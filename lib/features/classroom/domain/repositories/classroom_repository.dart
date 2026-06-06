import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../entities/classroom.dart';
import '../entities/classroom_activity.dart';
import '../entities/classroom_phase.dart';
import '../entities/classroom_result.dart';
import '../entities/quiz_submission_result.dart';

/// Contrato do repositório de salas de aula.
///
/// Implementado por `ClassroomRepositoryImpl` na camada data/.
/// Todos os métodos retornam `Either<Failure, T>` seguindo o padrão
/// do projeto (dartz).
abstract class ClassroomRepository {
  // ─── Sala ──────────────────────────────────────────────────────

  /// Cria uma nova sala com código único gerado automaticamente.
  /// Retorna a sala criada (com o id e code preenchidos).
  Future<Either<Failure, Classroom>> createClassroom({
    required String name,
    required String description,
    required String teacherId,
    required String teacherName,
  });

  /// Atualiza nome e descrição da sala.
  Future<Either<Failure, void>> updateClassroom({
    required String classroomId,
    required String name,
    required String description,
  });

  /// Atualiza o campo `teacherName` em todas as salas do professor.
  ///
  /// Deve ser chamado após o professor alterar o próprio nome na tela
  /// de conta, para manter o banner da trilha dos alunos sincronizado.
  Future<Either<Failure, void>> updateTeacherName({
    required String teacherId,
    required String newName,
  });

  /// Apaga a sala e todas as suas subcoleções (questions, results,
  /// phases). Operação irreversível.
  Future<Either<Failure, void>> deleteClassroom(String classroomId);

  /// Busca uma sala pelo código de 6 caracteres.
  Future<Either<Failure, Classroom>> getClassroomByCode(String code);

  /// Lista todas as salas de um professor.
  Future<Either<Failure, List<Classroom>>> getTeacherClassrooms(
    String teacherId,
  );

  /// Retorna todas as salas em que o aluno está matriculado.
  Future<Either<Failure, List<Classroom>>> getStudentClassrooms(String studentId);

  // ─── Aluno entra/sai ──────────────────────────────────────────

  /// Adiciona o aluno à sala (max 50). Falha se já está em outra sala.
  Future<Either<Failure, void>> joinClassroom({
    required String classroomId,
    required String studentId,
    String? studentName,
  });

  /// Remove o aluno da sala.
  Future<Either<Failure, void>> leaveClassroom({
    required String classroomId,
    required String studentId,
  });

  // ─── Questões ─────────────────────────────────────────────────

  /// Adiciona uma questão à subcoleção da sala.
  Future<Either<Failure, void>> addQuestion({
    required String classroomId,
    required Question question,
  });

  /// Atualiza uma questão existente.
  Future<Either<Failure, void>> updateQuestion({
    required String classroomId,
    required Question question,
  });

  /// Exclui uma questão da sala.
  Future<Either<Failure, void>> deleteQuestion({
    required String classroomId,
    required String questionId,
  });

  /// Busca todas as questões de uma sala.
  Future<Either<Failure, List<Question>>> getQuestions(String classroomId);

  // ─── Resultados ───────────────────────────────────────────────

  /// Envia as respostas do aluno (mapa `questionId → índice escolhido`) para
  /// correção NO SERVIDOR. O servidor calcula e grava a nota; devolve o resumo.
  Future<Either<Failure, QuizSubmissionResult>> submitQuiz({
    required String classroomId,
    required String phaseId,
    required Map<String, int> answers,
  });

  /// Retorna os resultados (agregados por aluno) de uma sala — para o ranking.
  Future<Either<Failure, List<ClassroomResult>>> getResults(
    String classroomId,
  );

  /// Retorna os resultados POR FASE de uma sala (cada item com `phaseId`),
  /// usado pelo dashboard do professor para filtrar/ponderar por fase.
  Future<Either<Failure, List<ClassroomResult>>> getPhaseResults(
    String classroomId,
  );

  // ─── Fases (quiz → fase no Supabase) ─────────────────────────

  /// Cria uma fase (Phase) no Supabase vinculada a uma sala de aula.
  ///
  /// A fase fica acessível somente para os alunos daquela sala.
  /// As questões são criadas na tabela `questions` com `phase_id`
  /// apontando para a fase criada.
  Future<Either<Failure, ClassroomPhase>> saveQuizAsPhase({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
  });

  /// Lista as fases (phases) de uma sala de aula.
  Future<Either<Failure, List<ClassroomPhase>>> getClassroomPhases(
    String classroomId,
  );

  /// Cria uma fase vazia (sem questões).
  /// As questões podem ser adicionadas depois via [addQuestionsToPhase].
  Future<Either<Failure, ClassroomPhase>> createEmptyPhase({
    required String classroomId,
    required String title,
    required String description,
    double weight = 1.0,
  });

  /// Atualiza o título, a descrição e o peso de uma fase existente.
  Future<Either<Failure, void>> updatePhase({
    required String classroomId,
    required String phaseId,
    required String title,
    required String description,
    double weight = 1.0,
  });

  /// Apaga uma fase (e todas as questões dela). Renumera o `order` das
  /// fases restantes.
  Future<Either<Failure, void>> deletePhase({
    required String classroomId,
    required String phaseId,
  });

  /// Reordena as fases conforme a lista de IDs (do início ao fim).
  Future<Either<Failure, void>> reorderPhases({
    required String classroomId,
    required List<String> orderedPhaseIds,
  });

  /// Adiciona questões a uma fase já existente, preservando as
  /// questões atuais e continuando o `order`.
  Future<Either<Failure, void>> addQuestionsToPhase({
    required String classroomId,
    required String phaseId,
    required List<Question> questions,
  });

  /// Reordena as questões dentro de uma fase.
  Future<Either<Failure, void>> reorderQuestionsInPhase({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  });

  /// Atualiza uma questão dentro de uma fase.
  Future<Either<Failure, void>> updateQuestionInPhase({
    required String classroomId,
    required String phaseId,
    required Question question,
  });

  /// Apaga uma questão de uma fase (renumera as restantes).
  Future<Either<Failure, void>> deleteQuestionFromPhase({
    required String classroomId,
    required String phaseId,
    required String questionId,
  });

  /// Devolve as [limit] actividades mais recentes de todas as salas do professor.
  Future<List<ClassroomActivity>> fetchRecentActivities(
    String teacherId, {
    int limit = 3,
  });
}
