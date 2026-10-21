import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';
import 'ia_model_option.dart';

/// Resultado da chamada à Edge Function `generate-questions`.
///
/// Carrega as questões geradas + metadados sobre qual modelo
/// efetivamente respondeu (pode ter sido um fallback).
class IaGenerationResult extends Equatable {
  /// Questões geradas pela IA, prontas para virarem [IaQuestionDraft]
  /// na tela de revisão.
  final List<Question> questions;

  /// Modelo que efetivamente respondeu — pode ser diferente do que
  /// o professor escolheu, caso o backend tenha usado fallback.
  final IaModelOption modelUsed;

  /// True se o modelo usado foi diferente do preferido pelo professor.
  /// O UI pode usar isso para mostrar um aviso "Gerado com X em vez de Y".
  final bool usedFallback;

  /// Questões que a IA mandou mas não couberam numa grade (cruzadinha ou
  /// caça-palavras) e ficaram de fora — a revisão avisa.
  final int skipped;

  const IaGenerationResult({
    required this.questions,
    required this.modelUsed,
    required this.usedFallback,
    this.skipped = 0,
  });

  @override
  List<Object?> get props => [questions, modelUsed, usedFallback, skipped];
}
