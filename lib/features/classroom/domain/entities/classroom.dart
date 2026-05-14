import 'package:equatable/equatable.dart';

class Classroom extends Equatable {
  const Classroom({
    required this.id,
    required this.name,
    required this.code,
    required this.teacherName,
    required this.subject,
  });

  final String id;
  final String name;
  final String code;
  final String teacherName;
  final String subject;

  @override
  List<Object?> get props => [id, name, code, teacherName, subject];
}