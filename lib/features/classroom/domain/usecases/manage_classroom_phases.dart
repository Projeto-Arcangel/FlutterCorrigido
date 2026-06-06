import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../lesson/domain/entities/question.dart';
import '../entities/classroom_phase.dart';
import '../repositories/classroom_repository.dart';

/// Use cases agrupados para gerenciar fases (CRUD + ordenação) de uma
/// sala de aula. Cada classe expõe uma única operação, mantendo o
/// padrão de Clean Architecture.

/// Cria uma fase vazia (sem questões) em uma sala.
class CreateEmptyPhase {
  final ClassroomRepository _repository;
  const CreateEmptyPhase(this._repository);

  Future<Either<Failure, ClassroomPhase>> call({
    required String classroomId,
    required String title,
    required String description,
    double weight = 1.0,
  }) {
    if (classroomId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('Turma inválida.')),
      );
    }
    if (title.trim().isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure('Dê um nome para a fase antes de criar.'),
        ),
      );
    }
    if (weight <= 0) {
      return Future.value(
        const Left(ValidationFailure('O peso da fase deve ser maior que zero.')),
      );
    }
    return _repository.createEmptyPhase(
      classroomId: classroomId,
      title: title.trim(),
      description: description.trim(),
      weight: weight,
    );
  }
}

/// Atualiza o título e a descrição de uma fase existente.
class UpdatePhase {
  final ClassroomRepository _repository;
  const UpdatePhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
    required String title,
    required String description,
    double weight = 1.0,
  }) {
    if (title.trim().isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure('O nome da fase não pode ficar em branco.'),
        ),
      );
    }
    if (weight <= 0) {
      return Future.value(
        const Left(ValidationFailure('O peso da fase deve ser maior que zero.')),
      );
    }
    return _repository.updatePhase(
      classroomId: classroomId,
      phaseId: phaseId,
      title: title.trim(),
      description: description.trim(),
      weight: weight,
    );
  }
}

/// Apaga uma fase. Operação irreversível: as questões da fase também
/// são removidas.
class DeletePhase {
  final ClassroomRepository _repository;
  const DeletePhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
  }) {
    return _repository.deletePhase(
      classroomId: classroomId,
      phaseId: phaseId,
    );
  }
}

/// Reordena as fases conforme a nova lista de IDs.
class ReorderPhases {
  final ClassroomRepository _repository;
  const ReorderPhases(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required List<String> orderedPhaseIds,
  }) {
    return _repository.reorderPhases(
      classroomId: classroomId,
      orderedPhaseIds: orderedPhaseIds,
    );
  }
}

/// Adiciona questões a uma fase já existente (sem criar fase nova).
class AddQuestionsToPhase {
  final ClassroomRepository _repository;
  const AddQuestionsToPhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
    required List<Question> questions,
  }) {
    if (questions.isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure('Nenhuma questão para adicionar.'),
        ),
      );
    }
    return _repository.addQuestionsToPhase(
      classroomId: classroomId,
      phaseId: phaseId,
      questions: questions,
    );
  }
}

/// Reordena as questões dentro de uma fase.
class ReorderQuestionsInPhase {
  final ClassroomRepository _repository;
  const ReorderQuestionsInPhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
    required List<String> orderedQuestionIds,
  }) {
    return _repository.reorderQuestionsInPhase(
      classroomId: classroomId,
      phaseId: phaseId,
      orderedQuestionIds: orderedQuestionIds,
    );
  }
}

/// Atualiza uma questão dentro de uma fase específica.
class UpdateQuestionInPhase {
  final ClassroomRepository _repository;
  const UpdateQuestionInPhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
    required Question question,
  }) {
    return _repository.updateQuestionInPhase(
      classroomId: classroomId,
      phaseId: phaseId,
      question: question,
    );
  }
}

/// Remove uma questão de uma fase.
class DeleteQuestionFromPhase {
  final ClassroomRepository _repository;
  const DeleteQuestionFromPhase(this._repository);

  Future<Either<Failure, void>> call({
    required String classroomId,
    required String phaseId,
    required String questionId,
  }) {
    return _repository.deleteQuestionFromPhase(
      classroomId: classroomId,
      phaseId: phaseId,
      questionId: questionId,
    );
  }
}
