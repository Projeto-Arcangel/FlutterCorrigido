import 'package:equatable/equatable.dart';

/// Resultado de um aluno numa sala (nota oficial = 1ª tentativa de cada fase).
///
/// Armazenado na tabela `classroom_results` e lido pela RPC
/// `get_classroom_results`. O professor usa isso no Dashboard de Alunos.
class ClassroomResult extends Equatable {
  final String studentId;
  final String studentName;

  /// Prontuário institucional do aluno (ex.: PT3000000), vindo de
  /// `profiles.student_id` via RPC `get_classroom_results`. Pode ser vazio
  /// (aluno via Google que não preencheu, ou perfil incompleto).
  final String studentRegistration;

  /// Fase a que este resultado se refere. `null` quando o resultado é um
  /// agregado da trilha inteira (ex.: média ponderada calculada no dashboard).
  final String? phaseId;
  final int totalQuestions;

  /// Acertos: cada questão vale de 0 a 1, então pode ser fracionário.
  final double correctAnswers;
  final DateTime completedAt;

  /// Melhor nota (%) do aluno na fase — dá as estrelas.
  final double? bestPct;

  /// Estrelas da melhor nota (0 a 3).
  final int stars;

  /// Linha de "não entregou": a fase fechou e o aluno não respondeu (vale 0).
  final bool missing;

  /// Nota já calculada (0.0 a 1.0), quando ela NÃO deriva de `correct/total` —
  /// usada para a média ponderada da trilha. Quando `null`, `percentage` usa
  /// `correctAnswers / totalQuestions`.
  final double? finalScore;

  const ClassroomResult({
    required this.studentId,
    required this.studentName,
    this.studentRegistration = '',
    this.phaseId,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.completedAt,
    this.finalScore,
    this.bestPct,
    this.stars = 0,
    this.missing = false,
  });

  /// Porcentagem de acertos (0.0 a 1.0). Prioriza [finalScore] quando definido.
  double get percentage =>
      finalScore ?? (totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0);

  /// Porcentagem formatada para exibição (ex: "78%").
  String get percentageFormatted =>
      '${(percentage * 100).round()}%';

  @override
  List<Object?> get props => [
        studentId,
        studentName,
        studentRegistration,
        phaseId,
        totalQuestions,
        correctAnswers,
        completedAt,
        finalScore,
        bestPct,
        stars,
        missing,
      ];
}
