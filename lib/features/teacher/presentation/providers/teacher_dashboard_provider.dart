import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../../domain/entities/teacher_dashboard_data.dart';

final teacherDashboardProvider =
    FutureProvider.autoDispose<TeacherDashboardData?>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return null;
  final classroomRepository = ref.read(classroomRepositoryProvider);

  // 1. Usa a primeira sala como resumo principal do dashboard do professor.
  final classroomsResult = await classroomRepository.getTeacherClassrooms(
    user.uid,
  );

  final classrooms = classroomsResult.fold((_) => [], (list) => list);
  if (classrooms.isEmpty) {
    return TeacherDashboardData(
      totalStudents: 0,
      totalQuestions: 0,
      averageScore: 0,
      classroomName: 'Nenhuma turma',
      classroomCode: '—',
      classroomId: '',
    );
  }

  final classroom = classrooms.first;

  // 2. Conta questões de todas as fases da sala
  final phasesResult = await classroomRepository.getClassroomPhases(
    classroom.id,
  );

  final phases = phasesResult.fold((_) => [], (list) => list);
  final totalQuestions =
      phases.fold<int>(0, (sum, p) => sum + p.totalQuestions);

  // 3. Calcula média dos resultados dos alunos
  final resultsResult = await classroomRepository.getResults(classroom.id);

  final results = resultsResult.fold((_) => [], (list) => list);
  double averageScore = 0;
  if (results.isNotEmpty) {
    final total = results.fold<double>(
      0,
      (sum, r) => sum + r.percentage * 100,
    );
    averageScore = total / results.length;
  }

  return TeacherDashboardData(
    totalStudents: classroom.studentIds.length,
    totalQuestions: totalQuestions,
    averageScore: averageScore,
    classroomName: classroom.name,
    classroomCode: classroom.code,
    classroomId: classroom.id,
  );
});
