import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Inicia o login com Google. Na web faz redirect (OAuth) — a sessão chega
  /// depois via [authStateChanges], então não há `User` para retornar aqui.
  Future<Either<Failure, void>> signInWithGoogle();

  Future<Either<Failure, void>> signOut();

  Stream<User?> get authStateChanges;

  Future<Either<Failure, User>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? studentId,
  });

  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  });

  /// Define uma nova senha para a sessão atual (usado na recuperação de senha,
  /// após o link de reset abrir o app com uma sessão de `passwordRecovery`).
  Future<Either<Failure, void>> updatePassword({
    required String newPassword,
  });

  Future<Either<Failure, void>> updateDisplayName({required String name});

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, void>> deleteAccount({String? password});
}