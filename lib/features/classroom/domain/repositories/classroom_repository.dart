import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../entities/bank_question.dart';
import '../entities/classroom.dart';
import '../entities/classroom_activity.dart';
import '../entities/classroom_phase.dart';
import '../entities/classroom_result.dart';
import '../entities/phase_attempt.dart';
import '../entities/phase_rules.dart';

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

  /// Apaga a sala e, em cascata, alunos, fases, questões, tentativas e
  /// resultados dela. Operação irreversível.
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

  /// Adiciona o aluno à sala (máx. 50). Se já for membro, nada muda; falha se
  /// a sala estiver inativa ou lotada.
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

  // ─── Questões soltas de sala ───────────────────────────────────
  // Não existem no schema atual: as questões vivem nas fases (ver
  // addQuestionsToPhase). Mantidos por contrato; a implementação é no-op e
  // getQuestions devolve vazio.

  /// Adiciona uma questão solta à sala (no-op).
  Future<Either<Failure, void>> addQuestion({
    required String classroomId,
    required Question question,
  });

  /// Atualiza uma questão solta da sala (no-op).
  Future<Either<Failure, void>> updateQuestion({
    required String classroomId,
    required Question question,
  });

  /// Exclui uma questão solta da sala (no-op).
  Future<Either<Failure, void>> deleteQuestion({
    required String classroomId,
    required String questionId,
  });

  /// Busca as questões soltas da sala (sempre vazio).
  Future<Either<Failure, List<Question>>> getQuestions(String classroomId);

  // ─── Resultados ───────────────────────────────────────────────

  /// Abre uma tentativa na fase (ou retoma a que ficou pela metade). As
  /// questões vêm sem gabarito; cada resposta é corrigida no servidor.
  Future<Either<Failure, PhaseAttempt>> startAttempt({
    required String classroomId,
    required String phaseId,
  });

  /// Com relógio: marca no servidor quando a questão apareceu.
  Future<Either<Failure, OpenedQuestion>> openQuestion({
    required String attemptId,
    required String questionId,
  });

  /// Confere na hora uma parte da resposta da questão aberta (cruzadinha ou
  /// caça-palavras com "acertos na hora"). O gabarito não vem: só se aquela
  /// palavra está certa (ou qual palavra a marcação achou).
  Future<Either<Failure, PartCheck>> checkAnswerPart({
    required String attemptId,
    required String questionId,
    required Map<String, dynamic> part,
  });

  /// Envia e trava UMA resposta (`null` = sem resposta, tempo esgotado).
  /// A última resposta entrega a tentativa e traz o resultado.
  Future<Either<Failure, AnswerOutcome>> answerQuestion({
    required String attemptId,
    required String questionId,
    Map<String, dynamic>? response,
  });

  /// Alunos da turma (para o painel do professor: "não entregou").
  Future<Either<Failure, List<ClassroomMember>>> getRoster(String classroomId);

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

  /// Lista as fases (phases) de uma sala de aula, COM gabarito.
  /// Só o professor dono consegue ler (RLS de `questions` é só do dono).
  Future<Either<Failure, List<ClassroomPhase>>> getClassroomPhases(
    String classroomId,
  );

  /// Lista as fases para o ALUNO, SEM gabarito (`get_student_phases`).
  /// O `correct_answer`/`explanation` não saem do servidor antes do envio.
  Future<Either<Failure, List<ClassroomPhase>>> getStudentPhases(
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

  /// Prazo (abertura/fechamento) e nota mínima da fase.
  Future<Either<Failure, void>> updatePhaseRules({
    required String classroomId,
    required String phaseId,
    required PhaseRules rules,
  });

  /// Questões de todas as turmas do professor logado, para reutilizar em
  /// outra fase ("Reutilizar minhas questões").
  Future<Either<Failure, List<BankQuestion>>> getQuestionBank();

  /// Copia questões do professor para o fim de uma fase (cópia, não
  /// vínculo: editar uma não muda a outra). Devolve quantas foram copiadas.
  Future<Either<Failure, int>> copyQuestionsToPhase({
    required String phaseId,
    required List<String> questionIds,
  });

  /// Exclui questões das turmas do professor pelo banco: elas somem da fase
  /// em que estão. Devolve quantas foram excluídas.
  Future<Either<Failure, int>> deleteBankQuestions({
    required List<String> questionIds,
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
