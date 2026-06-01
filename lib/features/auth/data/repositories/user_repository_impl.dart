import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../../core/errors/failure.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

/// Implementação do [UserRepository] sobre o Supabase (tabela `profiles`).
///
/// O perfil em si é criado pelo trigger `handle_new_user` no signup; aqui
/// tratamos leitura/atualização de campos do perfil e do `role`.
class UserRepositoryImpl implements UserRepository {
  final SupabaseClient _client;
  final Logger _logger;

  UserRepositoryImpl(this._client, this._logger);

  SupabaseQueryBuilder get _profiles => _client.from('profiles');

  @override
  Future<Either<Failure, void>> createProfileIfAbsent(User user) async {
    // O row de `profiles` já existe (trigger handle_new_user). Apenas
    // completamos nome/prontuário quando fornecidos (registro/Google).
    try {
      final updates = <String, dynamic>{};
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        updates['display_name'] = user.displayName;
      }
      if (user.studentId != null && user.studentId!.isNotEmpty) {
        updates['student_id'] = user.studentId;
      }
      if (updates.isNotEmpty) {
        await _profiles.update(updates).eq('id', user.id);
      }
      return const Right(null);
    } catch (e, st) {
      _logger.e('createProfileIfAbsent failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao criar perfil do usuário.'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasProfile(String userId) async {
    try {
      final row = await _profiles.select('id').eq('id', userId).maybeSingle();
      return Right(row != null);
    } catch (e, st) {
      _logger.e('hasProfile failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao verificar perfil do usuário.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile({
    required String userId,
    required String displayName,
    required String studentId,
  }) async {
    try {
      await _profiles.update({
        'display_name': displayName,
        'student_id': studentId,
      }).eq('id', userId);
      return const Right(null);
    } catch (e, st) {
      _logger.e('updateProfile failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao atualizar perfil do usuário.'));
    }
  }

  @override
  Future<Either<Failure, UserRole?>> getRole(String userId) async {
    try {
      final row = await _profiles.select('role').eq('id', userId).maybeSingle();
      if (row == null) return const Right(null);
      return Right(userRoleFromString(row['role'] as String?));
    } catch (e, st) {
      _logger.e('getRole failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar role do usuário.'));
    }
  }

  @override
  Future<Either<Failure, void>> setRole({
    required String userId,
    required UserRole role,
  }) async {
    try {
      // A escrita direta de `role` é bloqueada pelo trigger anti-escalada.
      // A RPC set_role (SECURITY DEFINER) altera o role do próprio uid.
      await _client.rpc<void>('set_role', params: {'p_role': role.name});
      return const Right(null);
    } catch (e, st) {
      _logger.e('setRole failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao salvar role do usuário.'));
    }
  }
}
