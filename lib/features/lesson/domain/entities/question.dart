import 'package:equatable/equatable.dart';

enum QuestionType {
  multipleChoice, // type == 0
  fillBlanks,     // type == 1
  trueFalse,      // type == 2
  unknown;

  static QuestionType fromInt(int? value) {
    switch (value) {
      case 0:
        return QuestionType.multipleChoice;
      case 1:
        return QuestionType.fillBlanks;
      case 2:
        return QuestionType.trueFalse;
      default:
        return QuestionType.unknown;
    }
  }
}

class Question extends Equatable {
  final String id;
  final String text;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final QuestionType type;
  final String? imageUrl;
  final String? imageAuthor;
  final String? imageSource;

  const Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.type,
    this.imageUrl,
    this.imageAuthor,
    this.imageSource,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool isCorrect(int selectedIndex) => selectedIndex == correctAnswer;

  @override
  List<Object?> get props => [
        id, text, options, correctAnswer, explanation, type,
        imageUrl, imageAuthor, imageSource,
      ];
}