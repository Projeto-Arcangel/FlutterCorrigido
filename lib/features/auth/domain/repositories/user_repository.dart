import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user.dart';

abstract class UserRepository {
  /// Cria o registro do usuário (tabela `profiles`) se ainda não existir.
  Future<Either<Failure, void>> createProfileIfAbsent(User user);

  /// Verifica se o registro do usuário já existe (tabela `profiles`).
  /// Usado para detectar se é a primeira vez que o usuário entra via Google.
  Future<Either<Failure, bool>> hasProfile(String userId);

  /// Atualiza nome e prontuário no perfil existente do usuário.
  /// Usado após a tela de completar perfil (Google Sign-In, primeira vez).
  Future<Either<Failure, void>> updateProfile({
    required String userId,
    required String displayName,
    required String studentId,
  });

  /// Retorna o role salvo em `profiles.role`.
  ///
  /// `null` significa que o perfil existe mas o `role` não está preenchido —
  /// é o sinal usado pelo router para forçar a passagem pela
  /// `RoleSelectionPage`. Perfil inexistente também retorna `null`.
  Future<Either<Failure, UserRole?>> getRole(String userId);

  /// Grava o `role` do próprio usuário pela RPC `set_role` (a escrita direta
  /// na coluna é bloqueada pelo trigger anti-escalada).
  Future<Either<Failure, void>> setRole({
    required String userId,
    required UserRole role,
  });
}
