import '../../../lesson/domain/entities/question.dart';

/// Converte o payload JSON retornado pela Cloud Function em
/// entidades [Question] usáveis pela tela de revisão.
///
/// O backend já valida a estrutura (4 opções, correctAnswer 0-3, etc),
/// então aqui assumimos que os campos estão presentes — se algo vier
/// fora do esperado, a exceção sobe naturalmente para o repository.
class IaQuestionResponseModel {
  /// Mapeia uma única questão crua para [Question].
  /// O `id` fica vazio: será atribuído pelo Firestore quando o professor
  /// confirmar e salvar a fase via `SaveClassroomQuiz`.
  static Question questionFromJson(Map<String, dynamic> json) {
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

  /// Mapeia a lista de questões dentro do payload completo.
  static List<Question> questionsFromResponse(Map<String, dynamic> response) {
    final rawList = response['questions'] as List;
    return rawList
        .map((q) => questionFromJson(Map<String, dynamic>.from(q as Map)))
        .toList();
  }
}