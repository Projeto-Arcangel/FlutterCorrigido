import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Retorna todas as salas em que o aluno está matriculado.
class GetStudentClassroom {
  final ClassroomRepository _repository;
  const GetStudentClassroom(this._repository);

  Future<Either<Failure, List<Classroom>>> call(String studentId) {
    return _repository.getStudentClassrooms(studentId);
  }
}
