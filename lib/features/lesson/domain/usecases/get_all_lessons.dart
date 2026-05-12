import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/lesson.dart';
import '../repositories/lesson_repository.dart';

class GetAllLessons {
  final LessonRepository _repository;
  const GetAllLessons(this._repository);

  Future<Either<Failure, List<Lesson>>> call() => _repository.getAllLessons();
}