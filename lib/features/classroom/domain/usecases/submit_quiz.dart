import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/quiz_submission_result.dart';
import '../repositories/classroom_repository.dart';

/// Envia as respostas do aluno para correção **no servidor** (RPC `submit_quiz`).
///
/// O servidor calcula a nota contra o gabarito, grava-a e devolve o resumo —
/// o cliente nunca informa a própria nota.
class SubmitQuiz {
  final ClassroomRepository _repository;
  const SubmitQuiz(this._repository);

  Future<Either<Failure, QuizSubmissionResult>> call({
    required String classroomId,
    required String phaseId,
    required Map<String, int> answers,
  }) {
    return _repository.submitQuiz(
      classroomId: classroomId,
      phaseId: phaseId,
      answers: answers,
    );
  }
}
