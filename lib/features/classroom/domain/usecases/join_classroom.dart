import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classroom.dart';
import '../repositories/classroom_repository.dart';

/// Aluno entra numa sala usando o código de 6 caracteres.
///
/// Regras:
/// 1. O aluno não pode estar em outra sala (1 sala por vez).
/// 2. A sala não pode estar cheia (max 50 alunos).
/// 3. O código deve existir e estar ativo.
class JoinClassroom {
  final ClassroomRepository _repository;
  const JoinClassroom(this._repository);

  Future<Either<Failure, Classroom>> call({
    required String code,
    required String studentId,
  }) async {
    final trimmed = code.trim().toUpperCase();

    if (trimmed.length != 6) {
      return const Left(
        ValidationFailure('O código deve ter 6 caracteres'),
      );
    }

    // 1. Verifica se o aluno já está em uma sala.
    final currentResult = await _repository.getStudentClassroom(studentId);
    final currentClassroom = currentResult.fold((_) => null, (c) => c);
    if (currentClassroom != null) {
      return Left(
        ValidationFailure(
          'Você já está na sala "${currentClassroom.name}". '
          'Saia dela antes de entrar em outra.',
        ),
      );
    }

    // 2. Busca a sala pelo código.
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

        // 3. Entra na sala.
        final joinResult = await _repository.joinClassroom(
          classroomId: classroom.id,
          studentId: studentId,
        );
        return joinResult.fold(
          (failure) => Left(failure),
          (_) => Right(classroom),
        );
      },
    );
  }
}
