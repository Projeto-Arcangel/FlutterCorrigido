import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../data/datasources/enem_supabase_datasource.dart';
import '../../data/repositories/enem_repository_impl.dart';
import '../../domain/entities/enem_question.dart';
import '../../domain/repositories/enem_repository.dart';

// ─── Infraestrutura ────────────────────────────────────────────

final enemDatasourceProvider = Provider<EnemSupabaseDatasource>((ref) {
  return EnemSupabaseDatasource(ref.watch(supabaseClientProvider));
});

final enemRepositoryProvider = Provider<EnemRepository>((ref) {
  return EnemRepositoryImpl(
    ref.watch(enemDatasourceProvider),
    ref.watch(loggerProvider),
  );
});

// ─── Parâmetros de busca (imutável → chave do FutureProvider.family) ──

class EnemQuery extends Equatable {
  const EnemQuery({
    this.year,
    this.discipline,
    this.language,
    this.search = '',
    this.onlyWithoutImages = false,
    this.limit = 30,
  });

  final int? year;
  final String? discipline;
  final String? language; // null = qualquer idioma; '' = sem idioma
  final String search;
  final bool onlyWithoutImages;
  final int limit;

  EnemQuery copyWith({
    int? year,
    bool clearYear = false,
    String? discipline,
    bool clearDiscipline = false,
    String? language,
    bool clearLanguage = false,
    String? search,
    bool? onlyWithoutImages,
    int? limit,
  }) {
    return EnemQuery(
      year: clearYear ? null : (year ?? this.year),
      discipline: clearDiscipline ? null : (discipline ?? this.discipline),
      language: clearLanguage ? null : (language ?? this.language),
      search: search ?? this.search,
      onlyWithoutImages: onlyWithoutImages ?? this.onlyWithoutImages,
      limit: limit ?? this.limit,
    );
  }

  @override
  List<Object?> get props =>
      [year, discipline, language, search, onlyWithoutImages, limit];
}

// ─── Busca ─────────────────────────────────────────────────────

/// Resultados da busca para os parâmetros [query]. Limitado a `query.limit`
/// (aumente o limit para "carregar mais").
final enemSearchProvider = FutureProvider.autoDispose
    .family<List<EnemQuestion>, EnemQuery>((ref, query) async {
  final repo = ref.watch(enemRepositoryProvider);
  final result = await repo.search(
    year: query.year,
    discipline: query.discipline,
    language: query.language,
    search: query.search,
    onlyWithoutImages: query.onlyWithoutImages,
    limit: query.limit,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (questions) => questions,
  );
});
