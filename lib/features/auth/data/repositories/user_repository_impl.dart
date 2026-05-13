import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  UserRepositoryImpl(this._firestore, this._logger);

  @override
  Future<Either<Failure, void>> createProfileIfAbsent(User user) async {
    try {
      final doc = _firestore.collection('Users').doc(user.id);
      final snap = await doc.get();
      if (snap.exists) return const Right(null);

      await doc.set({
        'display_name': user.displayName ?? '',
        'email': user.email,
        'photo_url': user.photoUrl ?? '',
        'xp': 0.0,
        'level': 1,
        'gold': 0,
        'faseAtual': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
      return const Right(null);
    } catch (e, st) {
      _logger.e('createProfileIfAbsent failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao criar perfil do usuário.'));
    }
  }
}