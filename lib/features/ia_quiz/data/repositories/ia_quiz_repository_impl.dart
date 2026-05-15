import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/ia_generation_result.dart';
import '../../domain/entities/ia_model_option.dart';
import '../../domain/repositories/ia_quiz_repository.dart';
import '../datasources/firebase_functions_ia_datasource.dart';
import '../models/ia_question_response_model.dart';

class IaQuizRepositoryImpl implements IaQuizRepository {
  IaQuizRepositoryImpl(this._datasource, this._logger);

  final FirebaseFunctionsIaDatasource _datasource;
  final Logger _logger;

  @override
  Future<Either<Failure, IaGenerationResult>> generateQuestions({
    required String topic,
    required String difficulty,
    required int quantity,
    required String description,
    required IaModelOption model,
  }) async {
    try {
      final response = await _datasource.generateQuestions(
        topic: topic,
        difficulty: difficulty,
        quantity: quantity,
        description: description,
        modelKey: model.key,
      );

      final questions = IaQuestionResponseModel.questionsFromResponse(response);
      final modelUsedKey = response['modelUsed'] as String?;
      final modelUsed = IaModelOption.fromKey(modelUsedKey) ?? model;

      return Right(
        IaGenerationResult(
          questions: questions,
          modelUsed: modelUsed,
          usedFallback: modelUsed != model,
        ),
      );
    } on FirebaseFunctionsException catch (e, st) {
      _logger.e(
        'generateQuestions firebase error: ${e.code} - ${e.message}',
        error: e,
        stackTrace: st,
      );
      return Left(_mapFunctionsException(e));
    } catch (e, st) {
      _logger.e(
        'generateQuestions unknown error',
        error: e,
        stackTrace: st,
      );
      return const Left(
        UnknownFailure('Falha inesperada ao gerar questões.'),
      );
    }
  }

  Failure _mapFunctionsException(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return const NetworkFailure(
          'Você precisa estar logado para gerar questões.',
        );
      case 'permission-denied':
        return const ValidationFailure(
          'Apenas professores podem usar este recurso.',
        );
      case 'invalid-argument':
        return ValidationFailure(e.message ?? 'Dados inválidos.');
      case 'deadline-exceeded':
        return const NetworkFailure(
          'A IA demorou demais para responder. Tente novamente.',
        );
      case 'unavailable':
        return const NetworkFailure(
          'Serviço de IA indisponível no momento.',
        );
      default:
        return NetworkFailure(
          e.message ??
              'A IA não conseguiu gerar as questões. Tente outro modelo.',
        );
    }
  }
}
