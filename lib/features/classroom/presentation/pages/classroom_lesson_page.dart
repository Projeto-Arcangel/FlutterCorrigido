import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../lesson/presentation/providers/quiz_controller.dart';
import '../../../lesson/presentation/widgets/quiz_view.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/classroom_result.dart';
import '../providers/classroom_providers.dart';

/// Página de quiz para uma fase de sala de aula.
///
/// Reutiliza o [QuizView] da trilha normal, mas ao final salva o resultado
/// na subcoleção `Classrooms/{classroomId}/results/{studentUid}`.
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
      body: _ClassroomLessonContent(
        classroom: classroom,
        phase: phase,
      ),
    );
  }
}

/// Wrapper que observa o término do quiz e salva o resultado do aluno
/// na subcoleção `results` da classroom.
class _ClassroomLessonContent extends ConsumerWidget {
  const _ClassroomLessonContent({
    required this.classroom,
    required this.phase,
  });
  final Classroom classroom;
  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<QuizState>(
      quizControllerProvider(phase.questions),
      (previous, next) {
        final justFinished =
            (previous?.finished ?? false) == false && next.finished;
        if (!justFinished) return;

        _submitResult(ref, next.correctCount);
      },
    );

    return QuizView(
      title: phase.title,
      description: phase.description,
      questions: phase.questions,
    );
  }

  Future<void> _submitResult(WidgetRef ref, int correctCount) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    // Salva o resultado na subcoleção results da classroom
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

    // Também concede XP ao aluno pela conclusão (mesma lógica da trilha normal)
    final repo = ref.read(progressRepositoryProvider);
    await repo.addXp(userId: user.id, amount: 15);
    await repo.addGold(userId: user.id, amount: 5);

    ref.invalidate(userProgressProvider(user.id));
  }
}
