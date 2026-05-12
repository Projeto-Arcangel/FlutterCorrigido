import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/question.dart';

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.text,
    required super.options,
    required super.correctAnswer,
    required super.explanation,
    required super.type,
  });

  factory QuestionModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data()! as Map<String, dynamic>;
    return QuestionModel(
      id: snap.id,
      text: (data['text'] as String?) ?? '',
      options: List<String>.from((data['options'] as List<dynamic>?) ?? []),
      correctAnswer: (data['correct_answer'] as num?)?.toInt() ?? 0,
      explanation: (data['explanation'] as String?) ?? '',
      type: QuestionType.fromInt((data['type'] as num?)?.toInt()),
    );
  }
}