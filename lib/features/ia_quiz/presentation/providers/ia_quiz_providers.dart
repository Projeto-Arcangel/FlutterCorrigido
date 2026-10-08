import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../data/datasources/supabase_ia_datasource.dart';
import '../../data/repositories/ia_quiz_repository_impl.dart';
import '../../domain/entities/ia_generation_result.dart';
import '../../domain/entities/ia_model_option.dart';
import '../../domain/entities/study_material.dart';
import '../../domain/repositories/ia_quiz_repository.dart';
import '../../domain/usecases/generate_questions_with_ia.dart';

// ─── Infraestrutura ────────────────────────────────────────────

final iaQuizDatasourceProvider = Provider<SupabaseIaDatasource>((ref) {
  return SupabaseIaDatasource(ref.watch(supabaseClientProvider));
});

final iaQuizRepositoryProvider = Provider<IaQuizRepository>((ref) {
  return IaQuizRepositoryImpl(
    ref.watch(iaQuizDatasourceProvider),
    ref.watch(loggerProvider),
  );
});

/// Cota diária de IA do professor logado — alimenta o indicador
/// "X de N questões" na tela de criação. Invalidado após cada geração.
final aiDailyQuotaProvider =
    FutureProvider.autoDispose<({int used, int limit, int remaining})>((ref) {
  return ref.watch(iaQuizDatasourceProvider).fetchDailyQuota();
});

// ─── Use Cases ─────────────────────────────────────────────────

final generateQuestionsWithIaProvider = Provider<GenerateQuestionsWithIa>(
  (ref) => GenerateQuestionsWithIa(ref.watch(iaQuizRepositoryProvider)),
);

// ─── Estado da geração ─────────────────────────────────────────

/// Para onde levar as questões geradas: título e dificuldade mostrados na
/// revisão e a turma/fase em que elas serão salvas. Guardado quando a
/// geração começa, porque o professor pode sair da tela antes do fim.
class IaReviewTarget {
  const IaReviewTarget({
    required this.title,
    required this.difficultyLabel,
    this.classroomId,
    this.phaseId,
    this.phaseTitle,
  });

  final String title;
  final String difficultyLabel;
  final String? classroomId;
  final String? phaseId;
  final String? phaseTitle;
}

/// Geração concluída, esperando o professor abrir a revisão.
class IaGenerationOutcome {
  const IaGenerationOutcome({required this.result, required this.target});

  final IaGenerationResult result;
  final IaReviewTarget target;

  /// Parâmetros da rota de revisão. [fromCreation]: a tela de criação está
  /// logo abaixo na pilha, e a revisão volta as duas ao salvar.
  Map<String, Object?> reviewExtra({required bool fromCreation}) => {
        'result': result,
        'topic': target.title,
        'difficulty': target.difficultyLabel,
        'classroomId': target.classroomId,
        'phaseId': target.phaseId,
        'phaseTitle': target.phaseTitle,
        'fromCreation': fromCreation,
      };
}

/// Notifier que controla o ciclo de vida da geração de questões.
///
/// A geração continua se o professor sair da tela de criação: o resultado
/// fica guardado aqui até ele abrir a revisão — pela própria tela, se ela
/// estiver aberta, ou pelo aviso global (IaGenerationWatcher).
///
/// Estados:
/// - `AsyncData(null)`    → nada em andamento nem esperando revisão.
/// - `AsyncLoading()`     → chamando a Edge Function.
/// - `AsyncData(outcome)` → questões prontas, esperando a revisão.
/// - `AsyncError(...)`    → falhou (mensagem fica no error).
class IaGenerationNotifier extends AsyncNotifier<IaGenerationOutcome?> {
  /// Telas de criação abertas agora: aberta, a tela trata o resultado;
  /// fechada, o aviso global trata.
  int _openScreens = 0;

  /// Muda a cada geração e ao trocar de conta: um resultado que chega
  /// depois disso é descartado (não aparece para outro usuário).
  int _run = 0;

  @override
  Future<IaGenerationOutcome?> build() async {
    ref.listen(
      authStateProvider.select((auth) => auth.valueOrNull?.id),
      (previous, next) {
        if (previous != null && previous != next) {
          _run++;
          state = const AsyncData(null);
        }
      },
    );
    return null;
  }

  bool get hasOpenScreen => _openScreens > 0;

  void attachScreen() => _openScreens++;

  void detachScreen() => _openScreens--;

  Future<void> generate({
    required String topic,
    required String difficulty,
    required int quantity,
    required int alternatives,
    required String description,
    required IaModelOption model,
    required IaReviewTarget target,
    String? subject,
    List<MaterialForAi>? materials,
  }) async {
    final run = ++_run;
    state = const AsyncLoading();
    final useCase = ref.read(generateQuestionsWithIaProvider);
    final result = await useCase(
      topic: topic,
      difficulty: difficulty,
      quantity: quantity,
      alternatives: alternatives,
      description: description,
      model: model,
      subject: subject,
      materials: materials,
    );
    if (run != _run) return;

    // A geração pode ter consumido cota: o indicador "X de N" se atualiza.
    ref.invalidate(aiDailyQuotaProvider);
    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (generated) => AsyncData(
        IaGenerationOutcome(result: generated, target: target),
      ),
    );
  }

  /// Entrega o resultado que espera revisão, uma única vez, e volta ao
  /// estado inicial. `null` se não há resultado esperando.
  IaGenerationOutcome? take() {
    if (state.isLoading) return null;
    final outcome = state.valueOrNull;
    if (outcome == null) return null;
    state = const AsyncData(null);
    return outcome;
  }

  /// Volta ao estado inicial (ex.: depois de mostrar um erro).
  void reset() {
    state = const AsyncData(null);
  }
}

final iaGenerationNotifierProvider =
    AsyncNotifierProvider<IaGenerationNotifier, IaGenerationOutcome?>(
  IaGenerationNotifier.new,
);
