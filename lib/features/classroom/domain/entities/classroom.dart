import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Representa uma sala de aula criada por um professor.
///
/// O [code] é um identificador curto de 6 caracteres (ex: `A3X9K2`) que
/// o professor compartilha verbalmente com os alunos para eles entrarem.
///
/// O aluno pode estar em **no máximo 1 sala** ao mesmo tempo.
/// O limite de alunos por sala é 50 (`maxStudents`).
class Classroom extends Equatable {
  final String id;
  final String code;
  final String name;
  final String description;
  final String teacherId;
  final List<String> studentIds;
  final DateTime createdAt;
  final bool isActive;
  final List<Question> questions;

  static const int maxStudents = 50;

  const Classroom({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.teacherId,
    required this.studentIds,
    required this.createdAt,
    required this.isActive,
    required this.questions,
  });

  int get studentCount => studentIds.length;
  int get questionCount => questions.length;
  bool get isFull => studentCount >= maxStudents;

  bool hasStudent(String uid) => studentIds.contains(uid);

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        description,
        teacherId,
        studentIds,
        createdAt,
        isActive,
        questions,
      ];
}
