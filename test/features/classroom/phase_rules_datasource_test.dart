import 'dart:convert';

import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/classroom/data/datasources/supabase/classroom_supabase_datasource.dart';
import 'package:arcangel_o_oficial/features/classroom/data/repositories/classroom_repository_impl.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/usecases/manage_classroom_phases.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase sem rede: guarda os pedidos e responde o que o teste mandar.
class _FakeSupabaseHttp extends http.BaseClient {
  final requests = <({String method, Uri url, String body})>[];

  /// Resposta por "MÉTODO caminho-final" (ex.: 'PATCH classroom_phases').
  final responses = <String, (int, Object?)>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    requests.add((method: request.method, url: request.url, body: body));
    final key = '${request.method} ${request.url.pathSegments.last}';
    final (status, payload) = responses[key] ?? (200, null);
    final text = payload == null ? '' : jsonEncode(payload);
    return http.StreamedResponse(
      Stream.value(utf8.encode(text)),
      text.isEmpty && status == 200 ? 204 : status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

void main() {
  late _FakeSupabaseHttp fake;
  late ClassroomRepositoryImpl repository;

  setUp(() {
    fake = _FakeSupabaseHttp();
    repository = ClassroomRepositoryImpl(
      ClassroomSupabaseDatasource(
        SupabaseClient('http://supabase.test', 'chave', httpClient: fake),
      ),
      Logger(level: Level.off),
    );
  });

  test('salva prazo, nota mínima e relógio na fase, em UTC', () async {
    final result = await repository.updatePhaseRules(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: PhaseRules(
        opensAt: DateTime.utc(2026, 10, 20, 11),
        closesAt: DateTime.utc(2026, 10, 25, 21, 30),
        passPct: 70,
        timerEnabled: true,
        timerLevel: 'short',
      ),
    );

    expect(result.isRight(), isTrue);
    final patch = fake.requests.single;
    expect(patch.method, 'PATCH');
    expect(patch.url.path, endsWith('/classroom_phases'));
    expect(patch.url.queryParameters['id'], 'eq.f1');
    expect(jsonDecode(patch.body), {
      'opens_at': '2026-10-20T11:00:00.000Z',
      'closes_at': '2026-10-25T21:30:00.000Z',
      'pass_pct': 70.0,
      'timer_enabled': true,
      'timer_level': 'short',
    });
  });

  test('sem ajustes: limpa datas e nota mínima, relógio desligado', () async {
    await repository.updatePhaseRules(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: const PhaseRules(),
    );
    expect(jsonDecode(fake.requests.single.body), {
      'opens_at': null,
      'closes_at': null,
      'pass_pct': null,
      'timer_enabled': false,
      'timer_level': 'normal',
    });
  });

  test('restrição do banco vira mensagem clara', () async {
    fake.responses['PATCH classroom_phases'] = (
      400,
      {
        'code': '23514',
        'message': 'new row for relation "classroom_phases" violates check '
            'constraint "classroom_phases_dates_order_check"',
      }
    );
    final result = await repository.updatePhaseRules(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: const PhaseRules(),
    );
    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<ValidationFailure>());
    expect(failure!.message, 'O fechamento precisa ser depois da abertura.');
  });

  test('o caso de uso recusa antes de ir ao servidor', () async {
    final useCase = UpdatePhaseRules(repository);
    final result = await useCase(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: const PhaseRules(passPct: 0),
    );
    expect(result.fold((f) => f.message, (_) => ''), contains('1% a 100%'));
    expect(fake.requests, isEmpty);
  });

  test('abrir tentativa: questões sem gabarito, tempos e onde parou',
      () async {
    fake.responses['POST start_attempt'] = (
      200,
      {
        'attempt_id': 'a1',
        'phase_id': 'f1',
        'attempt_no': 2,
        'first_attempt': false,
        'timer_enabled': true,
        'timer_level': 'short',
        'questions': [
          {'id': 'q1', 'text': 'Q1', 'options': ['A', 'B'], 'type': 'multiple_choice', 'limit_s': 15},
          {'id': 'q2', 'text': 'Q2', 'options': ['A', 'B'], 'type': 'multiple_choice', 'limit_s': 20},
        ],
        'answers': [
          {
            'question_id': 'q1', 'score': 1.000, 'correct': true,
            'timed_out': false, 'streak': 1, 'multiplier': 1.0,
            'points': 14, 'reveal': {'correct_answer': 1},
          },
        ],
        'points': 14,
        'streak': 1,
        'next_question_id': 'q2',
        'opened': {'question_id': 'q2', 'limit_s': 20, 'elapsed_s': 4.5},
        'finished': false,
        'result': null,
      }
    );
    final result =
        await repository.startAttempt(classroomId: 'c1', phaseId: 'f1');
    final attempt = result.fold((_) => null, (a) => a)!;

    expect(jsonDecode(fake.requests.single.body),
        {'p_classroom': 'c1', 'p_phase': 'f1'},);
    expect(attempt.attemptNo, 2);
    expect(attempt.firstAttempt, isFalse);
    expect(attempt.questions.map((q) => q.id), ['q1', 'q2']);
    expect(attempt.timeLimits, {'q1': 15, 'q2': 20});
    expect(attempt.answers.single.correctAnswer, 1);
    expect(attempt.answers.single.points, 14);
    expect(attempt.nextQuestionId, 'q2');
    expect(attempt.opened!.remainingS, 15.5);
    expect(attempt.finished, isFalse);
  });

  test('resposta: manda a escolha e a última traz o resultado', () async {
    fake.responses['POST answer_question'] = (
      200,
      {
        'question_id': 'q2', 'score': 0.5, 'correct': false,
        'timed_out': false, 'streak': 0, 'multiplier': 1.0, 'points': 5,
        'reveal': {'correct_answer': 0},
        'total_points': 19,
        'finished': true,
        'result': {
          'attempt_id': 'a1', 'attempt_no': 1, 'first_attempt': true,
          'total': 2, 'score': 1.5, 'pct': 75.00, 'stars': 1,
          'points': 19, 'best_streak': 1, 'xp': 9, 'gold': 5,
          'official': {'total': 2, 'correct': '1.500', 'pct': 75.00},
          'best_pct': 75.00, 'best_stars': 1,
          'review': [
            {
              'question_id': 'q2', 'score': 0.5, 'correct': false,
              'answered': true, 'timed_out': false,
              'response': {'choice': 1}, 'reveal': {'correct_answer': 0},
              'explanation': 'Porque sim.',
            },
          ],
        },
      }
    );
    final result = await repository.answerQuestion(
      attemptId: 'a1',
      questionId: 'q2',
      response: const {'choice': 1},
    );
    final outcome = result.fold((_) => null, (o) => o)!;

    expect(jsonDecode(fake.requests.single.body), {
      'p_attempt': 'a1',
      'p_question': 'q2',
      'p_response': {'choice': 1},
    });
    expect(outcome.feedback.score, 0.5);
    expect(outcome.totalPoints, 19);
    expect(outcome.finished, isTrue);
    final r = outcome.result!;
    expect(r.stars, 1);
    expect(r.officialCorrect, 1.5); // numeric pode chegar como texto
    expect(r.xp, 9);
    expect(r.review.single.chosen, 1);
    expect(r.review.single.explanation, 'Porque sim.');
  });

  test('recusa da regra da fase vira mensagem final', () async {
    fake.responses['POST answer_question'] = (
      400,
      {
        'code': '22023',
        'message': 'Esta fase já fechou e não aceita mais respostas.',
      }
    );
    final result = await repository.answerQuestion(
      attemptId: 'a1',
      questionId: 'q1',
    );
    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<ValidationFailure>());
    expect(failure!.message, 'Esta fase já fechou e não aceita mais respostas.');
    final body = jsonDecode(fake.requests.single.body) as Map<String, dynamic>;
    expect(body['p_response'], isNull);
  });

  test('lista da turma com as fases em andamento', () async {
    fake.responses['POST get_classroom_roster'] = (
      200,
      [
        {
          'student_id': 's1', 'student_name': 'Bia', 'registration': 'SP1',
          'in_progress': ['f1'],
        },
        {'student_id': 's2', 'student_name': 'Caio', 'in_progress': <Object>[]},
      ]
    );
    final result = await repository.getRoster('c1');
    final members = result.fold((_) => null, (m) => m)!;
    expect(members.map((m) => m.name), ['Bia', 'Caio']);
    expect(members.first.inProgressPhaseIds, {'f1'});
    expect(members.last.registration, '');
  });

  test('editar a questão salva o tempo escolhido (ou volta ao automático)',
      () async {
    const question = Question(
      id: 'q1',
      text: 'Q1',
      options: ['A', 'B'],
      correctAnswer: 0,
      explanation: '',
      type: QuestionType.multipleChoice,
      timeLimitS: 45,
    );
    await repository.updateQuestionInPhase(
      classroomId: 'c1',
      phaseId: 'f1',
      question: question,
    );
    await repository.updateQuestionInPhase(
      classroomId: 'c1',
      phaseId: 'f1',
      question: question.withTimeLimit(null),
    );
    final bodies = fake.requests
        .where((r) => r.method == 'PATCH')
        .map((r) => jsonDecode(r.body) as Map<String, dynamic>)
        .toList();
    expect(bodies.first['time_limit_s'], 45);
    expect(bodies.last.containsKey('time_limit_s'), isTrue);
    expect(bodies.last['time_limit_s'], isNull);
  });

  test('gravar questão de ligar manda tipo, conteúdo e gabarito', () async {
    fake.responses['GET questions'] = (200, <Object>[]);
    final question = buildMatchQuestion(
      text: 'Ligue.',
      pairs: const [
        MatchPair('a', 'x'),
        MatchPair('b', 'y'),
        MatchPair('c', 'z'),
      ],
    );
    final result = await repository.addQuestionsToPhase(
      classroomId: 'c1',
      phaseId: 'f1',
      questions: [question],
    );
    expect(result.isRight(), isTrue);
    final post = fake.requests.singleWhere((r) => r.method == 'POST');
    final row = (jsonDecode(post.body) as List).single as Map<String, dynamic>;
    expect(row['type'], 'match_columns');
    expect(row['options'], isEmpty);
    expect(row['correct_answer'], 0);
    expect(row['content'], question.content);
    expect(row['answer'], question.answer);
    expect(row['sort_order'], 1);
  });
}
