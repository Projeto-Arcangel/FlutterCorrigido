import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../../lesson/domain/entities/question_kinds.dart';
import '../../../lesson/presentation/widgets/option_tile.dart';
import '../../../profile/domain/entities/achievement.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/phase_attempt.dart';
import '../../domain/entities/phase_rules.dart';
import '../providers/attempt_controller.dart';
import '../providers/classroom_providers.dart';
import '../widgets/crossword_board.dart';
import '../widgets/fill_blanks_board.dart';
import '../widgets/match_columns_board.dart';
import '../widgets/ordering_board.dart';
import '../widgets/word_search_board.dart';

const _green = Color(0xFF4CAF50);
const _amber = Color(0xFFE0A85B);
const _fire = Color(0xFFFF8A3D);
const _gold = Color(0xFFFFC83D);

/// Página de uma fase da turma, jogada numa tentativa no servidor:
/// cada resposta é corrigida e travada ao confirmar (com o gabarito da
/// questão na hora); a explicação vem no resultado, no fim da fase.
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
    final background = isDark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          phase.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: background,
        foregroundColor: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: phase.questions.isEmpty
          ? const Center(child: Text('Esta fase ainda não tem perguntas.'))
          : _AttemptView(classroom: classroom, phase: phase),
    );
  }
}

// ─── Tentativa ───────────────────────────────────────────────────────────────

class _AttemptView extends ConsumerWidget {
  const _AttemptView({required this.classroom, required this.phase});

  final Classroom classroom;
  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider =
        attemptControllerProvider((classroomId: classroom.id, phaseId: phase.id));

    // Tentativa entregue (ou recusada porque a fase fechou): a trilha e o
    // XP mudaram no servidor.
    ref.listen(provider, (prev, next) {
      final delivered = next.result != null &&
          next.result?.attemptId != prev?.result?.attemptId;
      final refused = next.stage == AttemptStage.error &&
          next.errorIsFinal &&
          prev?.stage != AttemptStage.error;
      if (!delivered && !refused) return;
      ref.invalidate(studentPhasesProvider(classroom.id));
      if (delivered) {
        final user = ref.read(authStateProvider).valueOrNull;
        if (user != null) ref.invalidate(userProgressProvider(user.id));
      }
    });

    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    switch (state.stage) {
      case AttemptStage.loading:
        return const _Busy(label: 'Abrindo a fase...');
      case AttemptStage.error:
        return _ErrorView(
          message: state.errorIsFinal
              ? state.error ?? 'Esta fase não está disponível.'
              : 'Não foi possível falar com o servidor.\n${state.error ?? ''}',
          onRetry: state.errorIsFinal ? null : controller.retry,
        );
      case AttemptStage.finished:
        return _AttemptResultView(
          result: state.result!,
          questions: state.attempt!.questions,
          passPct: phase.passPct,
          onRestart: controller.restart,
        );
      case AttemptStage.opening:
      case AttemptStage.playing:
      case AttemptStage.sending:
      case AttemptStage.feedback:
        return _QuestionView(state: state, controller: controller);
    }
  }
}

class _Busy extends StatelessWidget {
  const _Busy({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;

  /// `null` = recusa das regras da fase: repetir não adianta.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              onRetry == null ? Icons.event_busy_rounded : Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(message.trim(), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (onRetry != null) ...[
              AppButton(onPressed: onRetry, label: 'Tentar de novo'),
              const SizedBox(height: 8),
            ],
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

// ─── Questão ─────────────────────────────────────────────────────────────────

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.state, required this.controller});

  final AttemptViewState state;
  final AttemptController controller;

  OptionState _optionState(int i) {
    final fb = state.feedback;
    if (fb != null) {
      if (i == fb.correctAnswer) return OptionState.correct;
      if (i == state.selected) return OptionState.wrong;
      return OptionState.idle;
    }
    return state.selected == i ? OptionState.selected : OptionState.idle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = state.question!;
    final feedback = state.feedback;
    final playing = state.stage == AttemptStage.playing;
    final muted = isDark
        ? AppColors.textOnDark.withValues(alpha: 0.50)
        : AppColors.textSecondary;

    return ColoredBox(
      color: isDark ? AppColors.backgroundDark : AppColors.background,
      child: Column(
        children: [
          // ── Progresso, sequência e pontos ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SegmentedProgress(
                  questions: state.attempt!.questions,
                  answers: state.answers,
                  current: state.index,
                ),
                const SizedBox(height: 6),
                // Altura fixa: a sequência aparece e some sem empurrar a
                // questão.
                SizedBox(
                  height: 26,
                  child: Row(
                    children: [
                      Text(
                        'Pergunta ${state.index + 1} de ${state.total}',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const Spacer(),
                      if (state.streak > 0) ...[
                        _StreakChip(streak: state.streak),
                        const SizedBox(width: 8),
                      ],
                      _PointsChip(points: state.points),
                    ],
                  ),
                ),
                if (state.limitS != null && state.deadline != null) ...[
                  const SizedBox(height: 10),
                  _TimerBar(
                    key: ValueKey('timer-${question.id}'),
                    deadline: state.deadline!,
                    limitS: state.limitS!,
                    clock: ref.watch(attemptClockProvider),
                    running: playing,
                  ),
                ] else if (state.stage == AttemptStage.opening) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 6),
                ],
              ],
            ),
          ),

          // ── Enunciado e alternativas ──────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _cleanQuestionText(question.text),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                          color: isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (question.hasImage) ...[
                        const SizedBox(height: 16),
                        _QuestionImage(question: question, isDark: isDark),
                      ],
                      // Dica para jogar; depois de travar, a legenda da
                      // correção no mesmo lugar (sem empurrar o tabuleiro).
                      if (question.type.usesContent) ...[
                        const SizedBox(height: 10),
                        // Altura de 2 linhas: dica e legenda não empurram o tabuleiro.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: Text(
                            switch ((question.type, feedback == null)) {
                              (QuestionType.matchColumns, true) =>
                                'Toque num item da esquerda e depois no par '
                                    'dele na direita (ou arraste o fio).',
                              (QuestionType.matchColumns, false) =>
                                'Verde: ligação certa. Vermelho: errada. '
                                    'Tracejado: o par certo.',
                              (QuestionType.fillBlanks, true) =>
                                'Toque numa palavra do banco para preencher '
                                    'a lacuna (toque na lacuna para tirar).',
                              (QuestionType.fillBlanks, false) =>
                                'Verde: palavra certa. Vermelho: errada, com '
                                    'a certa ao lado.',
                              (QuestionType.crossword, true) =>
                                'Toque numa dica (ou numa casa) e escreva a '
                                    'palavra. Pode confirmar com o que tiver.',
                              (QuestionType.crossword, false) =>
                                'Na grade, as letras certas: verde onde você '
                                    'acertou, vermelho onde não.',
                              (QuestionType.wordSearch, true) =>
                                'Toque na primeira e na última letra de cada '
                                    'palavra (ou arraste).',
                              (QuestionType.wordSearch, false) =>
                                'Verde: palavras achadas. Tracejado: onde '
                                    'estavam as que faltaram.',
                              (_, true) =>
                                'Arraste ou use as setas para pôr na ordem '
                                    'certa.',
                              (_, false) =>
                                'Verde: na posição certa. '
                                    'Vermelho: fora do lugar.',
                            },
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (question.isMatchColumns)
                        MatchColumnsBoard(
                          left: question.matchLeft,
                          right: question.matchRight,
                          match: _nullableInts(state.draft?['match']),
                          onChanged: playing
                              ? (m) => controller.setDraft({'match': m})
                              : null,
                          reveal: _intsOrNull(feedback?.reveal['match']),
                        )
                      else if (question.isOrdering)
                        OrderingBoard(
                          items: question.orderingItems,
                          order: _nullableInts(state.draft?['order'])
                              .whereType<int>()
                              .toList(),
                          onChanged: playing
                              ? (o) => controller.setDraft({'order': o})
                              : null,
                          reveal: _intsOrNull(feedback?.reveal['order']),
                        )
                      else if (question.type == QuestionType.fillBlanks)
                        FillBlanksBoard(
                          parts: question.blankParts,
                          bank: question.blankBank,
                          blanks: _nullableInts(state.draft?['blanks']),
                          onChanged: playing
                              ? (b) => controller.setDraft({'blanks': b})
                              : null,
                          reveal: _intsOrNull(feedback?.reveal['blanks']),
                        )
                      else if (question.type == QuestionType.crossword)
                        CrosswordBoard(
                          rows: question.gridRows,
                          cols: question.gridCols,
                          slots: question.crosswordSlots,
                          words: _stringList(state.draft?['words']),
                          onChanged: playing
                              ? (w) => controller.setDraft({'words': w})
                              : null,
                          reveal: feedback == null
                              ? null
                              : _stringList(feedback.reveal['words']),
                        )
                      else if (question.type == QuestionType.wordSearch)
                        WordSearchBoard(
                          grid: question.wordSearchGrid,
                          words: question.wordSearchWords,
                          found: _positionList(state.draft?['found']),
                          onChanged: playing
                              ? (f) => controller.setDraft({'found': f})
                              : null,
                          reveal: feedback == null
                              ? null
                              : _positionList(feedback.reveal['positions']),
                        )
                      else
                        ...List.generate(question.options.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OptionTile(
                              index: i,
                              label: question.options[i],
                              optionState: _optionState(i),
                              onTap:
                                  playing ? () => controller.select(i) : null,
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Rodapé: confirmar ou o retorno da resposta ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (feedback != null) ...[
                    _FeedbackBanner(
                      feedback: feedback,
                      type: question.type,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      key: const ValueKey('next'),
                      onPressed: controller.next,
                      label:
                          state.result != null ? 'Ver resultado' : 'Continuar',
                    ),
                  ] else
                    AppButton(
                      key: const ValueKey('confirm'),
                      onPressed:
                          state.canConfirm ? controller.confirm : null,
                      loading: state.stage == AttemptStage.sending,
                      label: 'Confirmar',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.question, required this.isDark});

  final Question question;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final placeholder = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.05);
    final faint = isDark ? Colors.white38 : Colors.black38;
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 240),
            child: GestureDetector(
              onTap: () =>
                  _showImageDialog(context, question.imageUrl!, isDark),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  question.imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: placeholder,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, color: faint, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          'Imagem indisponível',
                          style: TextStyle(fontSize: 11, color: faint),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (question.imageAuthor != null && question.imageAuthor!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              question.imageSource != null && question.imageSource!.isNotEmpty
                  ? '${question.imageAuthor} — ${question.imageSource}'
                  : question.imageAuthor!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.textOnDark.withValues(alpha: 0.45)
                    : AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Retorno da resposta travada: acertou (com pontos e sequência), errou
/// ou o tempo acabou. A certa já aparece em verde nas alternativas.
class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.feedback, required this.type});

  final AnswerFeedback feedback;
  final QuestionType type;

  /// Onde o aluno vê a resposta certa, conforme o tipo.
  String get _where => switch (type) {
        QuestionType.matchColumns => 'Os fios certos aparecem tracejados em verde.',
        QuestionType.ordering => 'A ordem certa aparece abaixo dos itens.',
        QuestionType.fillBlanks => 'As palavras certas aparecem em verde.',
        QuestionType.crossword => 'A grade mostra as letras certas.',
        QuestionType.wordSearch => 'As que faltaram aparecem tracejadas.',
        _ => 'A resposta certa está em verde.',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon, title, detail) = switch (feedback) {
      AnswerFeedback(timedOut: true) => (
          _amber,
          Icons.timer_off_rounded,
          'Tempo esgotado',
          'Esta questão valeu 0. $_where',
        ),
      AnswerFeedback(correct: true) => (
          _green,
          Icons.check_circle_rounded,
          'Acertou! +${feedback.points} pontos',
          feedback.multiplier > 1
              ? 'Sequência de ${feedback.streak} acertos: '
                  'pontos ${formatMultiplier(feedback.multiplier)}'
              : null,
        ),
      AnswerFeedback(score: > 0) => (
          _amber,
          Icons.adjust_rounded,
          'Quase! Valeu ${formatPct(feedback.score * 100)}% '
              '(+${feedback.points} pontos)',
          _where,
        ),
      _ => (
          AppColors.error,
          Icons.cancel_rounded,
          'Não foi dessa vez',
          _where,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "×1,5", "×2".
String formatMultiplier(double m) => '×${formatPct(m)}';

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final mult = streak >= 5 ? 2.0 : (streak >= 3 ? 1.5 : 1.0);
    return Tooltip(
      message: 'Sequência de acertos: 3 seguidos valem ×1,5 e 5 seguidos, ×2',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _fire.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 16, color: _fire,),
            const SizedBox(width: 3),
            Text(
              mult > 1
                  ? 'Sequência $streak · ${formatMultiplier(mult)}'
                  : 'Sequência $streak',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _fire,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsChip extends StatelessWidget {
  const _PointsChip({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.stars_rounded, size: 16, color: AppColors.primary),
        const SizedBox(width: 3),
        Text(
          '$points pts',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Barra do relógio. Conta pelo horário do aparelho (não por quadros), para
/// não atrasar se a aba ficar em segundo plano; quem decide o tempo de
/// verdade é o servidor.
class _TimerBar extends StatefulWidget {
  const _TimerBar({
    super.key,
    required this.deadline,
    required this.limitS,
    required this.clock,
    required this.running,
  });

  final DateTime deadline;
  final int limitS;
  final DateTime Function() clock;

  /// Parado (enviando a resposta): congela a barra.
  final bool running;

  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late double _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _compute();
    _ticker = createTicker((_) {
      final r = _compute();
      // Redesenha só quando muda o bastante para aparecer.
      if ((r - _remaining).abs() >= 0.05 || r == 0) {
        setState(() => _remaining = r);
      }
      if (r == 0) _ticker.stop();
    });
    if (widget.running) _ticker.start();
  }

  @override
  void didUpdateWidget(_TimerBar old) {
    super.didUpdateWidget(old);
    if (widget.running && !_ticker.isActive && _remaining > 0) {
      _ticker.start();
    } else if (!widget.running && _ticker.isActive) {
      _ticker.stop();
    }
  }

  double _compute() {
    final ms = widget.deadline.difference(widget.clock()).inMilliseconds;
    return (ms / 1000).clamp(0.0, widget.limitS.toDouble());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = widget.limitS == 0 ? 0.0 : _remaining / widget.limitS;
    final color = fraction > 0.5
        ? AppColors.primary
        : (fraction > 0.25 ? _amber : AppColors.error);
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${_remaining.ceil()} s',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Uma faixa por questão: verde acertou, vermelho errou, âmbar parcial ou
/// tempo esgotado, azul a atual.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.questions,
    required this.answers,
    required this.current,
  });

  final List<Question> questions;
  final Map<String, AnswerFeedback> answers;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor =
        isDark ? Colors.white12 : AppColors.borderBlue.withValues(alpha: 0.25);

    return Row(
      children: List.generate(questions.length, (i) {
        final a = answers[questions[i].id];
        final Color color;
        if (a != null) {
          color = a.correct
              ? _green
              : (a.timedOut || a.score > 0 ? _amber : AppColors.error);
        } else if (i == current) {
          color = AppColors.primary;
        } else {
          color = emptyColor;
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < questions.length - 1 ? 4 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Resultado ───────────────────────────────────────────────────────────────

class _AttemptResultView extends StatelessWidget {
  const _AttemptResultView({
    required this.result,
    required this.questions,
    required this.onRestart,
    this.passPct,
  });

  final AttemptResult result;
  final List<Question> questions;
  final VoidCallback onRestart;

  /// Nota mínima da fase para liberar a próxima.
  final double? passPct;

  String get _title => switch (result.stars) {
        3 => 'Perfeito!',
        2 => 'Muito bem!',
        1 => 'Fase concluída!',
        _ => 'Quase lá!',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = result;
    final rewards = [
      if (r.xp > 0) '+${r.xp} XP',
      if (r.gold > 0) '+${r.gold} moedas',
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stars(count: r.stars),
                const SizedBox(height: 12),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.firstAttempt
                      ? 'Você acertou ${formatPct(r.score)} de ${r.total}.'
                      : 'Nesta tentativa você acertou ${formatPct(r.score)} '
                          'de ${r.total}.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (r.pct / 100).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      r.stars > 0 ? cs.primary : cs.error,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatPct(r.pct)}% de aproveitamento',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.stars_rounded,
                        color: AppColors.primary,
                        value: '${r.points}',
                        label: 'pontos',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.local_fire_department_rounded,
                        color: _fire,
                        value: '${r.bestStreak}',
                        label: 'maior sequência',
                      ),
                    ),
                  ],
                ),
                if (rewards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          r.gold > 0 && r.xp == 0
                              ? FontAwesomeIcons.coins
                              : Icons.bolt_rounded,
                          color: cs.onPrimaryContainer,
                          size: r.gold > 0 && r.xp == 0 ? 18 : 28,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            r.firstAttempt
                                ? rewards.join('  •  ')
                                : '${rewards.join('  •  ')} pelas estrelas novas',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                for (final a in r.achievements) ...[
                  const SizedBox(height: 12),
                  _UnlockedAchievementTile(achievement: a),
                ],
                if (!r.firstAttempt) ...[
                  const SizedBox(height: 12),
                  _InfoBox(
                    icon: Icons.check_circle_outline_rounded,
                    text: [
                      'Sua nota oficial continua ${formatPct(r.officialPct)}%, '
                          'a da 1ª tentativa.',
                      if (r.bestStars > r.stars)
                        'Suas estrelas nesta fase continuam ${r.bestStars}, '
                            'da melhor tentativa.',
                    ].join(' '),
                  ),
                ],
                if (passPct != null) ...[
                  const SizedBox(height: 16),
                  _PassScoreBox(passPct: passPct!, bestPct: r.bestPct),
                ],
                if (r.review.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _ReviewSection(questions: questions, review: r.review),
                ],
                const SizedBox(height: 24),
                AppButton(onPressed: onRestart, label: 'Tentar novamente'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar à turma'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Conquista liberada!" na tela de resultado.
class _UnlockedAchievementTile extends StatelessWidget {
  const _UnlockedAchievementTile({required this.achievement});

  final UnlockedAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Dourado escuro some no tema escuro: lá usa o dourado das estrelas.
    final accent = theme.brightness == Brightness.dark
        ? _gold
        : const Color(0xFFB98500);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievementIcon(achievement.id),
                color: accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conquista liberada!',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    achievement.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (achievement.gold > 0) ...[
              Icon(FontAwesomeIcons.coins, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                '+${achievement.gold}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Três estrelas que acendem uma a uma (60%, 80%, 100%).
class _Stars extends StatelessWidget {
  const _Stars({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25);
    return Semantics(
      label: '$count de 3 estrelas',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final lit = i < count;
          final size = i == 1 ? 76.0 : 60.0;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: lit ? 0.0 : 1.0, end: 1.0),
            duration: Duration(milliseconds: lit ? 450 + i * 200 : 1),
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Padding(
              padding: EdgeInsets.only(bottom: i == 1 ? 12 : 0),
              child: Icon(
                lit ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: lit ? _gold : off,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(label, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nota mínima da fase: liberou a próxima ou quanto falta.
class _PassScoreBox extends StatelessWidget {
  const _PassScoreBox({required this.passPct, required this.bestPct});

  final double passPct;
  final double? bestPct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = bestPct ?? 0;
    final reached = best >= passPct;
    final color = reached ? const Color(0xFF3FA86B) : _amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            reached ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reached
                  ? 'Próxima fase liberada! Sua melhor nota '
                      '(${formatPct(best)}%) alcançou o mínimo de '
                      '${formatPct(passPct)}%.'
                  : 'Para liberar a próxima fase, tire pelo menos '
                      '${formatPct(passPct)}%. Sua melhor nota: '
                      '${formatPct(best)}%. Toque em "Tentar novamente".',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Correção completa (no fim da fase) ──────────────────────────────────────

/// A correção de cada questão com a explicação — só no resultado.
class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.questions, required this.review});

  final List<Question> questions;
  final List<AttemptReviewItem> review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byId = {for (final q in questions) q.id: q};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Revisão das respostas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < review.length; i++)
          if (byId[review[i].questionId] case final q?)
            _ReviewItem(
              number: i + 1,
              question: q,
              item: review[i],
              isDark: isDark,
            ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.number,
    required this.question,
    required this.item,
    required this.isDark,
  });

  final int number;
  final Question question;
  final AttemptReviewItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ok = item.correct;
    final partial = !ok && item.score > 0;
    final accent = ok ? _green : (partial ? _amber : AppColors.error);
    final note = !item.answered
        ? 'A fase fechou antes de você responder esta questão.'
        : item.timedOut
            ? 'O tempo acabou nesta questão.'
            : (item.response == null ? 'Você não respondeu esta questão.' : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white12
              : AppColors.borderBlue.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Questão $number',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textOnDark.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (partial)
                Text(
                  'valeu ${formatPct(item.score * 100)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _amber,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                ok
                    ? Icons.check_circle_rounded
                    : (item.timedOut
                        ? Icons.timer_off_rounded
                        : Icons.cancel_rounded),
                color: accent,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _cleanQuestionText(question.text),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (question.isMatchColumns)
            MatchColumnsBoard(
              left: question.matchLeft,
              right: question.matchRight,
              match: item.response == null
                  ? List<int?>.filled(question.matchLeft.length, null)
                  : _nullableInts(item.response!['match']),
              reveal: _intsOrNull(item.reveal['match']),
            )
          else if (question.type == QuestionType.fillBlanks)
            FillBlanksBoard(
              parts: question.blankParts,
              bank: question.blankBank,
              blanks: item.response == null
                  ? List<int?>.filled(question.interactions, null)
                  : _nullableInts(item.response!['blanks']),
              reveal: _intsOrNull(item.reveal['blanks']),
            )
          else if (question.type == QuestionType.crossword)
            CrosswordBoard(
              rows: question.gridRows,
              cols: question.gridCols,
              slots: question.crosswordSlots,
              words: _stringList(item.response?['words']),
              reveal: _stringList(item.reveal['words']),
            )
          else if (question.type == QuestionType.wordSearch)
            WordSearchBoard(
              grid: question.wordSearchGrid,
              words: question.wordSearchWords,
              found: _positionList(item.response?['found']),
              reveal: _positionList(item.reveal['positions']),
            )
          else if (question.isOrdering)
            item.response == null
                ? _CorrectOrder(
                    items: question.orderingItems,
                    order: _intsOrNull(item.reveal['order']) ?? const [],
                  )
                : OrderingBoard(
                    items: question.orderingItems,
                    order: _nullableInts(item.response!['order'])
                        .whereType<int>()
                        .toList(),
                    reveal: _intsOrNull(item.reveal['order']),
                  )
          else
            ...List.generate(question.options.length, (i) {
              final OptionState st;
              if (i == item.correctAnswer) {
                st = OptionState.correct;
              } else if (i == item.chosen) {
                st = OptionState.wrong;
              } else {
                st = OptionState.idle;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OptionTile(
                  index: i,
                  label: question.options[i],
                  optionState: st,
                ),
              );
            }),
          if (note != null)
            Text(
              note,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.error,
              ),
            ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ExplanationCard(
              explanation: item.explanation,
              isCorrect: ok,
              isDark: isDark,
            ),
          ],
        ],
      ),
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
    final color = isCorrect ? _green : AppColors.error;
    return Container(
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

/// Ordem certa, quando o aluno não chegou a responder.
class _CorrectOrder extends StatelessWidget {
  const _CorrectOrder({required this.items, required this.order});

  final List<String> items;
  final List<int> order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ordem certa:',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: _green),
        ),
        const SizedBox(height: 6),
        for (var p = 0; p < order.length; p++)
          if (order[p] >= 0 && order[p] < items.length)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${p + 1}. ${items[order[p]]}'),
            ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Lista de índices vinda do JSON (`null` onde não há valor).
List<int?> _nullableInts(Object? value) => value is List
    ? [for (final v in value) v is num ? v.toInt() : null]
    : const [];

List<int>? _intsOrNull(Object? value) => value is List
    ? [for (final v in value) v is num ? v.toInt() : -1]
    : null;

/// Lista de textos vinda do JSON (cruzadinha).
List<String> _stringList(Object? value) =>
    value is List ? [for (final v in value) '${v ?? ''}'] : const [];

/// Marcações [r1, c1, r2, c2] vindas do JSON (caça-palavras).
List<List<int>> _positionList(Object? value) => value is List
    ? [
        for (final p in value)
          if (p is List) [for (final v in p) v is num ? v.toInt() : -1],
      ]
    : const [];

// ─── Dialog de imagem em tela cheia ───────────────────────────────────────────

void _showImageDialog(BuildContext context, String url, bool isDark) {
  showDialog<void>(
    context: context,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Scaffold(
        backgroundColor: isDark
            ? Colors.black.withValues(alpha: 0.92)
            : Colors.black87,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white38, size: 48,),
                        SizedBox(height: 8),
                        Text('Imagem indisponível',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14,),),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white70, size: 22,),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── Limpeza de URLs do texto de questão ──────────────────────────────────────

/// Remove URLs soltas (bare URLs do Supabase storage etc.) que ficaram
/// embutidas no texto da questão após importação do ENEM.
String _cleanQuestionText(String text) {
  var out = text.replaceAll(
    RegExp(r'https?://\S+', caseSensitive: false),
    '',
  );
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return out.trim();
}
