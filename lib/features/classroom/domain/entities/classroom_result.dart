import 'package:equatable/equatable.dart';

/// Resultado de um aluno ao completar o quiz de uma sala.
///
/// Armazenado em `Classrooms/{classroomId}/results/{studentUid}`.
/// O professor usa isso para ver a porcentagem final de acertos.
class ClassroomResult extends Equatable {
  final String studentId;
  final String studentName;
  final int totalQuestions;
  final int correctAnswers;
  final DateTime completedAt;

  const ClassroomResult({
    required this.studentId,
    required this.studentName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.completedAt,
  });

  /// Porcentagem de acertos (0.0 a 1.0).
  double get percentage =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  /// Porcentagem formatada para exibição (ex: "78%").
  String get percentageFormatted =>
      '${(percentage * 100).round()}%';

  @override
  List<Object?> get props => [
        studentId,
        studentName,
        totalQuestions,
        correctAnswers,
        completedAt,
      ];
}
