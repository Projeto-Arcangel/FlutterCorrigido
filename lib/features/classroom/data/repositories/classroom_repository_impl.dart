import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_result.dart';
import '../../domain/repositories/classroom_repository.dart';
import '../datasources/firebase/classroom_firestore_datasource.dart';
import '../models/classroom_result_model.dart';

/// Implementação concreta do [ClassroomRepository].
///
/// Segue o mesmo padrão de `LessonRepositoryImpl`:
/// delega ao datasource e envolve tudo em try/catch retornando `Either`.
class ClassroomRepositoryImpl implements ClassroomRepository {
  ClassroomRepositoryImpl(this._datasource, this._logger);

  final ClassroomFirestoreDatasource _datasource;
  final Logger _logger;

  // ─── Sala ──────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Classroom>> createClassroom({
    required String name,
    required String description,
    required String teacherId,
  }) async {
    try {
      final classroom = await _datasource.createClassroom(
        name: name,
        description: description,
        teacherId: teacherId,
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
  Future<Either<Failure, Classroom?>> getStudentClassroom(
    String studentId,
  ) async {
    try {
      final classroom = await _datasource.fetchStudentClassroom(studentId);
      return Right(classroom);
    } catch (e, st) {
      _logger.e('getStudentClassroom failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao buscar sala do aluno'));
    }
  }

  // ─── Aluno entra/sai ──────────────────────────────────────────

  @override
  Future<Either<Failure, void>> joinClassroom({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      await _datasource.joinClassroom(
        classroomId: classroomId,
        studentId: studentId,
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
}
