import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/classroom_repository.dart';

/// Remove o aluno de uma sala de aula.
class LeaveClassroom {
  final ClassroomRepository _repository;
  const LeaveClassroom(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String studentId,
  }) {
    return _repository.leaveClassroom(
      classroomId: classroomId,
      studentId: studentId,
    );
  }
}
