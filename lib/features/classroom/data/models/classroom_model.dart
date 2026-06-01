import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/classroom.dart';

/// Model que converte uma sala do Supabase para a entidade [Classroom].
///
/// O JSON vem das RPCs `classroom_to_json` / `get_*_classrooms`
/// (com `teacher_name` e `student_ids` já resolvidos). As questões soltas
/// de sala não existem no schema Supabase — o conteúdo vive em fases — então
/// `questions` é sempre vazio aqui.
class ClassroomModel extends Classroom {
  const ClassroomModel({
    required super.id,
    required super.code,
    required super.name,
    required super.description,
    required super.teacherId,
    required super.teacherName,
    required super.studentIds,
    required super.createdAt,
    required super.isActive,
    required super.questions,
  });

  factory ClassroomModel.empty() => ClassroomModel(
        id: '',
        code: '',
        name: '',
        description: '',
        teacherId: '',
        teacherName: '',
        studentIds: const [],
        createdAt: DateTime(2024),
        isActive: false,
        questions: const [],
      );

  factory ClassroomModel.fromMap(
    Map<String, dynamic> map, {
    List<QuestionModel> questions = const [],
  }) {
    return ClassroomModel(
      id: map['id'].toString(),
      code: (map['code'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      teacherId: (map['teacher_id'] as String?) ?? '',
      teacherName: (map['teacher_name'] as String?) ?? '',
      studentIds: (map['student_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isActive: (map['is_active'] as bool?) ?? true,
      questions: questions,
    );
  }
}
