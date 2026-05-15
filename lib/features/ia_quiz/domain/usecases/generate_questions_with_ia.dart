import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/ia_generation_result.dart';
import '../entities/ia_model_option.dart';
import '../repositories/ia_quiz_repository.dart';

/// Use case que valida os inputs e dispara a geração de questões via IA.
///
/// Validações:
/// - tema obrigatório.
/// - quantidade entre 1 e 20 (espelha o limite do backend em
///   `openrouter.js`).
/// - descrição com até 500 caracteres (defesa contra prompt injection
///   excessivo e contra estourar tokens).
class GenerateQuestionsWithIa {
  final IaQuizRepository _repository;
  const GenerateQuestionsWithIa(this._repository);

  static const int _minQuantity = 1;
  static const int _maxQuantity = 20;
  static const int _maxDescriptionLength = 500;

  Future<Either<Failure, IaGenerationResult>> call({
    required String topic,
    required String difficulty,
    required int quantity,
    required String description,
    required IaModelOption model,
  }) {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
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
      description: trimmedDescription,
      model: model,
    );
  }
}