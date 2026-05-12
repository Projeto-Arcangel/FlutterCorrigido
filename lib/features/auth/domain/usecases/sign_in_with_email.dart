import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmail {
  final AuthRepository _repository;
  const SignInWithEmail(this._repository);

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
  }) {
    if (!email.contains('@')) {
      return Future.value(const Left(ValidationFailure('E-mail inválido')));
    }
    if (password.length < 6) {
      return Future.value(
        const Left(ValidationFailure('A senha deve ter ao menos 6 caracteres')),
      );
    }
    return _repository.signInWithEmail(email: email, password: password);
  }
}