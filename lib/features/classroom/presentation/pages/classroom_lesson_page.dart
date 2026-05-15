import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../lesson/presentation/providers/quiz_controller.dart';
import '../../../lesson/presentation/widgets/option_tile.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/classroom_result.dart';
import '../providers/classroom_providers.dart';

/// Página de quiz para uma fase de sala de aula.
///
/// Usa sua própria tela de resultado ("Voltar à turma") em vez do
/// [QuizResultView] global, que manda para a trilha de história.
class ClassroomLessonPage extends ConsumerWidget {
  const ClassroomLessonPage({
    super.key,
    required this.classroom,
    required this.phase,
  });

  final Classroom classroom;
  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (phase.questions.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        appBar: AppBar(
          title: Text(
            phase.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor:
              isDark ? AppColors.backgroundDark : AppColors.background,
          foregroundColor:
              isDark ? AppColors.textOnDark : AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: const Center(
          child: Text('Esta fase ainda não tem perguntas.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: Text(
          phase.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        foregroundColor:
            isDark ? AppColors.textOnDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _ClassroomQuiz(
        classroom: classroom,
        phase: phase,
      ),
    );
  }
}

// ─── Quiz inline (sem usar QuizView para controlar a tela de resultado) ────────

class _ClassroomQuiz extends ConsumerWidget {
  const _ClassroomQuiz({required this.classroom, required this.phase});

  final Classroom classroom;
  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = phase.questions;
    final state      = ref.watch(quizControllerProvider(questions));
    final controller = ref.read(quizControllerProvider(questions).notifier);
    final isDark     = Theme.of(context).brightness == Brightness.dark;

    // ── Quiz terminou → salva resultado e mostra tela própria ──────
    if (state.finished) {
      _saveResult(ref, state.correctCount);
      return _ClassroomResultView(
        total: questions.length,
        correct: state.correctCount,
        onRestart: controller.reset,
      );
    }

    // ── Quiz em andamento ─────────────────────────────────────────
    final question  = questions[state.currentIndex];
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
          // ── Progresso segmentado ─────────────────────────────────
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

          // ── Conteúdo rolável ─────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 24),
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

          // ── Botão rodapé ─────────────────────────────────────────
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

  /// Salva resultado e XP. Chamado uma única vez quando o quiz termina.
  /// Usa `didChangeDependencies`-safe: a chamada é fire-and-forget dentro
  /// de build (idempotente porque o estado `finished` não muda depois).
  void _saveResult(WidgetRef ref, int correctCount) {
    // Agendar fora do build frame para não chamar setState durante build
    Future.microtask(() async {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      final useCase = ref.read(submitClassroomResultProvider);
      await useCase(
        classroomId: classroom.id,
        result: ClassroomResult(
          studentId: user.id,
          studentName: user.displayName ?? user.email,
          totalQuestions: phase.questions.length,
          correctAnswers: correctCount,
          completedAt: DateTime.now(),
        ),
      );

      final repo = ref.read(progressRepositoryProvider);
      await repo.addXp(userId: user.id, amount: 15);
      await repo.addGold(userId: user.id, amount: 5);
      ref.invalidate(userProgressProvider(user.id));
    });
  }
}

// ─── Tela de resultado da classroom ──────────────────────────────────────────

class _ClassroomResultView extends StatelessWidget {
  const _ClassroomResultView({
    required this.total,
    required this.correct,
    required this.onRestart,
  });

  final int total;
  final int correct;
  final VoidCallback onRestart;

  int get _percent => total == 0 ? 0 : ((correct / total) * 100).round();
  bool get _passed => _percent >= 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
              size: 96,
              color: _passed ? const Color(0xFFFFD700) : cs.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _passed ? 'Fase concluída! 🎉' : 'Quase lá!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _passed
                  ? 'Você acertou $correct de $total questões.'
                  : 'Você acertou $correct de $total. Tente novamente!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _percent / 100,
                minHeight: 12,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _passed ? cs.primary : cs.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_percent% de aproveitamento',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // XP e moedas (badge visual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, color: cs.onPrimaryContainer, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '+15 XP  •  ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const Icon(FontAwesomeIcons.coins, color: Color(0xFFEAD47F), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '+5 moedas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: onRestart,
              label: 'Tentar novamente',
            ),
            const SizedBox(height: 12),
            // ← BOTÃO CORRETO: volta para a trilha da TURMA (pop), não para /lessons
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Voltar à turma'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers (copiados do quiz_view.dart para manter o visual idêntico) ───────

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
