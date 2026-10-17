import 'package:equatable/equatable.dart';

enum QuestionType {
  multipleChoice, // type == 0
  fillBlanks,     // type == 1
  trueFalse,      // type == 2
  /// Ligar colunas (estilo fios): pares esquerda ↔ direita.
  matchColumns,
  /// Ordenar itens.
  ordering,
  /// Cruzadinha (grade com dicas).
  crossword,
  /// Caça-palavras.
  wordSearch,
  unknown;

  /// Usa [Question.content]/[Question.answer] em vez de alternativas.
  bool get usesContent =>
      this == matchColumns ||
      this == ordering ||
      this == fillBlanks ||
      this == crossword ||
      this == wordSearch;

  String get label => switch (this) {
        QuestionType.matchColumns => 'Ligar colunas',
        QuestionType.ordering => 'Ordenar',
        QuestionType.crossword => 'Cruzadinha',
        QuestionType.wordSearch => 'Caça-palavras',
        QuestionType.trueFalse => 'Verdadeiro ou falso',
        QuestionType.fillBlanks => 'Completar lacunas',
        _ => 'Múltipla escolha',
      };

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

  /// Segundos para responder com o relógio da fase ligado, escolhidos pelo
  /// professor (`null` = automático, pelo tamanho do texto).
  final int? timeLimitS;

  /// Tipos novos (ligar colunas, ordenar): o que o aluno vê. `null` na
  /// múltipla escolha. Ver `question_kinds.dart`.
  final Map<String, dynamic>? content;

  /// Tipos novos: o gabarito. Só o professor recebe; o aluno nunca.
  final Map<String, dynamic>? answer;

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
    this.timeLimitS,
    this.content,
    this.answer,
  });

  /// A mesma questão com outro tempo (`null` = automático).
  Question withTimeLimit(int? seconds) => Question(
        id: id,
        text: text,
        options: options,
        correctAnswer: correctAnswer,
        explanation: explanation,
        type: type,
        imageUrl: imageUrl,
        imageAuthor: imageAuthor,
        imageSource: imageSource,
        timeLimitS: seconds,
        content: content,
        answer: answer,
      );

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool isCorrect(int selectedIndex) => selectedIndex == correctAnswer;

  @override
  List<Object?> get props => [
        id, text, options, correctAnswer, explanation, type,
        imageUrl, imageAuthor, imageSource, timeLimitS, content, answer,
      ];
}