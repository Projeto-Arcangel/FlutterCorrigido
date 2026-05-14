import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/classroom_repository.dart';

/// Atualiza o nome e/ou descrição de uma sala.
///
/// Somente o professor dono da sala deve chamar este use case.
/// A validação de ownership é feita na camada de segurança do Firestore.
class UpdateClassroom {
  final ClassroomRepository _repository;
  const UpdateClassroom(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String name,
    String description = '',
  }) {
    if (name.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Nome da sala não pode ser vazio')),
      );
    }
    return _repository.updateClassroom(
      classroomId: classroomId,
      name: name.trim(),
      description: description.trim(),
    );
  }
}
