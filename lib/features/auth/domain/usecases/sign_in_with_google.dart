import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository _repository;
  const SignInWithGoogle(this._repository);

  Future<Either<Failure, User>> call() => _repository.signInWithGoogle();
}
