import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom_result.dart';
import '../repositories/classroom_repository.dart';

/// Salva o resultado do aluno ao completar o quiz de uma sala.
class SubmitClassroomResult {
  final ClassroomRepository _repository;
  const SubmitClassroomResult(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required ClassroomResult result,
  }) {
    return _repository.submitResult(
      classroomId: classroomId,
      result: result,
    );
  }
}
