import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/firebase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/user_progress.dart';
import '../../domain/repositories/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(loggerProvider),
  );
});

final userProgressProvider =
    FutureProvider.autoDispose.family<UserProgress, String>((ref, userId) async {
  final repo = ref.watch(progressRepositoryProvider);
  final result = await repo.getProgress(userId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (progress) => progress,
  );
});