import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/enem_question.dart';
import '../../domain/repositories/enem_repository.dart';
import '../datasources/enem_supabase_datasource.dart';

class EnemRepositoryImpl implements EnemRepository {
  EnemRepositoryImpl(this._datasource, this._logger);

  final EnemSupabaseDatasource _datasource;
  final Logger _logger;

  @override
  Future<Either<Failure, List<EnemQuestion>>> search({
    int? year,
    String? discipline,
    String? language,
    String? search,
    bool onlyWithoutImages = false,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final result = await _datasource.search(
        year: year,
        discipline: discipline,
        language: language,
        search: search,
        onlyWithoutImages: onlyWithoutImages,
        limit: limit,
        offset: offset,
      );
      return Right(result);
    } catch (e, st) {
      _logger.e('enem search failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao buscar questões do ENEM.'));
    }
  }
}
