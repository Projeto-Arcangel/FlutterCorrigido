import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Retorna a sala em que o aluno está atualmente (pode ser null).
///
/// O aluno só pode estar em **uma sala** por vez. Se não está em
/// nenhuma, retorna `Right(null)`.
class GetStudentClassroom {
  final ClassroomRepository _repository;
  const GetStudentClassroom(this._repository);

  Future<Either<Failure, Classroom?>> call(String studentId) {
    return _repository.getStudentClassroom(studentId);
  }
}
