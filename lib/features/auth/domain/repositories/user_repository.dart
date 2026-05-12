import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../entities/user.dart';

abstract class UserRepository {
  /// Cria o documento do usuário no Firestore se ainda não existir.
  Future<Either<Failure, void>> createProfileIfAbsent(User user);
}