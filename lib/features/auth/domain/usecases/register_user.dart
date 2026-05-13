import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

class RegisterUser {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  const RegisterUser(this._authRepository, this._userRepository);

  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final result = await _authRepository.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    return result.fold(
      Left.new,
      (user) async {
        await _userRepository.createProfileIfAbsent(user);
        return Right(user);
      },
    );
  }
}