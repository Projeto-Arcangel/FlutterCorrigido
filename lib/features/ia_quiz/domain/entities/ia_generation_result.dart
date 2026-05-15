import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';
import 'ia_model_option.dart';

/// Resultado da chamada à Cloud Function `generateQuestionsAI`.
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

  const IaGenerationResult({
    required this.questions,
    required this.modelUsed,
    required this.usedFallback,
  });

  @override
  List<Object?> get props => [questions, modelUsed, usedFallback];
}
