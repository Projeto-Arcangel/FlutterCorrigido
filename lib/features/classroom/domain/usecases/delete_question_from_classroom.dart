import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/classroom_repository.dart';

/// Professor exclui uma questão da sala de aula.
class DeleteQuestionFromClassroom {
  final ClassroomRepository _repository;
  const DeleteQuestionFromClassroom(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String questionId,
  }) {
    if (questionId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('ID da questão inválido')),
      );
    }
    return _repository.deleteQuestion(
      classroomId: classroomId,
      questionId: questionId,
    );
  }
}
