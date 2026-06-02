import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enem_question_model.dart';

/// Acesso de leitura à tabela `enem_questions` (banco de questões do ENEM).
/// A RLS libera SELECT para usuários autenticados.
class EnemSupabaseDatasource {
  EnemSupabaseDatasource(this._client);

  final SupabaseClient _client;

  Future<List<EnemQuestionModel>> search({
    int? year,
    String? discipline,
    String? language,
    String? search,
    bool onlyWithoutImages = false,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = _client.from('enem_questions').select();

    if (year != null) query = query.eq('year', year);
    if (discipline != null && discipline.isNotEmpty) {
      query = query.eq('discipline', discipline);
    }
    if (language != null) query = query.eq('language', language);
    if (onlyWithoutImages) query = query.eq('has_image', false);

    if (search != null && search.trim().isNotEmpty) {
      // Remove caracteres que quebrariam a sintaxe do filtro `or`.
      final term = search.trim().replaceAll(RegExp(r'[,()*%]'), ' ');
      query = query.or(
        'context.ilike.*$term*,alternatives_introduction.ilike.*$term*',
      );
    }

    final rows = await query
        .order('year', ascending: false)
        .order('index', ascending: true)
        .range(offset, offset + limit - 1);

    return (rows as List)
        .map((e) => EnemQuestionModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
