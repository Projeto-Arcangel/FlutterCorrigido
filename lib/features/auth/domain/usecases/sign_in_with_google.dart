import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

/// Resultado do Google Sign-In.
///
/// [user]           → usuário autenticado.
/// [isNewGoogleUser] → `true` quando é a primeira vez que este usuário
///                     entra via Google (perfil ainda não existe no Firestore).
///                     O router usa essa flag para exibir a tela de completar
///                     perfil (Nome + Prontuário) antes de criar o documento.
typedef SignInWithGoogleResult = ({User user, bool isNewGoogleUser});

class SignInWithGoogle {
  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  const SignInWithGoogle(this._authRepository, this._userRepository);

  Future<Either<Failure, SignInWithGoogleResult>> call() async {
    final result = await _authRepository.signInWithGoogle();
    return result.fold(
      Left.new,
      (user) async {
        final hasProfileResult = await _userRepository.hasProfile(user.id);
        return hasProfileResult.fold(
          Left.new,
          (exists) async {
            if (exists) {
              // Usuário recorrente — perfil já existe, segue normalmente.
              return Right((user: user, isNewGoogleUser: false));
            }
            // Primeira vez — NÃO cria o perfil agora.
            // A tela GoogleCompleteProfilePage vai coletar Nome + Prontuário
            // e então chamar createProfileIfAbsent com os dados completos.
            return Right((user: user, isNewGoogleUser: true));
          },
        );
      },
    );
  }
}
