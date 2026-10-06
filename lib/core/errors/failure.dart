import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'Algo deu errado. Tente novamente em instantes.',
  ]);
}

/// Leva uma [Failure] por um `throw` (ex.: dentro de um FutureProvider) sem
/// perder a mensagem amigável: `toString()` devolve só a mensagem, sem o
/// prefixo "Exception:" que `Exception(msg)` colocaria na tela.
class FailureException implements Exception {
  const FailureException(this.failure);

  final Failure failure;

  @override
  String toString() => failure.message;
}