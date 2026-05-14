import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/classroom.dart';

/// Model que converte dados do Firestore para a entidade [Classroom].
///
/// Segue o mesmo padrão de `LessonModel` (extends da entity).
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

  /// Constrói a partir de um `DocumentSnapshot` do Firestore.
  ///
  /// As questões são passadas separadamente porque estão em subcoleção.
  factory ClassroomModel.fromSnapshot(
    DocumentSnapshot snap,
    List<QuestionModel> questions,
  ) {
    final data = snap.data()! as Map<String, dynamic>;
    return ClassroomModel(
      id: snap.id,
      code: (data['code'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      teacherId: (data['teacherId'] as String?) ?? '',
      teacherName: (data['teacherName'] as String?) ?? '',
      studentIds: List<String>.from(
        (data['studentIds'] as List<dynamic>?) ?? [],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? true,
      questions: questions,
    );
  }

  /// Converte para Map para gravar no Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'studentIds': studentIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
