import 'package:firebase_auth/firebase_auth.dart';
import 'failure.dart';

class AuthFailure extends Failure {
  const AuthFailure(super.message);

  factory AuthFailure.fromFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const AuthFailure('Usuário não encontrado.');
      case 'wrong-password':
        return const AuthFailure('Senha incorreta.');
      case 'invalid-email':
        return const AuthFailure('E-mail inválido.');
      case 'email-already-in-use':
        return const AuthFailure('E-mail já cadastrado.');
      case 'weak-password':
        return const AuthFailure('Senha muito fraca.');
      case 'network-request-failed':
        return const AuthFailure('Sem conexão com a internet.');
      case 'requires-recent-login':
        return const AuthFailure('Por segurança, faça login novamente antes de realizar esta ação.');
      case 'invalid-credential':
        return const AuthFailure('Credenciais inválidas. Verifique sua senha.');
      default:
        return AuthFailure(e.message ?? 'Erro de autenticação.');
    }
  }
}