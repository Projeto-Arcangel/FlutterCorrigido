import '../../../lesson/domain/entities/question.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

/// Converte o payload JSON retornado pela Edge Function `generate-questions`
/// em entidades [Question] usáveis pela tela de revisão.
///
/// O backend já valida a estrutura de cada tipo (alternativas, pares, itens,
/// lacunas, palavras da grade),
/// então aqui assumimos que os campos estão presentes — se algo vier
/// fora do esperado, a exceção sobe naturalmente para o repository.
class IaQuestionResponseModel {
  /// Mapeia uma única questão crua para [Question].
  /// O `id` fica vazio: será atribuído pelo banco quando o professor
  /// confirmar e salvar a fase via `SaveClassroomQuiz`.
  /// `null` quando a cruzadinha/caça-palavras não coube numa grade de
  /// até 15×15 (a revisão avisa quantas ficaram de fora).
  static Question? questionFromJson(Map<String, dynamic> json) {
    final text = json['text'] as String;
    final explanation = (json['explanation'] as String?) ?? '';
    // Ligar/ordenar/lacunas vêm na forma natural (pares; itens na ordem
    // certa; texto com [respostas]) e são embaralhados aqui, ao montar.
    switch (json['type']) {
      case 'match_columns':
        return buildMatchQuestion(
          text: text,
          explanation: explanation,
          pairs: [
            for (final p in json['pairs'] as List)
              MatchPair('${(p as List)[0]}', '${p[1]}'),
          ],
        );
      case 'ordering':
        return buildOrderingQuestion(
          text: text,
          explanation: explanation,
          orderedItems: [for (final i in json['items'] as List) '$i'],
        );
      case 'crossword':
        return buildCrosswordQuestion(
          text: text,
          explanation: explanation,
          entries: [
            for (final e in json['entries'] as List)
              CrosswordEntry('${(e as Map)['word']}', '${e['clue']}'),
          ],
        );
      case 'word_search':
        return buildWordSearchQuestion(
          text: text,
          explanation: explanation,
          words: [for (final w in json['words'] as List) '$w'],
        );
      case 'fill_blanks':
        return buildFillBlanksQuestion(
          text: text,
          explanation: explanation,
          template: json['sentence'] as String,
          distractors: [
            for (final d in (json['distractors'] as List?) ?? const []) '$d',
          ],
        );
    }
    final rawOptions = json['options'] as List;
    return Question(
      id: '',
      text: json['text'] as String,
      options: rawOptions.map((o) => o as String).toList(),
      correctAnswer: json['correctAnswer'] as int,
      explanation: (json['explanation'] as String?) ?? '',
      type: QuestionType.multipleChoice,
    );
  }

  /// Mapeia a lista de questões dentro do payload completo. [skipped]:
  /// quantas não couberam na grade (cruzadinha/caça-palavras).
  static ({List<Question> questions, int skipped}) questionsFromResponse(
    Map<String, dynamic> response,
  ) {
    final rawList = response['questions'] as List;
    final parsed = [
      for (final q in rawList) questionFromJson(Map<String, dynamic>.from(q as Map)),
    ];
    return (
      questions: parsed.whereType<Question>().toList(),
      skipped: parsed.where((q) => q == null).length,
    );
  }
}