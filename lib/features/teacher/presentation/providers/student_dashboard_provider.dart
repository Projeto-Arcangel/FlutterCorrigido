import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_result.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';

/// Todas as turmas do professor logado.
final teacherAllClassroomsProvider =
    FutureProvider.autoDispose<List<Classroom>>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return [];
  final repo = ref.read(classroomRepositoryProvider);
  final result = await repo.getTeacherClassrooms(user.uid);
  return result.fold((_) => [], (list) => list);
});

/// Resultados dos alunos de uma turma específica.
final classroomStudentResultsProvider =
    FutureProvider.autoDispose.family<List<ClassroomResult>, String>(
  (ref, classroomId) async {
    if (classroomId.isEmpty) return [];
    final repo = ref.read(classroomRepositoryProvider);
    final result = await repo.getResults(classroomId);
    return result.fold((_) => [], (list) => list);
  },
);
