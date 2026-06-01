import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/user_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../models/user_progress_model.dart';

/// Implementação do [ProgressRepository] sobre o Supabase.
///
/// XP/gold/fase NÃO são escritos diretamente (a RLS bloqueia): toda
/// mutação passa por RPCs `SECURITY DEFINER` (award_xp/award_gold/
/// advance_phase) que validam no servidor — à prova de trapaça.
class ProgressRepositoryImpl implements ProgressRepository {
  final SupabaseClient _client;
  final Logger _logger;

  ProgressRepositoryImpl(this._client, this._logger);

  @override
  Future<Either<Failure, UserProgress>> getProgress(String userId) async {
    try {
      final row = await _client
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        return const Left(
            NetworkFailure('Progresso do usuário não encontrado.'),);
      }
      return Right(UserProgressModel.fromMap(row));
    } catch (e, st) {
      _logger.e('getProgress failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar progresso.'));
    }
  }

  @override
  Future<Either<Failure, UserProgress>> addXp({
    required String userId,
    required double amount,
  }) async {
    try {
      // award_xp incrementa o XP e recalcula o nível no servidor.
      final data = await _client.rpc<dynamic>(
        'award_xp',
        params: {'p_amount': amount},
      );
      final map = data is List ? data.first as Map : data as Map;
      return Right(UserProgressModel.fromMap(Map<String, dynamic>.from(map)));
    } catch (e, st) {
      _logger.e('addXp failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao salvar XP.'));
    }
  }

  @override
  Future<Either<Failure, void>> addGold({
    required String userId,
    required int amount,
  }) async {
    try {
      await _client.rpc<void>('award_gold', params: {'p_amount': amount});
      return const Right(null);
    } catch (e, st) {
      _logger.e('addGold failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao adicionar gold.'));
    }
  }

  @override
  Future<Either<Failure, void>> advancePhase({
    required String userId,
    required int newPhase,
  }) async {
    try {
      await _client.rpc<void>('advance_phase', params: {'p_phase': newPhase});
      return const Right(null);
    } catch (e, st) {
      _logger.e('advancePhase failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao avançar fase.'));
    }
  }
}
