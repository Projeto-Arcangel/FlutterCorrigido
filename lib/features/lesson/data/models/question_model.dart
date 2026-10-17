import '../../domain/entities/question.dart';

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.text,
    required super.options,
    required super.correctAnswer,
    required super.explanation,
    required super.type,
    super.imageUrl,
    super.imageAuthor,
    super.imageSource,
    super.timeLimitS,
    super.content,
    super.answer,
  });

  /// Constrói a partir de uma linha da tabela `questions` do Supabase.
  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'].toString(),
      text: (map['text'] as String?) ?? '',
      options: (map['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      correctAnswer: (map['correct_answer'] as num?)?.toInt() ?? 0,
      explanation: (map['explanation'] as String?) ?? '',
      type: questionTypeFromDb(map['type'] as String?),
      imageUrl: map['image_url'] as String?,
      imageAuthor: map['image_author'] as String?,
      imageSource: map['image_source'] as String?,
      timeLimitS: (map['time_limit_s'] as num?)?.toInt(),
      content: _jsonMap(map['content']),
      answer: _jsonMap(map['answer']),
    );
  }

  /// Mapeia o enum `question_type` do Postgres para [QuestionType].
  static QuestionType questionTypeFromDb(String? value) {
    switch (value) {
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'fill_blanks':
        return QuestionType.fillBlanks;
      case 'true_false':
        return QuestionType.trueFalse;
      case 'match_columns':
        return QuestionType.matchColumns;
      case 'ordering':
        return QuestionType.ordering;
      case 'crossword':
        return QuestionType.crossword;
      case 'word_search':
        return QuestionType.wordSearch;
      default:
        return QuestionType.multipleChoice;
    }
  }

  static Map<String, dynamic>? _jsonMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  /// Mapeia [QuestionType] para o enum `question_type` do Postgres.
  /// `unknown` cai em `multiple_choice` (o enum do banco não tem 'unknown').
  static String questionTypeToDb(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
      case QuestionType.unknown:
        return 'multiple_choice';
      case QuestionType.fillBlanks:
        return 'fill_blanks';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.matchColumns:
        return 'match_columns';
      case QuestionType.ordering:
        return 'ordering';
      case QuestionType.crossword:
        return 'crossword';
      case QuestionType.wordSearch:
        return 'word_search';
    }
  }
}
