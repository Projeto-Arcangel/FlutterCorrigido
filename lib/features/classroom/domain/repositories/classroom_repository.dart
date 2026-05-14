import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../entities/classroom.dart';
import '../entities/classroom_phase.dart';
import '../entities/classroom_result.dart';

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
  });

  /// Atualiza nome e/ou descrição da sala.
  Future<Either<Failure, void>> updateClassroom({
    required String classroomId,
    required String name,
    required String description,
  });

  /// Busca uma sala pelo código de 6 caracteres.
  Future<Either<Failure, Classroom>> getClassroomByCode(String code);

  /// Lista todas as salas de um professor.
  Future<Either<Failure, List<Classroom>>> getTeacherClassrooms(
    String teacherId,
  );

  /// Retorna a sala em que o aluno está (ou null se não está em nenhuma).
  Future<Either<Failure, Classroom?>> getStudentClassroom(String studentId);

  // ─── Aluno entra/sai ──────────────────────────────────────────

  /// Adiciona o aluno à sala (max 50). Falha se já está em outra sala.
  Future<Either<Failure, void>> joinClassroom({
    required String classroomId,
    required String studentId,
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

  /// Salva o resultado do aluno após completar o quiz.
  Future<Either<Failure, void>> submitResult({
    required String classroomId,
    required ClassroomResult result,
  });

  /// Retorna os resultados de todos os alunos de uma sala (para o professor).
  Future<Either<Failure, List<ClassroomResult>>> getResults(
    String classroomId,
  );

  // ─── Fases (quiz → fase no Firestore) ─────────────────────────

  /// Cria uma fase (Phase) no Firestore vinculada a uma sala de aula.
  ///
  /// A fase fica acessível somente para os alunos daquela sala.
  /// As questões são criadas na coleção `Questions` com `phase_ref`
  /// apontando para o documento da fase criada.
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
}
