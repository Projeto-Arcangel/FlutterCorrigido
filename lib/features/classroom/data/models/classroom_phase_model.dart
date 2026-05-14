import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/classroom_phase.dart';

/// Model que converte dados do Firestore para [ClassroomPhase].
///
/// Armazenado em `Classrooms/{classroomId}/phases/{phaseId}`.
/// As questões ficam em `Classrooms/{classroomId}/phases/{phaseId}/questions/{qId}`.
class ClassroomPhaseModel extends ClassroomPhase {
  const ClassroomPhaseModel({
    required super.id,
    required super.classroomId,
    required super.title,
    required super.description,
    required super.order,
    required super.createdAt,
    required super.questions,
  });

  /// Constrói a partir de um `DocumentSnapshot` do Firestore.
  ///
  /// As questões são passadas separadamente porque estão em subcoleção.
  /// O `classroomId` é extraído do path do documento:
  /// `Classrooms/{classroomId}/phases/{phaseId}`
  factory ClassroomPhaseModel.fromSnapshot(
    DocumentSnapshot snap,
    List<QuestionModel> questions,
  ) {
    final data = snap.data()! as Map<String, dynamic>;
    // Path: Classrooms/{classroomId}/phases/{phaseId}
    // snap.reference.parent = CollectionReference para 'phases'
    // snap.reference.parent.parent = DocumentReference para Classrooms/{classroomId}
    final classroomId = snap.reference.parent.parent?.id ?? '';
    return ClassroomPhaseModel(
      id: snap.id,
      classroomId: classroomId,
      title: (data['name'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      questions: questions,
    );
  }

  /// Converte para Map para gravar no Firestore.
  /// O `classroomId` NÃO é incluído no documento — é implícito
  /// pelo path: `Classrooms/{classroomId}/phases/{phaseId}`.
  Map<String, dynamic> toFirestore() {
    return {
      'name': title,
      'description': description,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
