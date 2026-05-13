import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user_progress.dart';

abstract class ProgressRepository {
  Future<Either<Failure, UserProgress>> getProgress(String userId);

  Future<Either<Failure, UserProgress>> addXp({
    required String userId,
    required double amount,
  });

  Future<Either<Failure, void>> advancePhase({
    required String userId,
    required int newPhase,
  });

  Future<Either<Failure, void>> addGold({
    required String userId,
    required int amount,
  });
}