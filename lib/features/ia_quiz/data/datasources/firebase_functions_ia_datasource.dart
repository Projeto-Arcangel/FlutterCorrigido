import 'package:cloud_functions/cloud_functions.dart';

/// Datasource que invoca a Cloud Function `generateQuestionsAI`.
///
/// A region precisa casar com a configurada no deploy
/// (`southamerica-east1` em `firebase/functions/index.js`).
/// Se divergir, o SDK aponta para `us-central1` e a chamada falha com 404.
class FirebaseFunctionsIaDatasource {
  FirebaseFunctionsIaDatasource(this._functions);

  final FirebaseFunctions _functions;

  /// Invoca a Cloud Function e retorna o payload bruto
  /// (`{ questions: [...], modelUsed: '...', attempts: [...] }`).
  ///
  /// Lança [FirebaseFunctionsException] em erros (auth, permission,
  /// internal). O repository converte para [Failure].
  Future<Map<String, dynamic>> generateQuestions({
    required String topic,
    required String difficulty,
    required int quantity,
    required String description,
    required String modelKey,
    String subject = 'História do Brasil',
  }) async {
    final callable = _functions.httpsCallable(
      'generateQuestionsAI',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 90),
      ),
    );

    final response = await callable.call<Map<Object?, Object?>>({
      'subject': subject,
      'topic': topic,
      'difficulty': difficulty,
      'quantity': quantity,
      'description': description,
      'modelKey': modelKey,
    });

    return Map<String, dynamic>.from(response.data);
  }
}
