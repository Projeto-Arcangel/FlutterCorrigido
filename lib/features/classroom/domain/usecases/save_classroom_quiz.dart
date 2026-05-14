import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../entities/classroom_phase.dart';
import '../repositories/classroom_repository.dart';

/// Salva um questionário criado pelo professor como uma fase (Phase)
/// vinculada à sala de aula dele.
///
/// A fase criada só será visível para os alunos que estão na sala.
class SaveClassroomQuiz {
  final ClassroomRepository _repository;
  const SaveClassroomQuiz(this._repository);

  Future<Either<Failure, ClassroomPhase>> call({
    required String classroomId,
    required String title,
    required String description,
    required List<Question> questions,
  }) {
    // Validações básicas.
    if (classroomId.isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure('Você precisa ter uma turma ativa para salvar'),
        ),
      );
    }
    if (title.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('O título do quiz não pode ser vazio')),
      );
    }
    if (questions.isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure('O quiz precisa ter pelo menos 1 questão'),
        ),
      );
    }

    return _repository.saveQuizAsPhase(
      classroomId: classroomId,
      title: title.trim(),
      description: description.trim(),
      questions: questions,
    );
  }
}
