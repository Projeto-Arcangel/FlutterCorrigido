import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/auth_failure.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepositoryImpl(this._firebaseAuth, this._googleSignIn, this._logger);

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
    try {
      fb.UserCredential userCredential;

      if (kIsWeb) {
        final provider = fb.GoogleAuthProvider();
        userCredential = await _firebaseAuth.signInWithPopup(provider);
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return const Left(AuthFailure('Login cancelado pelo usuário'));
        }
        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user == null) return const Left(AuthFailure('Usuário não encontrado'));
      return Right(_mapToEntity(user));
    } on fb.FirebaseAuthException catch (e, st) {
      _logger.e('Google auth error', error: e, stackTrace: st);
      return Left(AuthFailure.fromFirebase(e));
    } catch (e, st) {
      _logger.e('Google sign-in error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
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

  @override
  Future<Either<Failure, User>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return const Left(AuthFailure('Falha ao criar conta'));
      await user.updateDisplayName(displayName);
      await user.sendEmailVerification();
      return Right(_mapToEntity(user));
    } on fb.FirebaseAuthException catch (e, st) {
      _logger.e('Register error', error: e, stackTrace: st);
      return Left(AuthFailure.fromFirebase(e));
    } catch (e, st) {
      _logger.e('Unknown register error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  }) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return const Right(null);
    } on fb.FirebaseAuthException catch (e, st) {
      _logger.e('Password reset error', error: e, stackTrace: st);
      return Left(AuthFailure.fromFirebase(e));
    } catch (e, st) {
      _logger.e('Unknown password reset error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  User _mapToEntity(fb.User user) => User(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        // TODO: ler `role` de Firestore Users/{uid} quando o perfil de
        // professor for implementado. Por ora todo login resulta em aluno.
        role: UserRole.student,
      );
}