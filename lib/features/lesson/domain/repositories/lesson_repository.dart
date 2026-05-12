import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/lesson.dart';

abstract class LessonRepository {
  Future<Either<Failure, List<Lesson>>> getAllLessons();
  Future<Either<Failure, Lesson>> getLessonById(String id);
}