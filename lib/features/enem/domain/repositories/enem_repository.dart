import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/enem_question.dart';

/// Contrato de acesso ao banco de questões do ENEM (somente leitura).
abstract class EnemRepository {
  /// Busca questões aplicando filtros. `language` = null não filtra; `''`
  /// traz só questões sem idioma; `'ingles'`/`'espanhol'` filtram o idioma.
  Future<Either<Failure, List<EnemQuestion>>> search({
    int? year,
    String? discipline,
    String? language,
    String? search,
    bool onlyWithoutImages = false,
    int limit = 30,
    int offset = 0,
  });
}
