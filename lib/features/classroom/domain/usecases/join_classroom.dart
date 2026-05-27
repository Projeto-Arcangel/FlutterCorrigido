import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Aluno entra numa sala usando o código de 6 caracteres.
///
/// Regras:
/// 1. A sala não pode estar cheia (max 50 alunos).
/// 2. O código deve existir e estar ativo.
/// 3. O aluno não pode entrar na mesma sala duas vezes.
class JoinClassroom {
  final ClassroomRepository _repository;
  const JoinClassroom(this._repository);

  Future<Either<Failure, Classroom>> call({
    required String code,
    required String studentId,
    String? studentName,
  }) async {
    final trimmed = code.trim().toUpperCase();

    if (trimmed.length != 6) {
      return const Left(
        ValidationFailure('O código deve ter 6 caracteres'),
      );
    }

    // 1. Busca a sala pelo código.
    final classroomResult = await _repository.getClassroomByCode(trimmed);
    return classroomResult.fold(
      (failure) => Left(failure),
      (classroom) async {
        if (!classroom.isActive) {
          return const Left(
            ValidationFailure('Esta sala não está mais ativa'),
          );
        }
        if (classroom.isFull) {
          return const Left(
            ValidationFailure('Esta sala já está lotada (máx. 50 alunos)'),
          );
        }
        if (classroom.hasStudent(studentId)) {
          return const Left(
            ValidationFailure('Você já está nesta sala'),
          );
        }

        // 2. Entra na sala.
        final joinResult = await _repository.joinClassroom(
          classroomId: classroom.id,
          studentId: studentId,
          studentName: studentName,
        );
        return joinResult.fold(
          (failure) => Left(failure),
          (_) => Right(classroom),
        );
      },
    );
  }
}
