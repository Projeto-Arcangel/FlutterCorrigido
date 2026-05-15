import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/classroom_repository.dart';

/// Professor exclui uma turma, levando junto todas as questões,
/// fases e resultados. Operação irreversível — a UI deve sempre
/// pedir confirmação explícita antes de invocar.
class DeleteClassroom {
  final ClassroomRepository _repository;
  const DeleteClassroom(this._repository);

  Future<Either<Failure, void>> call(String classroomId) {
    if (classroomId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('ID da turma inválido')),
      );
    }
    return _repository.deleteClassroom(classroomId);
  }
}