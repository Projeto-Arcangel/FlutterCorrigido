import '../../domain/entities/classroom_result.dart';

/// Model que converte um resultado (tabela `classroom_results`) para
/// [ClassroomResult]. O `student_name` vem da RPC `get_classroom_results`.
class ClassroomResultModel extends ClassroomResult {
  const ClassroomResultModel({
    required super.studentId,
    required super.studentName,
    super.studentRegistration,
    super.phaseId,
    required super.totalQuestions,
    required super.correctAnswers,
    required super.completedAt,
    super.bestPct,
    super.stars,
  });

  factory ClassroomResultModel.fromMap(Map<String, dynamic> map) {
    return ClassroomResultModel(
      studentId: (map['student_id'] as String?) ?? '',
      studentName: (map['student_name'] as String?) ?? '',
      studentRegistration: (map['registration'] as String?) ?? '',
      phaseId: map['phase_id']?.toString(),
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctAnswers: _number(map['correct_answers']) ?? 0,
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? '') ??
          DateTime.now(),
      bestPct: _number(map['best_pct']),
      stars: _number(map['stars'])?.toInt() ?? 0,
    );
  }

  /// numeric do Postgres chega como número ou texto, conforme o caminho.
  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : (value == null ? null : double.tryParse(value.toString()));
}
