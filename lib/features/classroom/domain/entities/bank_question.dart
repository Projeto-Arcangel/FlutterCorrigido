import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Uma questão do banco do professor ("Reutilizar minhas questões"): a
/// questão e onde ela está hoje (turma e fase).
class BankQuestion extends Equatable {
  const BankQuestion({
    required this.question,
    required this.classroomId,
    required this.classroomName,
    required this.phaseId,
    required this.phaseTitle,
    required this.aiGenerated,
    required this.createdAt,
  });

  final Question question;
  final String classroomId;
  final String classroomName;
  final String phaseId;
  final String phaseTitle;
  final bool aiGenerated;
  final DateTime? createdAt;

  String get id => question.id;

  /// Texto normalizado para busca e para reconhecer repetidas (mesmo
  /// enunciado e alternativas, sem diferença de maiúsculas e espaços).
  String get signature => [
        question.text,
        ...question.options,
      ].map(normalize).join('\u0001');

  static String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  List<Object?> get props => [question, classroomId, phaseId];
}
