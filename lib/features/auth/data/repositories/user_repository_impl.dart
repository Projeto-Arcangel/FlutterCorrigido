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

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('Users').doc(userId);

  @override
  Future<Either<Failure, void>> createProfileIfAbsent(User user) async {
    try {
      final doc = _userDoc(user.id);
      final snap = await doc.get();
      if (snap.exists) return const Right(null);

      // `role` propositalmente AUSENTE — o usuário ainda não escolheu.
      // O router observa essa ausência via `currentUserRoleProvider` e
      // força a passagem pela `RoleSelectionPage`.
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

  @override
  Future<Either<Failure, UserRole?>> getRole(String userId) async {
    try {
      final snap = await _userDoc(userId).get();
      if (!snap.exists) return const Right(null);
      final data = snap.data();
      final raw = data?['role'] as String?;
      return Right(userRoleFromString(raw));
    } catch (e, st) {
      _logger.e('getRole failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar role do usuário.'));
    }
  }

  @override
  Future<Either<Failure, void>> setRole({
    required String userId,
    required UserRole role,
  }) async {
    try {
      await _userDoc(userId).set(
        {'role': role.name},
        SetOptions(merge: true),
      );
      return const Right(null);
    } catch (e, st) {
      _logger.e('setRole failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao salvar role do usuário.'));
    }
  }
}