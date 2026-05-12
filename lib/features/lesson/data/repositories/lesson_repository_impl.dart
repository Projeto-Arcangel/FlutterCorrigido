import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/lesson_repository.dart';
import '../datasources/firebase/lesson_firestore_datasource.dart';

class LessonRepositoryImpl implements LessonRepository {
  LessonRepositoryImpl(this._dataSource, this._logger);

  final LessonFirestoreDataSource _dataSource;
  final Logger _logger;

  @override
  Future<Either<Failure, List<Lesson>>> getAllLessons() async {
    try {
      final lessons = await _dataSource.fetchAllLessons();
      return Right(lessons);
    } catch (e, st) {
      _logger.e('getAllLessons failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar lições'));
    }
  }

  @override
  Future<Either<Failure, Lesson>> getLessonById(String id) async {
    try {
      final lesson = await _dataSource.fetchLessonById(id);
      if (lesson == null) {
        return const Left(NetworkFailure('Lição não encontrada'));
      }
      return Right(lesson);
    } catch (e, st) {
      _logger.e('getLessonById failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar lição'));
    }
  }
}
