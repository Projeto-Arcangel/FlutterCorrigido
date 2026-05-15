import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Rascunho de uma questão gerada pela IA, antes do professor decidir
/// se mantém ou descarta.
///
/// Não é persistido no Firestore — vive apenas no estado da tela de
/// revisão. Quando o professor confirma, as questões com [isAccepted]
/// `true` são convertidas de volta para [Question] e passadas ao
/// `SaveClassroomQuiz`.
class IaQuestionDraft extends Equatable {
  final Question question;
  final bool isAccepted;
  final bool isEdited;

  const IaQuestionDraft({
    required this.question,
    this.isAccepted = true,
    this.isEdited = false,
  });

  IaQuestionDraft copyWith({
    Question? question,
    bool? isAccepted,
    bool? isEdited,
  }) {
    return IaQuestionDraft(
      question: question ?? this.question,
      isAccepted: isAccepted ?? this.isAccepted,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  @override
  List<Object?> get props => [question, isAccepted, isEdited];
}
