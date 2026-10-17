import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/classmate_profile.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../models/achievement_model.dart';

/// Conquistas e perfil do colega pelas RPCs `SECURITY DEFINER`
/// (`my_achievements`, `get_classmate_profile`): o app nunca grava conquista
/// nem lê `user_achievements` de outro aluno direto.
class AchievementsRepositoryImpl implements AchievementsRepository {
  AchievementsRepositoryImpl(this._client, this._logger);

  final SupabaseClient _client;
  final Logger _logger;

  @override
  Future<Either<Failure, MyAchievements>> getMyAchievements() async {
    try {
      final data = await _client.rpc<dynamic>('my_achievements');
      if (data is! Map) {
        return const Left(
          NetworkFailure('Resposta inesperada das conquistas.'),
        );
      }
      return Right(AchievementModel.mine(Map<String, dynamic>.from(data)));
    } catch (e, st) {
      _logger.e('getMyAchievements failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar as conquistas.'));
    }
  }

  @override
  Future<Either<Failure, ClassmateProfile?>> getClassmateProfile({
    required String classroomId,
    required String studentId,
  }) async {
    try {
      final data = await _client.rpc<dynamic>(
        'get_classmate_profile',
        params: {'p_classroom': classroomId, 'p_student': studentId},
      );
      if (data == null) return const Right(null);
      if (data is! Map) {
        return const Left(NetworkFailure('Resposta inesperada do perfil.'));
      }
      return Right(AchievementModel.classmate(Map<String, dynamic>.from(data)));
    } catch (e, st) {
      _logger.e('getClassmateProfile failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar o perfil.'));
    }
  }
}
