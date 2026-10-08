import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/ia_generation_result.dart';
import '../entities/ia_model_option.dart';
import '../entities/study_material.dart';

/// Contrato do repositório responsável por gerar questões via IA.
///
/// Implementado por `IaQuizRepositoryImpl` na camada data/.
abstract class IaQuizRepository {
  /// Gera questões através da Cloud Function `generateQuestionsAI`,
  /// que por sua vez roteia para o OpenRouter com fallback automático.
  Future<Either<Failure, IaGenerationResult>> generateQuestions({
    required String topic,
    required String difficulty,
    required int quantity,
    required int alternatives,
    required String description,
    required IaModelOption model,
    String? subject,

    /// Materiais do professor ("Dos meus materiais"). Vazio = geração por
    /// tema; com materiais não há tema, e o foco vai em [description].
    List<MaterialForAi> materials = const [],
  });
}
