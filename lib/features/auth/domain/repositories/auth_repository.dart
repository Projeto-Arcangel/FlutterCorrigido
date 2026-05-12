import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, User>> signInWithGoogle();

  Future<Either<Failure, void>> signOut();

  Stream<User?> get authStateChanges;

  Future<Either<Failure, User>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  });
}