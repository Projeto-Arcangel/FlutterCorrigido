import 'package:equatable/equatable.dart';

/// Resultado de um quiz **calculado pelo servidor** (RPC `submit_quiz`).
///
/// O cliente envia as respostas escolhidas; o servidor compara com o gabarito
/// (que nunca sai do banco), grava a nota e devolve este resumo. [firstAttempt]
/// indica se esta foi a 1ª conclusão da fase (quando os prêmios são concedidos).
class QuizSubmissionResult extends Equatable {
  final int total;
  final int correct;
  final bool firstAttempt;

  const QuizSubmissionResult({
    required this.total,
    required this.correct,
    required this.firstAttempt,
  });

  double get percentage => total > 0 ? correct / total : 0.0;

  @override
  List<Object?> get props => [total, correct, firstAttempt];
}
