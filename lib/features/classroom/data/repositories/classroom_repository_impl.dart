import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_activity.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/classroom_result.dart';
import '../../domain/repositories/classroom_repository.dart';
import '../datasources/supabase/classroom_supabase_datasource.dart';
import '../models/classroom_result_model.dart';

/// Implementação concreta do [ClassroomRepository].
///
/// Segue o mesmo padrão de `LessonRepositoryImpl`:
/// delega ao datasource e envolve tudo em try/catch retornando `Either`.
class ClassroomRepositoryImpl implements ClassroomRepository {
  ClassroomRepositoryImpl(this._datasource, this._logger);

  final ClassroomSupabaseDatasource _datasource;
  final Logger _logger;

  // ─── Sala ──────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Classroom>> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  }) async {
    try {
      final classroom = await _datasource.createClassroom(
        name: name,
        description: description,
        teacherId: teacherId,
        teacherName: teacherName,
      );
      return Right(classroom);
    } catch (e, st) {
      _logger.e('createClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao criar sala de aula'));
    }
  }

  @override
  Future<Either<Failure, void>> updateClassroom({
    required String classroomId,
    required String name,
    required String description,
  }) async {
    try {
      await _datasource.updateClassroom(
        classroomId: classroomId,
        name: name,
        description: description,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('updateClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao atualizar sala'));
    }
  }

  @override
  Future<Either<Failure, void>> updateTeacherName({
    required String teacherId,
    required String newName,
  }) async {
    try {
      await _datasource.updateTeacherName(
        teacherId: teacherId,
        newName: newName,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('updateTeacherName failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao sincronizar nome nas turmas'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteClassroom(String classroomId) async {
    try {
      await _datasource.deleteClassroom(classroomId);
      return const Right(null);
    } catch (e, st) {
      _logger.e('deleteClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao excluir sala'));
    }
  }

  @override
  Future<Either<Failure, Classroom>> getClassroomByCode(String code) async {
    try {
      final classroom = await _datasource.fetchByCode(code);
      if (classroom == null) {
        return const Left(
          ValidationFailure('Sala não encontrada com este código'),
        );
      }
      return Right(classroom);
    } catch (e, st) {
      _logger.e('getClassroomByCode failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao buscar sala'));
    }
  }

  @override
  Future<Either<Failure, List<Classroom>>> getTeacherClassrooms(
    String teacherId,
  ) async {
    try {
      final classrooms = await _datasource.fetchTeacherClassrooms(teacherId);
      return Right(classrooms);
    } catch (e, st) {
      _logger.e('getTeacherClassrooms failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar salas'));
    }
  }

  @override
  Future<Either<Failure, List<Classroom>>> getStudentClassrooms(
    String studentId,
  ) async {
    try {
      final classrooms = await _datasource.fetchStudentClassrooms(studentId);
      return Right(classrooms);
    } catch (e, st) {
      _logger.e('getStudentClassrooms failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao buscar salas do aluno'));
    }
  }

  // ─── Aluno entra/sai ──────────────────────────────────────────

  @override
  Future<Either<Failure, void>> joinClassroom({
    required String classroomId,
    required String studentId,
    String? studentName,
  }) async {
    try {
      await _datasource.joinClassroom(
        classroomId: classroomId,
        studentId: studentId,
        studentName: studentName,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('joinClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao entrar na sala'));
    }
  }

  @override
  Future<Either<Failure, void>> leaveClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      await _datasource.leaveClassroom(
        classroomId: classroomId,
        studentId: studentId,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('leaveClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao sair da sala'));
    }
  }

  // ─── Questões ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> addQuestion({
    required String classroomId,
    required Question question,
  }) async {
    try {
      await _datasource.addQuestion(
        classroomId: classroomId,
        question: question,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('addQuestion failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao adicionar questão'));
    }
  }

  @override
  Future<Either<Failure, void>> updateQuestion({
    required String classroomId,
    required Question question,
  }) async {
    try {
      await _datasource.updateQuestion(
        classroomId: classroomId,
        question: question,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('updateQuestion failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao editar questão'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteQuestion({
    required String classroomId,
    required String questionId,
  }) async {
    try {
      await _datasource.deleteQuestion(
        classroomId: classroomId,
        questionId: questionId,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('deleteQuestion failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao excluir questão'));
    }
  }

  @override
  Future<Either<Failure, List<Question>>> getQuestions(
    String classroomId,
  ) async {
    try {
      final questions = await _datasource.fetchQuestions(classroomId);
      return Right(questions);
    } catch (e, st) {
      _logger.e('getQuestions failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar questões'));
    }
  }

  // ─── Resultados ───────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> submitResult({
    required String classroomId,
    required ClassroomResult result,
    String? phaseTitle,
  }) async {
    try {
      await _datasource.submitResult(
        classroomId: classroomId,
        result: ClassroomResultModel(
          studentId: result.studentId,
          studentName: result.studentName,
          totalQuestions: result.totalQuestions,
          correctAnswers: result.correctAnswers,
          completedAt: result.completedAt,
        ),
        phaseTitle: phaseTitle,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('submitResult failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao salvar resultado'));
    }
  }

  @override
  Future<Either<Failure, List<ClassroomResult>>> getResults(
    String classroomId,
  ) async {
    try {
      final results = await _datasource.fetchResults(classroomId);
      return Right(results);
    } catch (e, st) {
      _logger.e('getResults failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar resultados'));
    }
  }

  // ─── Fases (quiz → fase no Supabase) ─────────────────────────

  @override
  Future<Either<Failure, ClassroomPhase>> saveQuizAsPhase({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
  }) async {
    try {
      final phase = await _datasource.saveQuizAsPhase(
        classroomId: classroomId,
        title: title,
        description: description,
        questions: questions,
      );
      return Right(phase);
    } catch (e, st) {
      _logger.e('saveQuizAsPhase failed', error: e, stackTrace: st);
      return const Left(
        NetworkFailure('Falha ao salvar questionário como fase'),
      );
    }
  }

  @override
  Future<Either<Failure, List<ClassroomPhase>>> getClassroomPhases(
    String classroomId,
  ) async {
    try {
      final phases = await _datasource.fetchClassroomPhases(classroomId);
      return Right(phases);
    } catch (e, st) {
      _logger.e('getClassroomPhases failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar fases da sala'));
    }
  }

  @override
  Future<Either<Failure, ClassroomPhase>> createEmptyPhase({
    required String classroomId,
    required String title,
    required String description,
  }) async {
    try {
      final phase = await _datasource.createEmptyPhase(
        classroomId: classroomId,
        title: title,
        description: description,
      );
      return Right(phase);
    } catch (e, st) {
      _logger.e('createEmptyPhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao criar fase'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePhase({
    required String classroomId,
    required String phaseId,
    required String title,
    required String description,
  }) async {
    try {
      await _datasource.updatePhase(
        classroomId: classroomId,
        phaseId: phaseId,
        title: title,
        description: description,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('updatePhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao atualizar a fase'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePhase({
    required String classroomId,
    required String phaseId,
  }) async {
    try {
      await _datasource.deletePhase(
        classroomId: classroomId,
        phaseId: phaseId,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('deletePhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao excluir a fase'));
    }
  }

  @override
  Future<Either<Failure, void>> reorderPhases({
    required String classroomId,
    required List<String> orderedPhaseIds,
  }) async {
    try {
      await _datasource.reorderPhases(
        classroomId: classroomId,
        orderedPhaseIds: orderedPhaseIds,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('reorderPhases failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao reordenar as fases'));
    }
  }

  @override
  Future<Either<Failure, void>> addQuestionsToPhase({
    required String classroomId,
    required String phaseId,
    required List<Question> questions,
  }) async {
    try {
      await _datasource.addQuestionsToPhase(
        classroomId: classroomId,
        phaseId: phaseId,
        questions: questions,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('addQuestionsToPhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao adicionar questões à fase'));
    }
  }

  @override
  Future<Either<Failure, void>> reorderQuestionsInPhase({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  }) async {
    try {
      await _datasource.reorderQuestionsInPhase(
        classroomId: classroomId,
        phaseId: phaseId,
        orderedQuestionIds: orderedQuestionIds,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('reorderQuestionsInPhase failed', error: e, stackTrace: st);
      return const Left(
        NetworkFailure('Falha ao reordenar as questões'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateQuestionInPhase({
    required String classroomId,
    required String phaseId,
    required Question question,
  }) async {
    try {
      await _datasource.updateQuestionInPhase(
        classroomId: classroomId,
        phaseId: phaseId,
        question: question,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('updateQuestionInPhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao editar a questão'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteQuestionFromPhase({
    required String classroomId,
    required String phaseId,
    required String questionId,
  }) async {
    try {
      await _datasource.deleteQuestionFromPhase(
        classroomId: classroomId,
        phaseId: phaseId,
        questionId: questionId,
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('deleteQuestionFromPhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao excluir a questão'));
    }
  }

  @override
  Future<List<ClassroomActivity>> fetchRecentActivities(
    String teacherId, {
    int limit = 3,
  }) async {
    try {
      return await _datasource.fetchRecentActivities(teacherId, limit: limit);
    } catch (e, st) {
      _logger.e('fetchRecentActivities failed', error: e, stackTrace: st);
      return [];
    }
  }
}
