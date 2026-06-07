import 'package:equatable/equatable.dart';

/// Correção de UMA questão, calculada pelo servidor e revelada **só depois**
/// do envio (RPC `submit_quiz`). O gabarito (`correctAnswer`) e a explicação
/// nunca chegam ao app do aluno antes da submissão.
class QuizAnswerReview extends Equatable {
  /// Id da questão (casa com a questão local, sem gabarito, para montar a
  /// tela de revisão).
  final String questionId;

  /// Índice da alternativa correta (verdade do servidor).
  final int correctAnswer;

  /// Índice escolhido pelo aluno; `null` se ele deixou em branco.
  final int? chosen;

  /// Se o aluno acertou esta questão.
  final bool isCorrect;

  /// Justificativa pedagógica (pode vir vazia).
  final String explanation;

  const QuizAnswerReview({
    required this.questionId,
    required this.correctAnswer,
    required this.chosen,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuizAnswerReview.fromMap(Map<String, dynamic> map) {
    final chosenRaw = map['chosen'];
    return QuizAnswerReview(
      questionId: map['id'].toString(),
      correctAnswer: (map['correct_answer'] as num?)?.toInt() ?? -1,
      chosen: chosenRaw is num ? chosenRaw.toInt() : null,
      isCorrect: (map['is_correct'] as bool?) ?? false,
      explanation: (map['explanation'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props =>
      [questionId, correctAnswer, chosen, isCorrect, explanation];
}

/// Resultado de um quiz **calculado pelo servidor** (RPC `submit_quiz`).
///
/// O cliente envia as respostas escolhidas; o servidor compara com o gabarito
/// (que nunca sai do banco), grava a nota e devolve este resumo. [firstAttempt]
/// indica se esta foi a 1ª conclusão da fase (quando os prêmios são concedidos).
/// [review] traz a correção por questão (gabarito + acertou/errou + explicação),
/// usada na tela de revisão pós-envio.
class QuizSubmissionResult extends Equatable {
  final int total;
  final int correct;
  final bool firstAttempt;
  final List<QuizAnswerReview> review;

  const QuizSubmissionResult({
    required this.total,
    required this.correct,
    required this.firstAttempt,
    this.review = const [],
  });

  double get percentage => total > 0 ? correct / total : 0.0;

  @override
  List<Object?> get props => [total, correct, firstAttempt, review];
}