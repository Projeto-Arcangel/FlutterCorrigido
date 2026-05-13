import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/lesson.dart';
import '../providers/lesson_providers.dart';
import '../providers/quiz_controller.dart';
import '../widgets/quiz_view.dart';

class LessonPage extends ConsumerWidget {
  const LessonPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncLesson = ref.watch(lessonByIdProvider(lessonId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Conteúdo',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        foregroundColor: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: asyncLesson.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erro: $err', textAlign: TextAlign.center),
          ),
        ),
        data: (lesson) {
          if (lesson.questions.isEmpty) {
            return const Center(
              child: Text('Esta lição ainda não tem perguntas.'),
            );
          }
          return _LessonContent(lesson: lesson);
        },
      ),
    );
  }
}

/// Wrapper que observa o término do quiz e avança a fase do usuário
/// quando aprovado (≥60%). Mantém o listener montado de forma estável
/// enquanto a lição existir.
class _LessonContent extends ConsumerWidget {
  const _LessonContent({required this.lesson});
  final Lesson lesson;

  static const double _passingRate = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<QuizState>(
      quizControllerProvider(lesson.questions),
      (previous, next) {
        final justFinished =
            (previous?.finished ?? false) == false && next.finished;
        if (!justFinished) return;

        final total = lesson.questions.length;
        if (total == 0) return;

        final passed = (next.correctCount / total) >= _passingRate;
        if (!passed) return;

        _advancePhaseIfNeeded(ref);
      },
    );

    return QuizView(
      title: lesson.name,
      description: lesson.description,
      questions: lesson.questions,
    );
  }

  Future<void> _advancePhaseIfNeeded(WidgetRef ref) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final repo = ref.read(progressRepositoryProvider);
    final progressResult = await repo.getProgress(user.id);
    final currentPhase = progressResult.fold<int>(
      (_) => 0,
      (progress) => progress.currentPhase,
    );

    // Só avança quando a fase concluída está adiante da fase atual
    // (evita rebaixar quem retentou uma fase antiga).
    if (lesson.order > currentPhase) {
      await repo.advancePhase(
        userId: user.id,
        newPhase: lesson.order,
      );

      // NOVO: concede gold apenas na primeira conclusão da fase
      await repo.addGold(
        userId: user.id,
        amount: 10,
      );

      ref.read(quizControllerProvider(lesson.questions).notifier).setGoldEarned(10);

      ref.invalidate(userProgressProvider(user.id));
    }
  }
}