import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/auth_repository.dart';

/// Inicia o login com Google.
///
/// Na web o Supabase faz um **redirect de página inteira** para o Google e,
/// na volta, detecta a sessão pela URL e a emite em `authStateChanges`. Por
/// isso não há `User` para retornar aqui — o roteamento (incluindo mandar um
/// usuário novo para completar o perfil) é decidido pelo router a partir do
/// estado de autenticação resultante.
class SignInWithGoogle {
  final AuthRepository _authRepository;

  const SignInWithGoogle(this._authRepository);

  Future<Either<Failure, void>> call() => _authRepository.signInWithGoogle();
}