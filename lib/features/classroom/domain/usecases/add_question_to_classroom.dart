import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../repositories/classroom_repository.dart';

/// Professor adiciona uma questão à sala de aula.
class AddQuestionToClassroom {
  final ClassroomRepository _repository;
  const AddQuestionToClassroom(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required Question question,
  }) {
    if (question.text.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('O enunciado não pode ser vazio')),
      );
    }
    if (question.options.length < 2) {
      return Future.value(
        const Left(
          ValidationFailure('A questão precisa de pelo menos 2 alternativas'),
        ),
      );
    }
    return _repository.addQuestion(
      classroomId: classroomId,
      question: question,
    );
  }
}
