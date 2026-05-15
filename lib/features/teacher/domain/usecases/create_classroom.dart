import '../entities/teacher_dashboard_data.dart';

Future<Either<Failure, Classroom>> call({
  required String name,
  required String teacherId,
  required String teacherName, // adicionar este campo
  String description = '',
}) {
  if (name.trim().isEmpty) {
    return Future.value(
      const Left(ValidationFailure('Nome da sala não pode ser vazio')),
    );
  }
  return _repository.createClassroom(
    name: name.trim(),
    description: description.trim(),
    teacherId: teacherId,
    teacherName: teacherName, // repassar
  );
}