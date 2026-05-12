import 'package:equatable/equatable.dart';

import 'question.dart';

class Lesson extends Equatable {
  final String id;
  final String name;
  final String description;
  final int order;
  final List<Question> questions;

  const Lesson({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    required this.questions,
  });

  int get totalQuestions => questions.length;

  @override
  List<Object?> get props => [id, name, description, order, questions];
}