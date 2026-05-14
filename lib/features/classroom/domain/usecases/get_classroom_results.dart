import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom_result.dart';
import '../repositories/classroom_repository.dart';

/// Retorna os resultados de todos os alunos de uma sala.
///
/// Usado pelo professor para ver a porcentagem final de acertos
/// de cada aluno.
class GetClassroomResults {
  final ClassroomRepository _repository;
  const GetClassroomResults(this._repository);

  Future<Either<Failure, List<ClassroomResult>>> call(String classroomId) {
    return _repository.getResults(classroomId);
  }
}
