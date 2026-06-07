import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/ia_generation_result.dart';
import '../../domain/entities/ia_model_option.dart';
import '../../domain/repositories/ia_quiz_repository.dart';
import '../datasources/supabase_ia_datasource.dart';
import '../models/ia_question_response_model.dart';

class IaQuizRepositoryImpl implements IaQuizRepository {
  IaQuizRepositoryImpl(this._datasource, this._logger);

  final SupabaseIaDatasource _datasource;
  final Logger _logger;

  @override
  Future<Either<Failure, IaGenerationResult>> generateQuestions({
    required String topic,
    required String difficulty,
    required int quantity,
    required int alternatives,
    required String description,
    required IaModelOption model,
  }) async {
    try {
      final response = await _datasource.generateQuestions(
        topic: topic,
        difficulty: difficulty,
        quantity: quantity,
        alternatives: alternatives,
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
    } on FunctionException catch (e, st) {
      _logger.e(
        'generateQuestions edge function error: ${e.status} - ${e.details}',
        error: e,
        stackTrace: st,
      );
      return Left(_mapFunctionException(e));
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

  /// A Edge Function devolve `{ error, attempts }` no corpo dos erros — daí
  /// extraímos a mensagem real (ex.: o erro de cada modelo no fallback da IA).
  Failure _mapFunctionException(FunctionException e) {
    final detail =
        e.details is Map ? (e.details as Map)['error']?.toString() : null;
    switch (e.status) {
      case 401:
        return const NetworkFailure(
          'Você precisa estar logado para gerar questões.',
        );
      case 403:
        return const ValidationFailure(
          'Apenas professores podem usar este recurso.',
        );
      case 400:
        return ValidationFailure(detail ?? 'Dados inválidos.');
      case 429:
        return ValidationFailure(
          detail ??
              'Limite diário de geração por IA atingido. Tente novamente amanhã.',
        );
      case 504:
        return const NetworkFailure(
          'A IA demorou demais para responder. Tente novamente.',
        );
      case 503:
        return const NetworkFailure(
          'Serviço de IA indisponível no momento.',
        );
      default:
        return NetworkFailure(
          detail ??
              'A IA não conseguiu gerar as questões. Tente outro modelo.',
        );
    }
  }
}
