import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository _authRepository;

  const RegisterUser(this._authRepository);

  /// Cria a conta. Nome e prontuário vão no metadata do signUp — com a
  /// confirmação de e-mail ligada NÃO há sessão logo após o cadastro, então
  /// quem grava o perfil é o trigger `handle_new_user` (server-side). O aluno
  /// só entra de fato depois de confirmar o e-mail.
  Future<Either<Failure, User>> call({
    required String email,
    required String password,
    required String displayName,
    String? studentId,
  }) {
    return _authRepository.registerWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      studentId: studentId,
    );
  }
}