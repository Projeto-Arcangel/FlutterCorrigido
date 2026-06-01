import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/auth_failure.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';

/// Implementação do [AuthRepository] sobre o Supabase Auth (GoTrue).
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepositoryImpl(this._client, this._googleSignIn, this._logger);

  GoTrueClient get _auth => _client.auth;

  @override
  Future<Either<Failure, domain.User>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final res =
          await _auth.signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) return const Left(AuthFailure('Usuário não encontrado'));
      return Right(_mapToEntity(user));
    } on AuthException catch (e, st) {
      _logger.e('Auth error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown auth error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, domain.User>> signInWithGoogle() async {
    try {
      // Abordagem nativa: obtém o idToken do Google e troca por sessão no
      // Supabase. Requer [auth.external.google] configurado no Supabase.
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const Left(AuthFailure('Login cancelado pelo usuário'));
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return const Left(
          AuthFailure('Não foi possível obter o token do Google.'),
        );
      }
      final res = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      final user = res.user;
      if (user == null) return const Left(AuthFailure('Usuário não encontrado'));
      return Right(_mapToEntity(user));
    } on AuthException catch (e, st) {
      _logger.e('Google auth error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Google sign-in error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _auth.signOut();
      return const Right(null);
    } catch (e, st) {
      _logger.e('Sign-out error', error: e, stackTrace: st);
      return const Left(UnknownFailure('Falha ao sair'));
    }
  }

  @override
  Stream<domain.User?> get authStateChanges => _auth.onAuthStateChange.map(
        (data) {
          final user = data.session?.user;
          return user == null ? null : _mapToEntity(user);
        },
      );

  @override
  Future<Either<Failure, domain.User>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = res.user;
      if (user == null) return const Left(AuthFailure('Falha ao criar conta'));
      return Right(_mapToEntity(user));
    } on AuthException catch (e, st) {
      _logger.e('Register error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown register error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  }) async {
    try {
      await _auth.resetPasswordForEmail(email);
      return const Right(null);
    } on AuthException catch (e, st) {
      _logger.e('Password reset error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown password reset error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> updateDisplayName({required String name}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('Usuário não autenticado'));
      }
      await _auth.updateUser(UserAttributes(data: {'display_name': name}));
      // Mantém o profiles em sincronia (fonte canônica para leituras/joins).
      await _client.from('profiles').update({'display_name': name}).eq(
            'id',
            user.id,
          );
      return const Right(null);
    } on AuthException catch (e, st) {
      _logger.e('updateDisplayName error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown updateDisplayName error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return const Left(AuthFailure('Usuário não autenticado'));
      }
      // Reautentica verificando a senha atual.
      await _auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      await _auth.updateUser(UserAttributes(password: newPassword));
      return const Right(null);
    } on AuthException catch (e, st) {
      _logger.e('changePassword error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown changePassword error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount({String? password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('Usuário não autenticado'));
      }
      // Reautentica se a senha foi fornecida (contas e-mail/senha).
      if (password != null && user.email != null) {
        await _auth.signInWithPassword(
          email: user.email!,
          password: password,
        );
      }
      // Exclusão da conta é feita server-side (RPC SECURITY DEFINER).
      await _client.rpc<void>('delete_account');
      await _auth.signOut();
      return const Right(null);
    } on AuthException catch (e, st) {
      _logger.e('deleteAccount error', error: e, stackTrace: st);
      return Left(_mapAuthError(e));
    } catch (e, st) {
      _logger.e('Unknown deleteAccount error', error: e, stackTrace: st);
      return const Left(UnknownFailure());
    }
  }

  domain.User _mapToEntity(User user) => domain.User(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
        photoUrl: (user.userMetadata?['avatar_url'] ??
            user.userMetadata?['photo_url']) as String?,
        // role real é resolvido via currentUserRoleProvider (tabela profiles).
        role: domain.UserRole.student,
      );

  AuthFailure _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return const AuthFailure('Credenciais inválidas. Verifique e-mail e senha.');
    }
    if (msg.contains('email not confirmed')) {
      return const AuthFailure('E-mail ainda não confirmado.');
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return const AuthFailure('E-mail já cadastrado.');
    }
    if (msg.contains('password should be at least')) {
      return const AuthFailure('Senha muito fraca (mínimo de 6 caracteres).');
    }
    if (msg.contains('unable to validate email address')) {
      return const AuthFailure('E-mail inválido.');
    }
    return AuthFailure(e.message);
  }
}
