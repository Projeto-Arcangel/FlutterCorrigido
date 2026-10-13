import 'dart:convert';

import 'package:arcangel_o_oficial/core/errors/error_messages.dart';
import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/classroom/data/datasources/supabase/classroom_supabase_datasource.dart';
import 'package:arcangel_o_oficial/features/classroom/data/repositories/classroom_repository_impl.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase sem rede: guarda os pedidos e responde o que o teste mandar.
class _FakeSupabaseHttp extends http.BaseClient {
  final requests = <({String method, Uri url, String body})>[];

  /// Resposta por "MÉTODO caminho-final" (ex.: 'POST questions').
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

  Iterable<({String method, Uri url, String body})> where(
    String method,
    String path,
  ) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(path));
}

/// Resposta do PostgREST quando o gatilho de armazenamento recusa (PT402).
const _storageLimit = {
  'code': 'PT402',
  'message': 'Seu plano Free guarda até 200 questões e você já tem 199. '
      'Estas 2 questões não cabem.',
  'details': 'stored_limit:200:199:2',
  'hint': 'Apague questões que você não usa mais ou mude de plano.',
};

const _question = Question(
  id: 'q',
  text: 'Enunciado',
  options: ['A', 'B'],
  correctAnswer: 0,
  explanation: '',
  type: QuestionType.multipleChoice,
);

void main() {
  late _FakeSupabaseHttp fake;
  late ClassroomSupabaseDatasource datasource;
  late ClassroomRepositoryImpl repository;

  setUp(() {
    fake = _FakeSupabaseHttp();
    datasource = ClassroomSupabaseDatasource(
      SupabaseClient('http://supabase.test', 'chave', httpClient: fake),
    );
    repository = ClassroomRepositoryImpl(datasource, Logger(level: Level.off));
  });

  test('salvar fase nova sem espaço desfaz a fase (não fica fase vazia)',
      () async {
    fake.responses['GET classroom_phases'] = (200, <Object>[]);
    fake.responses['POST classroom_phases'] = (
      201,
      {
        'id': 'fase-nova',
        'classroom_id': 'sala',
        'title': 'Revisão',
        'sort_order': 1,
      }
    );
    fake.responses['POST questions'] = (402, _storageLimit);

    final result = await repository.saveQuizAsPhase(
      classroomId: 'sala',
      title: 'Revisão',
      description: '',
      questions: const [_question, _question],
    );

    final deleted = fake.where('DELETE', '/classroom_phases').single;
    expect(deleted.url.queryParameters['id'], 'eq.fase-nova');
    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<ValidationFailure>());
    expect(
      failure!.message,
      'Seu plano Free guarda até 200 questões e você já tem 199. Estas 2 '
      'questões não cabem. Apague questões que você não usa mais ou mude de '
      'plano.',
    );
  });

  test('adicionar questões sem espaço mostra a mensagem do plano', () async {
    fake.responses['GET questions'] = (200, <Object>[]);
    fake.responses['POST questions'] = (402, _storageLimit);

    final result = await repository.addQuestionsToPhase(
      classroomId: 'sala',
      phaseId: 'f1',
      questions: const [_question],
    );

    expect(
      result.fold((f) => f.message, (_) => ''),
      contains('Seu plano Free guarda até 200 questões'),
    );
  });

  test('copiar questões é uma chamada só, com a ordem escolhida', () async {
    fake.responses['POST copy_questions_to_phase'] = (200, 3);

    final result = await repository.copyQuestionsToPhase(
      phaseId: 'f1',
      questionIds: ['q3', 'q1', 'q2'],
    );

    expect(result.fold((_) => -1, (n) => n), 3);
    expect(
      fake.requests.where((r) => r.url.path.endsWith('/questions')),
      isEmpty,
    );
    final call = fake.where('POST', '/rpc/copy_questions_to_phase').single;
    expect(
      jsonDecode(call.body),
      {
        'p_phase': 'f1',
        'p_question_ids': ['q3', 'q1', 'q2'],
      },
    );
  });

  test('cópia recusada pela RPC mostra o motivo do servidor', () async {
    fake.responses['POST copy_questions_to_phase'] = (
      400,
      {
        'code': '22023',
        'message': 'Alguma das questões escolhidas não existe mais. '
            'Recarregue a lista e tente de novo.',
      }
    );

    final result = await repository.copyQuestionsToPhase(
      phaseId: 'f1',
      questionIds: ['q1'],
    );

    expect(
      result.fold((f) => f.message, (_) => ''),
      startsWith('Alguma das questões escolhidas não existe mais.'),
    );
  });

  test('banco de questões: uma consulta, mais novas primeiro', () async {
    fake.responses['GET questions'] = (
      200,
      [
        {
          'id': 'q1',
          'text': 'Quem foi Vargas?',
          'options': ['A', 'B'],
          'correct_answer': 1,
          'explanation': '',
          'type': 'multiple_choice',
          'ai_generated': true,
          'created_at': '2026-10-12T10:00:00+00:00',
          'classroom_phases': {
            'id': 'f1',
            'title': 'Era Vargas',
            'classrooms': {'id': 'c1', 'name': 'Turma 9B'},
          },
        },
      ]
    );

    final bank = await datasource.fetchQuestionBank();

    final request = fake.where('GET', '/questions').single;
    expect(request.url.queryParameters['order'], startsWith('created_at.desc'));
    expect(request.url.queryParameters['select'], contains('classrooms!inner'));
    expect(bank.single.classroomName, 'Turma 9B');
    expect(bank.single.phaseTitle, 'Era Vargas');
    expect(bank.single.question.correctAnswer, 1);
    expect(bank.single.aiGenerated, isTrue);
  });

  test('ErrorMessages reconhece o limite do plano', () {
    const e = PostgrestException(
      message: 'Seu plano Pro guarda até 400 questões e você já tem 400. '
          'Esta questão não cabe.',
      code: 'PT402',
      hint: 'Apague questões que você não usa mais ou mude de plano.',
    );
    expect(ErrorMessages.isPlanLimit(e), isTrue);
    expect(ErrorMessages.from(e), endsWith('ou mude de plano.'));
    expect(
      ErrorMessages.isPlanLimit(const PostgrestException(message: 'x')),
      isFalse,
    );
  });
}
