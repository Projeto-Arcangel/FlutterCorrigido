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
    String? studentId,
  }) async {
    final result = await _authRepository.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
    );
    return result.fold(
      Left.new,
      (user) async {
        final userWithId = studentId != null && studentId.isNotEmpty
            ? User(
                id: user.id,
                email: user.email,
                displayName: user.displayName,
                photoUrl: user.photoUrl,
                role: user.role,
                studentId: studentId,
              )
            : user;
        await _userRepository.createProfileIfAbsent(userWithId);
        return Right(userWithId);
      },
    );
  }
}