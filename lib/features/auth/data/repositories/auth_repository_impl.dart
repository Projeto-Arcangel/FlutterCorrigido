import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:logger/logger.dart';

import '../../../../core/errors/auth_failure.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final Logger _logger;

  AuthRepositoryImpl(this._firebaseAuth, this._logger);

  @override
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return const Left(AuthFailure('Usuário não encontrado'));
      }
      return Right(_mapToEntity(user));
    } on fb.FirebaseAuthException catch (e, st) {
      _logger.e('Auth error', error: e, stackTrace: st);
      return Left(AuthFailure.fromFirebase(e));
    } catch (e, st) {
      _logger.e('Unknown auth error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() async {
    // TODO: implementar com google_sign_in no Passo 3
    return const Left(UnknownFailure('Google Sign-In ainda não implementado'));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _firebaseAuth.signOut();
      return const Right(null);
    } catch (e, st) {
      _logger.e('Sign-out error', error: e, stackTrace: st);
      return const Left(UnknownFailure('Falha ao sair'));
    }
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges().map(
        (user) => user == null ? null : _mapToEntity(user),
      );

  User _mapToEntity(fb.User user) => User(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
}