import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/user_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../models/user_progress_model.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  ProgressRepositoryImpl(this._firestore, this._logger);

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('Users').doc(userId);

  @override
  Future<Either<Failure, UserProgress>> getProgress(String userId) async {
    try {
      final doc = await _userDoc(userId).get();
      if (!doc.exists) {
        return const Left(NetworkFailure('Perfil do usuário não encontrado.'));
      }
      return Right(UserProgressModel.fromSnapshot(doc));
    } catch (e, st) {
      _logger.e('getProgress failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar progresso.'));
    }
  }

  @override
  Future<Either<Failure, UserProgress>> addXp({
    required String userId,
    required double amount,
  }) async {
    try {
      await _userDoc(userId).update({
        'xp': FieldValue.increment(amount),
      });
      return getProgress(userId);
    } catch (e, st) {
      _logger.e('addXp failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao salvar XP.'));
    }
  }

  @override
  Future<Either<Failure, void>> advancePhase({
    required String userId,
    required int newPhase,
  }) async {
    try {
      await _userDoc(userId).update({'faseAtual': newPhase});
      return const Right(null);
    } catch (e, st) {
      _logger.e('advancePhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao avançar fase.'));
    }
  }
}