import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/classroom_phase.dart';

/// Model que converte uma fase (tabela `classroom_phases`) para [ClassroomPhase].
class ClassroomPhaseModel extends ClassroomPhase {
  const ClassroomPhaseModel({
    required super.id,
    required super.classroomId,
    required super.title,
    required super.description,
    required super.order,
    super.weight,
    required super.createdAt,
    required super.questions,
  });

  factory ClassroomPhaseModel.fromMap(
    Map<String, dynamic> map,
    List<QuestionModel> questions,
  ) {
    final rawWeight = map['weight'];
    return ClassroomPhaseModel(
      id: map['id'].toString(),
      classroomId: (map['classroom_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      order: (map['sort_order'] as num?)?.toInt() ?? 0,
      weight: rawWeight is num
          ? rawWeight.toDouble()
          : double.tryParse('${rawWeight ?? ''}') ?? 1.0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      questions: questions,
    );
  }
}
