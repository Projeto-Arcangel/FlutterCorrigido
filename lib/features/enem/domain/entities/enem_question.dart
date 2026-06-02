import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Uma alternativa de uma questão do ENEM (A–E).
class EnemAlternative extends Equatable {
  const EnemAlternative({
    required this.letter,
    required this.text,
    required this.isCorrect,
    this.file,
  });

  final String letter;
  final String text;
  final bool isCorrect;

  /// URL da imagem da alternativa (raro). O modelo de questão do app não
  /// suporta imagem por alternativa, então é ignorada na conversão.
  final String? file;

  bool get hasImage => file != null && file!.isNotEmpty;

  @override
  List<Object?> get props => [letter, text, isCorrect, file];
}

/// Questão do banco do ENEM (tabela `enem_questions`).
class EnemQuestion extends Equatable {
  const EnemQuestion({
    required this.id,
    required this.year,
    required this.index,
    required this.discipline,
    required this.language,
    required this.context,
    required this.contextImages,
    required this.alternativesIntroduction,
    required this.correctAlternative,
    required this.alternatives,
    required this.hasImage,
  });

  final String id;
  final int year;
  final int index;
  final String discipline;
  final String language; // '' | ingles | espanhol
  final String context;
  final List<String> contextImages;
  final String alternativesIntroduction;
  final String correctAlternative; // 'A'..'E'
  final List<EnemAlternative> alternatives;
  final bool hasImage;

  String get disciplineLabel => switch (discipline) {
        'ciencias-humanas' => 'Ciências Humanas',
        'ciencias-natureza' => 'Ciências da Natureza',
        'linguagens' => 'Linguagens',
        'matematica' => 'Matemática',
        _ => discipline,
      };

  String get languageLabel => switch (language) {
        'ingles' => 'Inglês',
        'espanhol' => 'Espanhol',
        _ => '',
      };

  /// Enunciado sem a sintaxe de imagem/links do Markdown — as imagens vêm
  /// separadas em [contextImages].
  String get cleanContext => stripEnemMarkdown(context);

  /// Converte para a entidade [Question] do app.
  ///
  /// As alternativas viram `options` (texto); a correta é o índice da
  /// alternativa marcada. A 1ª imagem do enunciado (se houver) vira a imagem
  /// da questão — imagens por alternativa não são suportadas pelo modelo e
  /// são descartadas (a UI avisa quando a questão tem imagem).
  Question toQuestion() {
    final parts = [cleanContext, alternativesIntroduction.trim()]
        .where((s) => s.isNotEmpty)
        .toList();
    final idx = alternatives.indexWhere((a) => a.isCorrect);
    return Question(
      id: '',
      text: parts.join('\n\n'),
      options: alternatives.map((a) => a.text).toList(),
      correctAnswer: idx < 0 ? 0 : idx,
      explanation: '',
      type: QuestionType.multipleChoice,
      imageUrl: contextImages.isNotEmpty ? contextImages.first : null,
      imageSource: 'ENEM $year',
    );
  }

  @override
  List<Object?> get props => [
        id,
        year,
        index,
        discipline,
        language,
        context,
        contextImages,
        alternativesIntroduction,
        correctAlternative,
        alternatives,
        hasImage,
      ];
}

/// Remove imagens `![](...)` e troca links `[txt](url)` pelo texto, deixando
/// apenas o conteúdo legível do enunciado do ENEM (markdown).
String stripEnemMarkdown(String input) {
  var out = input.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  return out.trim();
}
