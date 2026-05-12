import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/question.dart';
import '../providers/quiz_controller.dart';
import 'option_tile.dart';
import 'quiz_result_view.dart';

class QuizView extends ConsumerWidget {
  const QuizView({
    super.key,
    required this.title,
    required this.description,
    required this.questions,
  });

  final String title;
  final String description;
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state      = ref.watch(quizControllerProvider(questions));
    final controller = ref.read(quizControllerProvider(questions).notifier);
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    if (state.finished) {
      return QuizResultView(
        total: questions.length,
        correct: state.correctCount,
        xpEarned: state.xpEarned,
        onRestart: controller.reset,
      );
    }

    final question = questions[state.currentIndex];
    final selected  = state.answers[state.currentIndex];
    final confirmed = state.confirmed;
    final isLast    = state.currentIndex == questions.length - 1;

    final btnLabel = !confirmed
        ? 'Verificar'
        : (isLast ? 'Finalizar' : 'Continuar');

    return ColoredBox(
      color: isDark ? AppColors.backgroundDark : AppColors.background,
      child: Column(
        children: [
          // ── Progresso segmentado ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SegmentedProgress(
                  total: questions.length,
                  current: state.currentIndex,
                  confirmed: confirmed,
                ),
                const SizedBox(height: 6),
                Text(
                  'Pergunta ${state.currentIndex + 1} de ${questions.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.50)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // ── Conteúdo rolável ───────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Enunciado
                  Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                      color: isDark
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                    ),
                  ),

                  // Imagem (quando disponível)
                  if (question.hasImage) ...[
                    const SizedBox(height: 20),
                    _QuestionImage(question: question, isDark: isDark),
                  ],

                  const SizedBox(height: 24),

                  // Alternativas
                  ...List.generate(question.options.length, (i) {
                    final OptionState optState;
                    if (!confirmed) {
                      optState = selected == i
                          ? OptionState.selected
                          : OptionState.idle;
                    } else {
                      if (i == question.correctAnswer) {
                        optState = OptionState.correct;
                      } else if (i == selected) {
                        optState = OptionState.wrong;
                      } else {
                        optState = OptionState.idle;
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OptionTile(
                        index: i,
                        label: question.options[i],
                        optionState: optState,
                        onTap: confirmed ? null : () => controller.answer(i),
                      ),
                    );
                  }),

                  // Explicação (exibida após confirmação)
                  if (confirmed && question.explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _ExplanationCard(
                      explanation: question.explanation,
                      isCorrect: selected == question.correctAnswer,
                      isDark: isDark,
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Botão de ação (fixo no rodapé) ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: AppButton(
                key: ValueKey(btnLabel),
                onPressed: selected == null
                    ? null
                    : confirmed
                        ? () => controller.next()
                        : controller.confirm,
                label: btnLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Barra de progresso segmentada ────────────────────────────────────────────
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.total,
    required this.current,
    required this.confirmed,
  });

  final int total;
  final int current;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor = isDark
        ? Colors.white12
        : AppColors.borderBlue.withValues(alpha: 0.25);

    return Row(
      children: List.generate(total, (i) {
        Color segColor;
        if (i < current) {
          segColor = AppColors.primary;
        } else if (i == current) {
          segColor = confirmed
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.45);
        } else {
          segColor = emptyColor;
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: segColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Imagem da questão com créditos ───────────────────────────────────────────
class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.question, required this.isDark});

  final Question question;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final placeholderColor =
        isDark ? AppColors.surfaceDark : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: question.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => ColoredBox(
                color: placeholderColor,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => ColoredBox(
                color: placeholderColor,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (question.imageAuthor != null || question.imageSource != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (question.imageAuthor != null)
                Text(
                  'Autor: ${question.imageAuthor}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.45)
                        : AppColors.textSecondary,
                  ),
                ),
              if (question.imageSource != null)
                Text(
                  'Fonte: ${question.imageSource}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textOnDark.withValues(alpha: 0.45)
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Card de explicação (exibido após confirmar a resposta) ───────────────────
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.explanation,
    required this.isCorrect,
    required this.isDark,
  });

  final String explanation;
  final bool isCorrect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF4CAF50) : AppColors.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCorrect ? Icons.lightbulb_rounded : Icons.info_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              explanation,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.textOnDark.withValues(alpha: 0.85)
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
