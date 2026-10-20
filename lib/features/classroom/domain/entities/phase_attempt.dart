import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';

/// Correção de UMA resposta, feita no servidor (RPC `answer_question`).
///
/// A resposta trava ao confirmar e o aluno já vê se acertou e qual era a
/// certa; a explicação só vem no fim da fase ([AttemptResult.review]).
class AnswerFeedback extends Equatable {
  final String questionId;

  /// Nota da questão, de 0 a 1 (múltipla escolha: 0 ou 1).
  final double score;
  final bool correct;

  /// O tempo do relógio acabou: a questão valeu 0.
  final bool timedOut;

  /// Sequência de acertos depois desta resposta (0 se errou).
  final int streak;

  /// Multiplicador desta resposta: 1, 1,5 (3 seguidos) ou 2 (5 seguidos).
  final double multiplier;
  final int points;

  /// Gabarito revelado. Múltipla escolha: `{'correct_answer': 2}`.
  final Map<String, dynamic> reveal;

  const AnswerFeedback({
    required this.questionId,
    required this.score,
    required this.correct,
    required this.timedOut,
    required this.streak,
    required this.multiplier,
    required this.points,
    this.reveal = const {},
  });

  /// Alternativa certa (múltipla escolha).
  int? get correctAnswer => (reveal['correct_answer'] as num?)?.toInt();

  @override
  List<Object?> get props => [
        questionId,
        score,
        correct,
        timedOut,
        streak,
        multiplier,
        points,
        reveal,
      ];
}

/// Uma questão na correção final da tentativa.
class AttemptReviewItem extends Equatable {
  final String questionId;
  final double score;
  final bool correct;

  /// `false` = a fase fechou antes de o aluno chegar nela.
  final bool answered;
  final bool timedOut;

  /// O que o aluno marcou (`null` = sem resposta).
  final Map<String, dynamic>? response;
  final Map<String, dynamic> reveal;
  final String explanation;

  const AttemptReviewItem({
    required this.questionId,
    required this.score,
    required this.correct,
    required this.answered,
    required this.timedOut,
    this.response,
    this.reveal = const {},
    this.explanation = '',
  });

  /// Alternativa escolhida (múltipla escolha).
  int? get chosen => (response?['choice'] as num?)?.toInt();
  int? get correctAnswer => (reveal['correct_answer'] as num?)?.toInt();

  @override
  List<Object?> get props => [
        questionId,
        score,
        correct,
        answered,
        timedOut,
        response,
        reveal,
        explanation,
      ];
}

/// Conferência na hora de uma parte da resposta (RPC `check_answer_part`).
/// Cruzadinha: [correct] da palavra [index]. Caça-palavras: a palavra
/// [word] (índice [index]) que a marcação formou, ou nada.
class PartCheck extends Equatable {
  final int? index;
  final bool correct;
  final String? word;

  const PartCheck({this.index, this.correct = false, this.word});

  @override
  List<Object?> get props => [index, correct, word];
}

/// Conquista liberada numa entrega, com as moedas que deu.
class UnlockedAchievement extends Equatable {
  final String id;
  final String title;
  final int gold;

  const UnlockedAchievement({
    required this.id,
    required this.title,
    required this.gold,
  });

  @override
  List<Object?> get props => [id, title, gold];
}

/// Resultado de uma tentativa entregue, calculado no servidor.
class AttemptResult extends Equatable {
  final String attemptId;
  final int attemptNo;

  /// Esta tentativa virou a nota oficial (1ª entrega) — só ela dá XP.
  final bool firstAttempt;

  /// Nota DESTA tentativa: soma das notas (0 a 1) sobre o total.
  final int total;
  final double score;
  final double pct;
  final int stars;
  final int points;
  final int bestStreak;
  final int xp;
  final int gold;

  /// Nota oficial (1ª entrega).
  final int officialTotal;
  final double officialCorrect;
  final double officialPct;

  /// Melhor nota (%) — a que dá as estrelas e libera a próxima fase.
  final double bestPct;
  final int bestStars;
  final List<AttemptReviewItem> review;

  /// Conquistas que esta entrega liberou (as moedas delas não entram em
  /// [gold], que é só das estrelas).
  final List<UnlockedAchievement> achievements;

  const AttemptResult({
    required this.attemptId,
    required this.attemptNo,
    required this.firstAttempt,
    required this.total,
    required this.score,
    required this.pct,
    required this.stars,
    required this.points,
    required this.bestStreak,
    required this.xp,
    required this.gold,
    required this.officialTotal,
    required this.officialCorrect,
    required this.officialPct,
    required this.bestPct,
    required this.bestStars,
    this.review = const [],
    this.achievements = const [],
  });

  @override
  List<Object?> get props => [
        attemptId,
        attemptNo,
        firstAttempt,
        total,
        score,
        pct,
        stars,
        points,
        bestStreak,
        xp,
        gold,
        officialTotal,
        officialCorrect,
        officialPct,
        bestPct,
        bestStars,
        review,
        achievements,
      ];
}

/// Questão aberta com relógio (RPC `open_question`).
class OpenedQuestion extends Equatable {
  final String questionId;

  /// Segundos para responder (`null` = fase sem relógio).
  final int? limitS;

  /// Segundos que já passaram desde que a questão apareceu (ao retomar).
  final double elapsedS;

  /// O tempo já tinha acabado (o aluno saiu e voltou): a questão travou
  /// valendo 0.
  final AnswerFeedback? expired;

  const OpenedQuestion({
    required this.questionId,
    this.limitS,
    this.elapsedS = 0,
    this.expired,
  });

  /// Quanto falta, em segundos (nunca negativo).
  double? get remainingS => limitS == null
      ? null
      : (limitS! - elapsedS).clamp(0.0, limitS!.toDouble()).toDouble();

  @override
  List<Object?> get props => [questionId, limitS, elapsedS, expired];
}

/// Tentativa aberta ou retomada (RPC `start_attempt`).
class PhaseAttempt extends Equatable {
  final String attemptId;
  final String phaseId;
  final int attemptNo;

  /// Ainda não há nota oficial: esta tentativa vai ser a oficial.
  final bool firstAttempt;
  final bool timerEnabled;
  final String timerLevel;

  /// Questões SEM gabarito, na ordem fixada no início da tentativa.
  final List<Question> questions;

  /// Segundos de cada questão (só com relógio), por id.
  final Map<String, int> timeLimits;

  /// Respostas já travadas (ao retomar).
  final List<AnswerFeedback> answers;
  final int points;
  final int streak;

  /// Próxima questão a responder (`null` = não falta nenhuma).
  final String? nextQuestionId;

  /// Questão que já estava aberta com relógio (ao retomar).
  final OpenedQuestion? opened;

  /// Tentativa já entregue (ex.: retomada depois do fim do tempo).
  final AttemptResult? result;

  const PhaseAttempt({
    required this.attemptId,
    required this.phaseId,
    required this.attemptNo,
    required this.firstAttempt,
    required this.timerEnabled,
    required this.timerLevel,
    required this.questions,
    this.timeLimits = const {},
    this.answers = const [],
    this.points = 0,
    this.streak = 0,
    this.nextQuestionId,
    this.opened,
    this.result,
  });

  bool get finished => result != null;

  @override
  List<Object?> get props => [
        attemptId,
        phaseId,
        attemptNo,
        firstAttempt,
        timerEnabled,
        timerLevel,
        questions,
        timeLimits,
        answers,
        points,
        streak,
        nextQuestionId,
        opened,
        result,
      ];
}

/// Retorno de `answer_question`: a correção e, na última, o resultado.
class AnswerOutcome extends Equatable {
  final AnswerFeedback feedback;
  final int totalPoints;
  final AttemptResult? result;

  const AnswerOutcome({
    required this.feedback,
    required this.totalPoints,
    this.result,
  });

  bool get finished => result != null;

  @override
  List<Object?> get props => [feedback, totalPoints, result];
}

/// Aluno da turma, para o painel do professor ("não entregou").
class ClassroomMember extends Equatable {
  final String studentId;
  final String name;
  final String registration;

  /// Fases abertas que o aluno começou e ainda não entregou.
  final Set<String> inProgressPhaseIds;

  const ClassroomMember({
    required this.studentId,
    required this.name,
    this.registration = '',
    this.inProgressPhaseIds = const {},
  });

  @override
  List<Object?> get props =>
      [studentId, name, registration, inProgressPhaseIds];
}
