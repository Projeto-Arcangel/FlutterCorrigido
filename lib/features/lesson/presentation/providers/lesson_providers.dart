import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/firebase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../data/datasources/firebase/lesson_firestore_datasource.dart';
import '../../data/repositories/lesson_repository_impl.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/lesson_repository.dart';
import '../../domain/usecases/get_all_lessons.dart';
import '../../domain/usecases/get_lesson_by_id.dart';

final lessonFirestoreDataSourceProvider = Provider<LessonFirestoreDataSource>(
  (ref) => LessonFirestoreDataSource(ref.watch(firestoreProvider)),
);

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepositoryImpl(
    ref.watch(lessonFirestoreDataSourceProvider),
    ref.watch(loggerProvider),
  );
});

final getLessonByIdProvider = Provider<GetLessonById>((ref) {
  return GetLessonById(ref.watch(lessonRepositoryProvider));
});

final getAllLessonsProvider = Provider<GetAllLessons>((ref) {
  return GetAllLessons(ref.watch(lessonRepositoryProvider));
});

final lessonByIdProvider =
    FutureProvider.autoDispose.family<Lesson, String>((ref, id) async {
  final useCase = ref.watch(getLessonByIdProvider);
  final result = await useCase(id);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (lesson) => lesson,
  );
});

final allLessonsProvider =
    FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final useCase = ref.watch(getAllLessonsProvider);
  final result = await useCase();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (lessons) => lessons,
  );
});
