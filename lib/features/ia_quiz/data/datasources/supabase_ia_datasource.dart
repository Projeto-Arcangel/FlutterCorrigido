import 'package:supabase_flutter/supabase_flutter.dart';

/// Datasource que invoca a Edge Function `generate-questions` (Supabase).
///
/// Substitui a antiga Cloud Function `generateQuestionsAI`.
///
/// `functions.invoke` lança [FunctionException] em respostas não-2xx
/// (401 não-autenticado, 403 não-professor, 400 input inválido, 500 falha da
/// IA com `{ error, attempts }`). O repository converte para [Failure].
class SupabaseIaDatasource {
  SupabaseIaDatasource(this._client);

  final SupabaseClient _client;

  /// Invoca a função e retorna o payload bruto
  /// (`{ questions: [...], modelUsed: '...', attempts: [...] }`).
  Future<Map<String, dynamic>> generateQuestions({
    required String topic,
    required String difficulty,
    required int quantity,
    required String description,
    required String modelKey,
    String subject = 'História do Brasil',
  }) async {
    final res = await _client.functions.invoke(
      'generate-questions',
      body: {
        'subject': subject,
        'topic': topic,
        'difficulty': difficulty,
        'quantity': quantity,
        'description': description,
        'modelKey': modelKey,
      },
    );

    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FunctionException(
      status: 500,
      details: 'Resposta inesperada da função generate-questions.',
    );
  }
}
