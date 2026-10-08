import 'dart:convert';

import 'package:arcangel_o_oficial/features/classroom/data/datasources/supabase/classroom_supabase_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Responde às chamadas do Supabase sem rede e guarda o que foi pedido.
class _FakeSupabaseHttp extends http.BaseClient {
  final requests = <({String method, Uri url, String body})>[];

  /// Linhas devolvidas para cada tabela consultada (GET).
  final rows = <String, List<Map<String, dynamic>>>{};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    requests.add((method: request.method, url: request.url, body: body));
    final table = request.url.pathSegments.last;
    final payload =
        request.method == 'GET' ? jsonEncode(rows[table] ?? []) : '';
    return http.StreamedResponse(
      Stream.value(utf8.encode(payload)),
      payload.isEmpty ? 204 : 200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Iterable<({String method, Uri url, String body})> to(String path) =>
      requests.where((r) => r.url.path.endsWith(path));
}

void main() {
  late _FakeSupabaseHttp fake;
  late ClassroomSupabaseDatasource datasource;

  setUp(() {
    fake = _FakeSupabaseHttp();
    datasource = ClassroomSupabaseDatasource(
      SupabaseClient('http://supabase.test', 'chave', httpClient: fake),
    );
  });

  String orderOf(Uri url) => url.queryParameters['order'] ?? '';

  test('professor recebe as fases em ordem CRESCENTE de posição', () async {
    // No postgrest-dart, .order() é decrescente por padrão: sem
    // ascending: true as fases apareciam de trás para frente.
    fake.rows['classroom_phases'] = [
      for (var i = 1; i <= 3; i++)
        {
          'id': 'f$i',
          'classroom_id': 'sala',
          'title': 'Fase $i',
          'sort_order': i,
          'questions': [
            {
              'id': 'q2',
              'phase_id': 'f$i',
              'text': 'B',
              'options': ['a'],
              'correct_answer': 0,
              'sort_order': 2
            },
            {
              'id': 'q1',
              'phase_id': 'f$i',
              'text': 'A',
              'options': ['a'],
              'correct_answer': 0,
              'sort_order': 1
            },
          ],
        },
    ];

    final phases = await datasource.fetchClassroomPhases('sala');

    expect(orderOf(fake.to('/classroom_phases').single.url),
        startsWith('sort_order.asc'));
    expect(phases.map((p) => p.title), ['Fase 1', 'Fase 2', 'Fase 3']);
    expect(phases.first.questions.map((q) => q.text), ['A', 'B']);
  });

  test('reordenar fases é uma única chamada, com a ordem completa', () async {
    await datasource.reorderPhases(
        classroomId: 'sala', orderedPhaseIds: ['f3', 'f1', 'f2']);

    expect(fake.requests.where((r) => r.method == 'PATCH'), isEmpty);
    final call = fake.to('/rpc/reorder_phases').single;
    expect(jsonDecode(call.body), {
      'p_classroom': 'sala',
      'p_phase_ids': ['f3', 'f1', 'f2'],
    });
  });

  test('reordenar questões é uma única chamada, com a ordem completa',
      () async {
    await datasource.reorderQuestionsInPhase(
      classroomId: 'sala',
      phaseId: 'f1',
      orderedQuestionIds: ['q2', 'q1'],
    );

    expect(fake.requests.where((r) => r.method == 'PATCH'), isEmpty);
    expect(jsonDecode(fake.to('/rpc/reorder_questions').single.body), {
      'p_phase': 'f1',
      'p_question_ids': ['q2', 'q1'],
    });
  });

  test('excluir fase renumera mantendo a ordem (sem inverter)', () async {
    fake.rows['classroom_phases'] = [
      {'id': 'f1'},
      {'id': 'f2'},
      {'id': 'f4'},
    ];

    await datasource.deletePhase(classroomId: 'sala', phaseId: 'f3');

    final leitura = fake.requests.firstWhere(
      (r) => r.method == 'GET' && r.url.path.endsWith('/classroom_phases'),
    );
    expect(orderOf(leitura.url), startsWith('sort_order.asc'));
    expect(
        jsonDecode(fake.to('/rpc/reorder_phases').single.body)['p_phase_ids'],
        ['f1', 'f2', 'f4']);
  });

  test('excluir questão renumera mantendo a ordem (sem inverter)', () async {
    fake.rows['questions'] = [
      {'id': 'q1'},
      {'id': 'q3'},
    ];

    await datasource.deleteQuestionFromPhase(
        classroomId: 'sala', phaseId: 'f1', questionId: 'q2');

    final leitura = fake.requests.firstWhere(
      (r) => r.method == 'GET' && r.url.path.endsWith('/questions'),
    );
    expect(orderOf(leitura.url), startsWith('sort_order.asc'));
    expect(
        jsonDecode(
            fake.to('/rpc/reorder_questions').single.body)['p_question_ids'],
        ['q1', 'q3']);
  });
}
