import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../domain/entities/bank_question.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_activity.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/classroom_result.dart';
import '../../domain/entities/phase_attempt.dart';
import '../../domain/entities/phase_rules.dart';
import '../../domain/repositories/classroom_repository.dart';
import '../datasources/supabase/classroom_supabase_datasource.dart';

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

  // ─── Tentativas ───────────────────────────────────────────────

  /// Recusas das regras da fase (não abriu, fechou, bloqueada, fora de
  /// ordem) chegam com a mensagem pronta do servidor e não adianta
  /// repetir; o resto é rede (repetir é seguro: o servidor não corrige a
  /// mesma questão duas vezes).
  Failure _attemptFailure(Object e, String fallback) {
    if (e is PostgrestException && (e.code == '22023' || e.code == '42501')) {
      return ValidationFailure(e.message);
    }
    return NetworkFailure(ErrorMessages.from(e, fallback: fallback));
  }

  @override
  Future<Either<Failure, PhaseAttempt>> startAttempt({
    required String classroomId,
    required String phaseId,
  }) async {
    try {
      return Right(
        await _datasource.startAttempt(
          classroomId: classroomId,
          phaseId: phaseId,
        ),
      );
    } catch (e, st) {
      _logger.e('startAttempt failed', error: e, stackTrace: st);
      return Left(_attemptFailure(e, 'Não foi possível abrir a fase.'));
    }
  }

  @override
  Future<Either<Failure, OpenedQuestion>> openQuestion({
    required String attemptId,
    required String questionId,
  }) async {
    try {
      return Right(
        await _datasource.openQuestion(
          attemptId: attemptId,
          questionId: questionId,
        ),
      );
    } catch (e, st) {
      _logger.e('openQuestion failed', error: e, stackTrace: st);
      return Left(_attemptFailure(e, 'Não foi possível abrir a questão.'));
    }
  }

  @override
  Future<Either<Failure, PartCheck>> checkAnswerPart({
    required String attemptId,
    required String questionId,
    required Map<String, dynamic> part,
  }) async {
    try {
      return Right(
        await _datasource.checkAnswerPart(
          attemptId: attemptId,
          questionId: questionId,
          part: part,
        ),
      );
    } catch (e, st) {
      _logger.e('checkAnswerPart failed', error: e, stackTrace: st);
      return Left(_attemptFailure(e, 'Não foi possível conferir agora.'));
    }
  }

  @override
  Future<Either<Failure, AnswerOutcome>> answerQuestion({
    required String attemptId,
    required String questionId,
    Map<String, dynamic>? response,
  }) async {
    try {
      return Right(
        await _datasource.answerQuestion(
          attemptId: attemptId,
          questionId: questionId,
          response: response,
        ),
      );
    } catch (e, st) {
      _logger.e('answerQuestion failed', error: e, stackTrace: st);
      return Left(_attemptFailure(e, 'Não foi possível enviar a resposta.'));
    }
  }

  @override
  Future<Either<Failure, List<ClassroomMember>>> getRoster(
    String classroomId,
  ) async {
    try {
      return Right(await _datasource.fetchRoster(classroomId));
    } catch (e, st) {
      _logger.e('getRoster failed', error: e, stackTrace: st);
      return Left(
        NetworkFailure(
          ErrorMessages.from(e, fallback: 'Falha ao carregar os alunos da turma'),
        ),
      );
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

  @override
  Future<Either<Failure, List<ClassroomResult>>> getPhaseResults(
    String classroomId,
  ) async {
    try {
      final results = await _datasource.fetchPhaseResults(classroomId);
      return Right(results);
    } catch (e, st) {
      _logger.e('getPhaseResults failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar resultados por fase'));
    }
  }

  // ─── Fases (quiz → fase no Supabase) ─────────────────────────

  @override
  Future<Either<Failure, ClassroomPhase>> saveQuizAsPhase({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
    double weight = 1.0,
  }) async {
    try {
      final phase = await _datasource.saveQuizAsPhase(
        classroomId: classroomId,
        title: title,
        description: description,
        questions: questions,
        weight: weight,
      );
      return Right(phase);
    } catch (e, st) {
      _logger.e('saveQuizAsPhase failed', error: e, stackTrace: st);
      return Left(_saveFailure(e, 'Falha ao salvar questionário como fase'));
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
  Future<Either<Failure, List<ClassroomPhase>>> getStudentPhases(
    String classroomId,
  ) async {
    try {
      final phases = await _datasource.fetchStudentPhases(classroomId);
      return Right(phases);
    } catch (e, st) {
      _logger.e('getStudentPhases failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar fases da sala'));
    }
  }

  @override
  Future<Either<Failure, ClassroomPhase>> createEmptyPhase({
    required String classroomId,
    required String title,
    required String description,
    double weight = 1.0,
  }) async {
    try {
      final phase = await _datasource.createEmptyPhase(
        classroomId: classroomId,
        title: title,
        description: description,
        weight: weight,
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
    double weight = 1.0,
  }) async {
    try {
      await _datasource.updatePhase(
        classroomId: classroomId,
        phaseId: phaseId,
        title: title,
        description: description,
        weight: weight,
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
      return Left(_saveFailure(e, 'Falha ao adicionar questões à fase'));
    }
  }

  @override
  Future<Either<Failure, void>> updatePhaseRules({
    required String classroomId,
    required String phaseId,
    required PhaseRules rules,
  }) async {
    try {
      await _datasource.updatePhaseRules(phaseId: phaseId, rules: rules);
      return const Right(null);
    } catch (e, st) {
      _logger.e('updatePhaseRules failed', error: e, stackTrace: st);
      // As restrições do banco espelham PhaseRules.validate.
      if (e is PostgrestException && e.code == '23514') {
        if (e.message.contains('dates_order')) {
          return const Left(
            ValidationFailure('O fechamento precisa ser depois da abertura.'),
          );
        }
        if (e.message.contains('pass_pct')) {
          return const Left(
            ValidationFailure('A nota mínima vai de 1% a 100%.'),
          );
        }
        if (e.message.contains('timer_level')) {
          return const Left(
            ValidationFailure(
              'Escolha o tempo do relógio: curto, normal ou longo.',
            ),
          );
        }
      }
      return Left(
        NetworkFailure(
          ErrorMessages.from(
            e,
            fallback: 'Não foi possível salvar as regras da fase.',
          ),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<BankQuestion>>> getQuestionBank() async {
    try {
      return Right(await _datasource.fetchQuestionBank());
    } catch (e, st) {
      _logger.e('getQuestionBank failed', error: e, stackTrace: st);
      return Left(
        NetworkFailure(
          ErrorMessages.from(
            e,
            fallback: 'Não foi possível carregar suas questões.',
          ),
        ),
      );
    }
  }

  @override
  Future<Either<Failure, int>> copyQuestionsToPhase({
    required String phaseId,
    required List<String> questionIds,
  }) async {
    try {
      return Right(
        await _datasource.copyQuestionsToPhase(
          phaseId: phaseId,
          questionIds: questionIds,
        ),
      );
    } catch (e, st) {
      _logger.e('copyQuestionsToPhase failed', error: e, stackTrace: st);
      return Left(_saveFailure(e, 'Não foi possível copiar as questões.'));
    }
  }

  @override
  Future<Either<Failure, int>> deleteBankQuestions({
    required List<String> questionIds,
  }) async {
    try {
      return Right(await _datasource.deleteMyQuestions(questionIds));
    } catch (e, st) {
      _logger.e('deleteBankQuestions failed', error: e, stackTrace: st);
      return Left(_saveFailure(e, 'Não foi possível excluir as questões.'));
    }
  }

  /// Limite do plano vira a mensagem do servidor (o que aconteceu e o que
  /// fazer); recusas das RPCs (lista mudou, sem permissão) também têm texto
  /// pronto. O resto fica com [fallback].
  Failure _saveFailure(Object e, String fallback) {
    if (ErrorMessages.isPlanLimit(e)) {
      return ValidationFailure(ErrorMessages.from(e));
    }
    if (e is PostgrestException && e.code == '22023') {
      return ValidationFailure(e.message);
    }
    return NetworkFailure(ErrorMessages.from(e, fallback: fallback));
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
