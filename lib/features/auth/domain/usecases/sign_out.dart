import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../repositories/auth_repository.dart';

class SignOut {
  final AuthRepository _repository;
  const SignOut(this._repository);

  Future<Either<Failure, void>> call() => _repository.signOut();
}