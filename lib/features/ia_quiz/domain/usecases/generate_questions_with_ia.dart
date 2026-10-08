import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/ia_generation_result.dart';
import '../entities/ia_model_option.dart';
import '../entities/study_material.dart';
import '../material_rules.dart';
import '../repositories/ia_quiz_repository.dart';

/// Use case que valida os inputs e dispara a geração de questões via IA.
///
/// Validações:
/// - tema obrigatório na geração por tema; com materiais não há tema (o foco
///   vai na descrição) e é preciso ao menos um material com texto, dentro do
///   limite de texto da IA.
/// - quantidade entre 1 e 20 (espelha o limite do backend em
///   `openrouter.js`).
/// - descrição com até 500 caracteres (defesa contra prompt injection
///   excessivo e contra estourar tokens).
class GenerateQuestionsWithIa {
  final IaQuizRepository _repository;
  const GenerateQuestionsWithIa(this._repository);

  static const int _minQuantity = 1;
  static const int _maxQuantity = 20;
  static const int _minAlternatives = 2;
  static const int _maxAlternatives = 5;
  static const int _maxDescriptionLength = 500;

  Future<Either<Failure, IaGenerationResult>> call({
    required String topic,
    required String difficulty,
    required int quantity,
    required int alternatives,
    required String description,
    required IaModelOption model,
    String? subject,
    List<MaterialForAi>? materials,
  }) {
    final trimmedTopic = topic.trim();
    final fromMaterials = materials != null;
    if (fromMaterials) {
      final usable = materials.where((m) => m.text.trim().isNotEmpty);
      if (usable.isEmpty) {
        return Future.value(
          const Left(
            ValidationFailure('Adicione ao menos um material com texto.'),
          ),
        );
      }
      final chars = usable.fold<int>(0, (sum, m) => sum + m.text.length);
      if (chars > MaterialRules.maxCharsForAi * 1.2) {
        return Future.value(
          const Left(
            ValidationFailure('O texto dos materiais passou do limite.'),
          ),
        );
      }
    } else if (trimmedTopic.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Informe um tema para as questões.')),
      );
    }

    if (quantity < _minQuantity || quantity > _maxQuantity) {
      return Future.value(
        const Left(
          ValidationFailure('A quantidade deve estar entre 1 e 20.'),
        ),
      );
    }

    if (alternatives < _minAlternatives || alternatives > _maxAlternatives) {
      return Future.value(
        const Left(
          ValidationFailure(
            'O número de alternativas deve estar entre 2 e 5.',
          ),
        ),
      );
    }

    final trimmedDescription = description.trim();
    if (trimmedDescription.length > _maxDescriptionLength) {
      return Future.value(
        const Left(
          ValidationFailure(
            'A descrição não pode ter mais de $_maxDescriptionLength caracteres.',
          ),
        ),
      );
    }

    return _repository.generateQuestions(
      topic: trimmedTopic,
      difficulty: difficulty,
      quantity: quantity,
      alternatives: alternatives,
      description: trimmedDescription,
      model: model,
      subject: subject,
      materials: materials ?? const [],
    );
  }
}
