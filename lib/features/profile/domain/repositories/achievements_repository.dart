import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/classmate_profile.dart';

abstract class AchievementsRepository {
  /// Conquistas do aluno logado com o progresso de cada uma. O servidor
  /// libera antes o que já foi completado (e credita as moedas).
  Future<Either<Failure, MyAchievements>> getMyAchievements();

  /// Perfil de um aluno da turma (`null` se quem pede não for da turma ou
  /// o aluno não estiver nela).
  Future<Either<Failure, ClassmateProfile?>> getClassmateProfile({
    required String classroomId,
    required String studentId,
  });
}
