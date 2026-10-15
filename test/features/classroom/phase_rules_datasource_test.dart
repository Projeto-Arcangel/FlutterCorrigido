import 'dart:convert';

import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/classroom/data/datasources/supabase/classroom_supabase_datasource.dart';
import 'package:arcangel_o_oficial/features/classroom/data/repositories/classroom_repository_impl.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/usecases/manage_classroom_phases.dart';
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

  test('salva prazo e nota mínima na fase, em UTC', () async {
    final result = await repository.updatePhaseRules(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: PhaseRules(
        opensAt: DateTime.utc(2026, 10, 20, 11),
        closesAt: DateTime.utc(2026, 10, 25, 21, 30),
        passPct: 70,
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
    });
  });

  test('sem datas nem nota mínima: limpa os ajustes (NULL)', () async {
    await repository.updatePhaseRules(
      classroomId: 'c1',
      phaseId: 'f1',
      rules: const PhaseRules(),
    );
    expect(jsonDecode(fake.requests.single.body), {
      'opens_at': null,
      'closes_at': null,
      'pass_pct': null,
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

  test('envio recusado pela regra da fase traz a mensagem do servidor',
      () async {
    fake.responses['POST submit_quiz'] = (
      400,
      {
        'code': '22023',
        'message': 'Esta fase já fechou e não aceita mais respostas.',
      }
    );
    final result = await repository.submitQuiz(
      classroomId: 'c1',
      phaseId: 'f1',
      answers: const {'q1': 0},
    );
    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<ValidationFailure>());
    expect(
      failure!.message,
      'Esta fase já fechou e não aceita mais respostas.',
    );
  });

  test('resultado traz a nota da tentativa e a melhor nota', () async {
    fake.responses['POST submit_quiz'] = (
      200,
      {
        'total': 2,
        'correct': 1,
        'first_attempt': false,
        'attempt_pct': 100.00,
        'best_pct': 100.00,
        'questions': <Object>[],
      }
    );
    final result = await repository.submitQuiz(
      classroomId: 'c1',
      phaseId: 'f1',
      answers: const {'q1': 0},
    );
    final sub = result.fold((_) => null, (s) => s)!;
    expect(sub.correct, 1); // nota oficial: a da 1ª tentativa
    expect(sub.attemptPct, 100);
    expect(sub.bestPct, 100);
  });
}
