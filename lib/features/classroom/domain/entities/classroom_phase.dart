import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Representa uma fase (phase/lesson) criada pelo professor e vinculada
/// a uma sala de aula (classroom).
///
/// Diferente das fases globais (da trilha), esta fase aparece SOMENTE
/// para os alunos que estão na sala do professor que a criou.
///
/// Armazenada em `Classrooms/{classroomId}/phases/{phaseId}`.
/// As questões ficam em `Classrooms/{classroomId}/phases/{phaseId}/questions/{qId}`.
class ClassroomPhase extends Equatable {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final int order;

  /// Peso da fase na média ponderada da trilha (multiplicador; padrão 1.0 =
  /// todas as fases com o mesmo peso). O professor ajusta ao criar/editar.
  final double weight;
  final DateTime createdAt;
  final List<Question> questions;

  const ClassroomPhase({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.description,
    required this.order,
    this.weight = 1.0,
    required this.createdAt,
    required this.questions,
  });

  int get totalQuestions => questions.length;

  @override
  List<Object?> get props => [
        id,
        classroomId,
        title,
        description,
        order,
        weight,
        createdAt,
        questions,
      ];
}
