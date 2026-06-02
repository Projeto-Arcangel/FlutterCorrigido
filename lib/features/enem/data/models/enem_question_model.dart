import '../../domain/entities/enem_question.dart';

/// Converte uma linha de `enem_questions` em [EnemQuestion].
class EnemQuestionModel extends EnemQuestion {
  const EnemQuestionModel({
    required super.id,
    required super.year,
    required super.index,
    required super.discipline,
    required super.language,
    required super.context,
    required super.contextImages,
    required super.alternativesIntroduction,
    required super.correctAlternative,
    required super.alternatives,
    required super.hasImage,
  });

  factory EnemQuestionModel.fromMap(Map<String, dynamic> map) {
    final altsRaw = (map['alternatives'] as List?) ?? const [];
    final alternatives = altsRaw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return EnemAlternative(
        letter: (m['letter'] as String?) ?? '',
        text: (m['text'] as String?) ?? '',
        isCorrect: (m['isCorrect'] as bool?) ?? false,
        file: (m['file'] as String?)?.isNotEmpty ?? false
            ? m['file'] as String?
            : null,
      );
    }).toList();

    return EnemQuestionModel(
      id: map['id'].toString(),
      year: (map['year'] as num?)?.toInt() ?? 0,
      index: (map['index'] as num?)?.toInt() ?? 0,
      discipline: (map['discipline'] as String?) ?? '',
      language: (map['language'] as String?) ?? '',
      context: (map['context'] as String?) ?? '',
      contextImages: ((map['context_images'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      alternativesIntroduction:
          (map['alternatives_introduction'] as String?) ?? '',
      correctAlternative: (map['correct_alternative'] as String?) ?? '',
      alternatives: alternatives,
      hasImage: (map['has_image'] as bool?) ?? false,
    );
  }
}
