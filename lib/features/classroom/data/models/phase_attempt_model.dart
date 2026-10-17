import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/phase_attempt.dart';

/// Lê o JSON das RPCs de tentativa (`start_attempt`, `open_question`,
/// `answer_question`, `get_classroom_roster`).
abstract final class AttemptJson {
  static PhaseAttempt attempt(Map<String, dynamic> map) {
    final questions = _list(map['questions']);
    return PhaseAttempt(
      attemptId: map['attempt_id'].toString(),
      phaseId: (map['phase_id'] ?? '').toString(),
      attemptNo: _int(map['attempt_no'], 1),
      firstAttempt: (map['first_attempt'] as bool?) ?? false,
      timerEnabled: (map['timer_enabled'] as bool?) ?? false,
      timerLevel: (map['timer_level'] as String?) ?? 'normal',
      questions: questions.map(QuestionModel.fromMap).toList(),
      timeLimits: {
        for (final q in questions)
          if (q['limit_s'] != null) q['id'].toString(): _int(q['limit_s']),
      },
      answers: _list(map['answers']).map(feedback).toList(),
      points: _int(map['points']),
      streak: _int(map['streak']),
      nextQuestionId: map['next_question_id']?.toString(),
      opened: map['opened'] is Map ? opened(_map(map['opened'])) : null,
      result: map['finished'] == true && map['result'] is Map
          ? result(_map(map['result']))
          : null,
    );
  }

  static AnswerFeedback feedback(Map<String, dynamic> map) => AnswerFeedback(
        questionId: map['question_id'].toString(),
        score: _double(map['score']),
        correct: (map['correct'] as bool?) ?? false,
        timedOut: (map['timed_out'] as bool?) ?? false,
        streak: _int(map['streak']),
        multiplier: _double(map['multiplier'], 1),
        points: _int(map['points']),
        reveal: map['reveal'] is Map ? _map(map['reveal']) : const {},
      );

  static OpenedQuestion opened(Map<String, dynamic> map) => OpenedQuestion(
        questionId: map['question_id'].toString(),
        limitS: map['limit_s'] == null ? null : _int(map['limit_s']),
        elapsedS: _double(map['elapsed_s']),
        expired: map['answered'] == true && map['feedback'] is Map
            ? feedback(_map(map['feedback']))
            : null,
      );

  static AnswerOutcome outcome(Map<String, dynamic> map) => AnswerOutcome(
        feedback: feedback(map),
        totalPoints: _int(map['total_points']),
        result: map['finished'] == true && map['result'] is Map
            ? result(_map(map['result']))
            : null,
      );

  static AttemptResult result(Map<String, dynamic> map) {
    final official =
        map['official'] is Map ? _map(map['official']) : const <String, dynamic>{};
    return AttemptResult(
      attemptId: map['attempt_id'].toString(),
      attemptNo: _int(map['attempt_no'], 1),
      firstAttempt: (map['first_attempt'] as bool?) ?? false,
      total: _int(map['total']),
      score: _double(map['score']),
      pct: _double(map['pct']),
      stars: _int(map['stars']),
      points: _int(map['points']),
      bestStreak: _int(map['best_streak']),
      xp: _int(map['xp']),
      gold: _int(map['gold']),
      officialTotal: _int(official['total']),
      officialCorrect: _double(official['correct']),
      officialPct: _double(official['pct']),
      bestPct: _double(map['best_pct']),
      bestStars: _int(map['best_stars']),
      review: _list(map['review']).map(_reviewItem).toList(),
      achievements: [
        for (final a in _list(map['achievements']))
          UnlockedAchievement(
            id: a['id'].toString(),
            title: (a['title'] as String?) ?? '',
            gold: _int(a['gold']),
          ),
      ],
    );
  }

  static ClassroomMember member(Map<String, dynamic> map) => ClassroomMember(
        studentId: map['student_id'].toString(),
        name: (map['student_name'] as String?) ?? '',
        registration: (map['registration'] as String?) ?? '',
        inProgressPhaseIds: {
          for (final id in (map['in_progress'] as List?) ?? const []) '$id',
        },
      );

  static AttemptReviewItem _reviewItem(Map<String, dynamic> map) =>
      AttemptReviewItem(
        questionId: map['question_id'].toString(),
        score: _double(map['score']),
        correct: (map['correct'] as bool?) ?? false,
        answered: (map['answered'] as bool?) ?? false,
        timedOut: (map['timed_out'] as bool?) ?? false,
        response: map['response'] is Map ? _map(map['response']) : null,
        reveal: map['reveal'] is Map ? _map(map['reveal']) : const {},
        explanation: (map['explanation'] as String?) ?? '',
      );

  static Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value! as Map);

  static List<Map<String, dynamic>> _list(Object? value) =>
      ((value as List?) ?? const []).map(_map).toList();

  /// numeric do Postgres chega como número ou texto, conforme o caminho.
  static double _double(Object? value, [double fallback = 0]) => value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}') ?? fallback;

  static int _int(Object? value, [int fallback = 0]) => value is num
      ? value.toInt()
      : int.tryParse('${value ?? ''}') ?? fallback;
}
