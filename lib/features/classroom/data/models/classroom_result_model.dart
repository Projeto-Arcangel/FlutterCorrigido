import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/classroom_result.dart';

/// Model que converte dados do Firestore para [ClassroomResult].
///
/// Armazenado em `Classrooms/{classroomId}/results/{studentId}`.
class ClassroomResultModel extends ClassroomResult {
  const ClassroomResultModel({
    required super.studentId,
    required super.studentName,
    required super.totalQuestions,
    required super.correctAnswers,
    required super.completedAt,
  });

  factory ClassroomResultModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data()! as Map<String, dynamic>;
    return ClassroomResultModel(
      studentId: snap.id,
      studentName: (data['studentName'] as String?) ?? '',
      totalQuestions: (data['totalQuestions'] as num?)?.toInt() ?? 0,
      correctAnswers: (data['correctAnswers'] as num?)?.toInt() ?? 0,
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentName': studentName,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'completedAt': Timestamp.fromDate(completedAt),
    };
  }
}
