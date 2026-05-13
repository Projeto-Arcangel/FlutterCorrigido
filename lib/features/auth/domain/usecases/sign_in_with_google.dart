import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

class SignInWithGoogle {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  const SignInWithGoogle(this._authRepository, this._userRepository);

  Future<Either<Failure, User>> call() async {
    final result = await _authRepository.signInWithGoogle();
    return result.fold(
      Left.new,
      (user) async {
        await _userRepository.createProfileIfAbsent(user);
        return Right(user);
      },
    );
  }
}
