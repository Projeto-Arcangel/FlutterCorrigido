import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Lista todas as salas criadas por um professor.
class GetTeacherClassrooms {
  final ClassroomRepository _repository;
  const GetTeacherClassrooms(this._repository);

  Future<Either<Failure, List<Classroom>>> call(String teacherId) {
    return _repository.getTeacherClassrooms(teacherId);
  }
}
