import '../../domain/entities/classroom_result.dart';

/// Model que converte um resultado (tabela `classroom_results`) para
/// [ClassroomResult]. O `student_name` vem da RPC `get_classroom_results`.
class ClassroomResultModel extends ClassroomResult {
  const ClassroomResultModel({
    required super.studentId,
    required super.studentName,
    required super.totalQuestions,
    required super.correctAnswers,
    required super.completedAt,
  });

  factory ClassroomResultModel.fromMap(Map<String, dynamic> map) {
    return ClassroomResultModel(
      studentId: (map['student_id'] as String?) ?? '',
      studentName: (map['student_name'] as String?) ?? '',
      totalQuestions: (map['total_questions'] as num?)?.toInt() ?? 0,
      correctAnswers: (map['correct_answers'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
