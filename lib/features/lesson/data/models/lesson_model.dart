import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/lesson.dart';
import 'question_model.dart';

class LessonModel extends Lesson {
  const LessonModel({
    required super.id,
    required super.name,
    required super.description,
    required super.order,
    required super.questions,
  });

  factory LessonModel.fromSnapshot(
    DocumentSnapshot snap,
    List<QuestionModel> questions,
  ) {
    final data = snap.data()! as Map<String, dynamic>;
    return LessonModel(
      id: snap.id,
      name: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      questions: questions,
    );
  }
}