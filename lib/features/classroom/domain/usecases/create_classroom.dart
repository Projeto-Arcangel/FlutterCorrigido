import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Cria uma nova sala de aula.
///
/// O professor informa nome e descrição; o código de 6 caracteres
/// é gerado automaticamente pelo datasource.
class CreateClassroom {
  final ClassroomRepository _repository;
  const CreateClassroom(this._repository);

  Future<Either<Failure, Classroom>> call({
    required String name,
    required String teacherId,
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
    );
  }
}
