import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/firebase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../data/datasources/firebase_functions_ia_datasource.dart';
import '../../data/repositories/ia_quiz_repository_impl.dart';
import '../../domain/entities/ia_generation_result.dart';
import '../../domain/entities/ia_model_option.dart';
import '../../domain/repositories/ia_quiz_repository.dart';
import '../../domain/usecases/generate_questions_with_ia.dart';

// ─── Infraestrutura ────────────────────────────────────────────

final iaQuizDatasourceProvider = Provider<FirebaseFunctionsIaDatasource>((ref) {
  return FirebaseFunctionsIaDatasource(ref.watch(firebaseFunctionsProvider));
});

final iaQuizRepositoryProvider = Provider<IaQuizRepository>((ref) {
  return IaQuizRepositoryImpl(
    ref.watch(iaQuizDatasourceProvider),
    ref.watch(loggerProvider),
  );
});

// ─── Use Cases ─────────────────────────────────────────────────

final generateQuestionsWithIaProvider = Provider<GenerateQuestionsWithIa>(
  (ref) => GenerateQuestionsWithIa(ref.watch(iaQuizRepositoryProvider)),
);

// ─── Estado da geração ─────────────────────────────────────────

/// Notifier que controla o ciclo de vida da geração de questões.
///
/// Estados:
/// - `AsyncData(null)`  → idle (tela acabou de abrir).
/// - `AsyncLoading()`   → chamando a Cloud Function.
/// - `AsyncData(result)`→ geração concluída.
/// - `AsyncError(...)`  → falhou (mensagem fica no error).
class IaGenerationNotifier extends AsyncNotifier<IaGenerationResult?> {
  @override
  Future<IaGenerationResult?> build() async => null;

  Future<void> generate({
    required String topic,
    required String difficulty,
    required int quantity,
    required String description,
    required IaModelOption model,
  }) async {
    state = const AsyncLoading();
    final useCase = ref.read(generateQuestionsWithIaProvider);
    final result = await useCase(
      topic: topic,
      difficulty: difficulty,
      quantity: quantity,
      description: description,
      model: model,
    );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      AsyncData.new,
    );
  }

  /// Reseta o estado para idle. Chamado ao sair da página ou após
  /// confirmar a navegação para a tela de revisão.
  void reset() {
    state = const AsyncData(null);
  }
}

final iaGenerationNotifierProvider =
    AsyncNotifierProvider<IaGenerationNotifier, IaGenerationResult?>(
  IaGenerationNotifier.new,
);
