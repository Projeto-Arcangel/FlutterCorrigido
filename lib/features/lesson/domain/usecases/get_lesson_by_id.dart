import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/lesson.dart';
import '../repositories/lesson_repository.dart';

class GetLessonById {
  final LessonRepository _repository;
  const GetLessonById(this._repository);

  Future<Either<Failure, Lesson>> call(String id) {
    if (id.isEmpty) {
      return Future.value(const Left(ValidationFailure('ID inválido')));
    }
    return _repository.getLessonById(id);
  }
}