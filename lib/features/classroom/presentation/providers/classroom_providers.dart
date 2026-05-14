import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/firebase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../data/datasources/firebase/classroom_firestore_datasource.dart';
import '../../data/repositories/classroom_repository_impl.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_result.dart';
import '../../domain/repositories/classroom_repository.dart';
import '../../domain/usecases/add_question_to_classroom.dart';
import '../../domain/usecases/create_classroom.dart';
import '../../domain/usecases/delete_question_from_classroom.dart';
import '../../domain/usecases/get_classroom_results.dart';
import '../../domain/usecases/get_student_classroom.dart';
import '../../domain/usecases/get_teacher_classrooms.dart';
import '../../domain/usecases/join_classroom.dart';
import '../../domain/usecases/leave_classroom.dart';
import '../../domain/usecases/submit_classroom_result.dart';
import '../../domain/usecases/update_classroom.dart';
import '../../domain/usecases/update_question_in_classroom.dart';

// ─── Infraestrutura ────────────────────────────────────────────

final classroomDatasourceProvider =
    Provider<ClassroomFirestoreDatasource>((ref) {
  return ClassroomFirestoreDatasource(ref.watch(firestoreProvider));
});

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepositoryImpl(
    ref.watch(classroomDatasourceProvider),
    ref.watch(loggerProvider),
  );
});

// ─── Use Cases ─────────────────────────────────────────────────

final createClassroomProvider = Provider<CreateClassroom>((ref) {
  return CreateClassroom(ref.watch(classroomRepositoryProvider));
});

final updateClassroomProvider = Provider<UpdateClassroom>((ref) {
  return UpdateClassroom(ref.watch(classroomRepositoryProvider));
});

final joinClassroomProvider = Provider<JoinClassroom>((ref) {
  return JoinClassroom(ref.watch(classroomRepositoryProvider));
});

final leaveClassroomProvider = Provider<LeaveClassroom>((ref) {
  return LeaveClassroom(ref.watch(classroomRepositoryProvider));
});

final getTeacherClassroomsProvider = Provider<GetTeacherClassrooms>((ref) {
  return GetTeacherClassrooms(ref.watch(classroomRepositoryProvider));
});

final getStudentClassroomProvider = Provider<GetStudentClassroom>((ref) {
  return GetStudentClassroom(ref.watch(classroomRepositoryProvider));
});

final addQuestionToClassroomProvider =
    Provider<AddQuestionToClassroom>((ref) {
  return AddQuestionToClassroom(ref.watch(classroomRepositoryProvider));
});

final updateQuestionInClassroomProvider =
    Provider<UpdateQuestionInClassroom>((ref) {
  return UpdateQuestionInClassroom(ref.watch(classroomRepositoryProvider));
});

final deleteQuestionFromClassroomProvider =
    Provider<DeleteQuestionFromClassroom>((ref) {
  return DeleteQuestionFromClassroom(ref.watch(classroomRepositoryProvider));
});

final submitClassroomResultProvider =
    Provider<SubmitClassroomResult>((ref) {
  return SubmitClassroomResult(ref.watch(classroomRepositoryProvider));
});

final getClassroomResultsProvider = Provider<GetClassroomResults>((ref) {
  return GetClassroomResults(ref.watch(classroomRepositoryProvider));
});

// ─── Async Providers (para consumir nas telas) ─────────────────

/// Lista de salas do professor (por teacherId).
final teacherClassroomsProvider = FutureProvider.autoDispose
    .family<List<Classroom>, String>((ref, teacherId) async {
  final useCase = ref.watch(getTeacherClassroomsProvider);
  final result = await useCase(teacherId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (classrooms) => classrooms,
  );
});

/// Sala atual do aluno (por studentId). Retorna null se não está em nenhuma.
final studentClassroomProvider = FutureProvider.autoDispose
    .family<Classroom?, String>((ref, studentId) async {
  final useCase = ref.watch(getStudentClassroomProvider);
  final result = await useCase(studentId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (classroom) => classroom,
  );
});

/// Questões de uma sala (por classroomId).
final classroomQuestionsProvider = FutureProvider.autoDispose
    .family<List<Question>, String>((ref, classroomId) async {
  final repo = ref.watch(classroomRepositoryProvider);
  final result = await repo.getQuestions(classroomId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (questions) => questions,
  );
});

/// Resultados dos alunos de uma sala (por classroomId).
final classroomResultsProvider = FutureProvider.autoDispose
    .family<List<ClassroomResult>, String>((ref, classroomId) async {
  final useCase = ref.watch(getClassroomResultsProvider);
  final result = await useCase(classroomId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (results) => results,
  );
});
