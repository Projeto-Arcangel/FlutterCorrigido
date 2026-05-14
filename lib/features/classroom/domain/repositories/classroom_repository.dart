import 'package:dartz/dartz.dart';
import '../../../../../../core/errors/failure.dart';
import '../entities/classroom.dart';

abstract class ClassroomRepository {
  Future<Either<Failure, Classroom>> joinByCode({
    required String code,
    required String userId,
  });

  Future<Either<Failure, List<Classroom>>> getUserClassrooms(String userId);
}