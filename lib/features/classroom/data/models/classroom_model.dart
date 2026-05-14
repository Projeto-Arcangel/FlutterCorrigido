import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/classroom.dart';

class ClassroomModel extends Classroom {
  const ClassroomModel({
    required super.id,
    required super.name,
    required super.code,
    required super.teacherName,
    required super.subject,
  });

  factory ClassroomModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data()! as Map<String, dynamic>;
    return ClassroomModel(
      id: snap.id,
      name: (data['name'] as String?) ?? '',
      code: (data['code'] as String?) ?? '',
      teacherName: (data['teacherName'] as String?) ?? '',
      subject: (data['subject'] as String?) ?? '',
    );
  }
}