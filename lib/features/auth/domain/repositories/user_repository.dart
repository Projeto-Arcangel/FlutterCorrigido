import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user.dart';

abstract class UserRepository {
  /// Cria o documento do usuário no Firestore se ainda não existir.
  Future<Either<Failure, void>> createProfileIfAbsent(User user);

  /// Verifica se o documento do usuário já existe no Firestore.
  /// Usado para detectar se é a primeira vez que o usuário entra via Google.
  Future<Either<Failure, bool>> hasProfile(String userId);

  /// Atualiza nome e prontuário no perfil existente do usuário.
  /// Usado após a tela de completar perfil (Google Sign-In, primeira vez).
  Future<Either<Failure, void>> updateProfile({
    required String userId,
    required String displayName,
    required String studentId,
  });

  /// Retorna o role salvo em `Users/{userId}.role`.
  ///
  /// `null` significa que o documento existe mas o campo `role` não está
  /// preenchido — é o sinal usado pelo router para forçar a passagem pela
  /// `RoleSelectionPage`. Documento inexistente também retorna `null`.
  Future<Either<Failure, UserRole?>> getRole(String userId);

  /// Grava `role` em `Users/{userId}.role` usando merge — não sobrescreve
  /// xp, level, gold, etc. Cria o documento se ainda não existir.
  Future<Either<Failure, void>> setRole({
    required String userId,
    required UserRole role,
  });
}
