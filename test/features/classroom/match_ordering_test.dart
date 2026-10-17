import 'dart:math';

import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_attempt.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/repositories/classroom_repository.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/attempt_controller.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/classroom_providers.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/match_columns_board.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/ordering_board.dart';
import 'package:arcangel_o_oficial/features/lesson/data/models/question_model.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _pairs = [
  MatchPair('Brasil', 'Brasília'),
  MatchPair('França', 'Paris'),
  MatchPair('Japão', 'Tóquio'),
];
const _ordered = ['Colônia', 'Império', 'República Velha', 'Era Vargas'];

class _FakeRepo extends Mock implements ClassroomRepository {
  _FakeRepo(this.attempt);
  final PhaseAttempt attempt;
  final sent = <Map<String, dynamic>?>[];

  @override
  Future<Either<Failure, PhaseAttempt>> startAttempt({
    required String classroomId,
    required String phaseId,
  }) async =>
      Right(attempt);

  @override
  Future<Either<Failure, AnswerOutcome>> answerQuestion({
    required String attemptId,
    required String questionId,
    Map<String, dynamic>? response,
  }) async {
    sent.add(response);
    return Right(AnswerOutcome(
      feedback: AnswerFeedback(
        questionId: questionId,
        score: 1,
        correct: true,
        timedOut: false,
        streak: 1,
        multiplier: 1,
        points: 10,
      ),
      totalPoints: 10,
    ),);
  }
}

/// O que o aluno recebe: conteúdo sem o gabarito.
Question _forStudent(Question q) => Question(
      id: q.id,
      text: q.text,
      options: q.options,
      correctAnswer: 0,
      explanation: '',
      type: q.type,
      content: q.content,
    );

void main() {
  group('montagem pelo professor', () {
    test('ligar: ida e volta, direita embaralhada', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = buildMatchQuestion(
          text: ' Ligue as capitais. ',
          pairs: _pairs,
          random: Random(seed),
        );
        expect(q.type, QuestionType.matchColumns);
        expect(q.text, 'Ligue as capitais.');
        expect(q.matchLeft, ['Brasil', 'França', 'Japão']);
        expect(q.matchPairs, _pairs);
        // Nunca na mesma ordem dos pares (entregaria a resposta).
        expect(q.matchRight, isNot(['Brasília', 'Paris', 'Tóquio']));
        expect(q.options, isEmpty);
      }
    });

    test('ordenar: ida e volta, nunca já na ordem certa', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = buildOrderingQuestion(
          text: 'Ordene os períodos.',
          orderedItems: _ordered,
          random: Random(seed),
        );
        expect(q.orderedItems, _ordered);
        expect(q.orderingItems, isNot(_ordered));
        expect(q.orderingItems.toSet(), _ordered.toSet());
      }
    });

    test('validação com as regras do banco', () {
      expect(validateMatchPairs(_pairs), isNull);
      expect(validateMatchPairs(_pairs.take(2).toList()), contains('3 a 6'));
      expect(
        validateMatchPairs([..._pairs, const MatchPair('Chile', ' paris ')]),
        contains('repetidos da coluna da direita'),
      );
      expect(
        validateMatchPairs([..._pairs, const MatchPair('', 'Lima')]),
        contains('Preencha'),
      );
      expect(validateOrderingItems(_ordered), isNull);
      expect(validateOrderingItems(['a', 'b']), contains('3 a 8'));
      expect(validateOrderingItems(['a', 'b', 'A']), contains('repetidos'));
      expect(
        validateOrderingItems(['a', 'b', 'x' * 201]),
        contains('200 caracteres'),
      );
    });

    test('lê do banco o conteúdo e o gabarito', () {
      final q = QuestionModel.fromMap(const {
        'id': 'q',
        'text': 'T',
        'type': 'match_columns',
        'options': <String>[],
        'content': {
          'left': ['a', 'b', 'c'],
          'right': ['z', 'x', 'y'],
        },
        'answer': {
          'match': [1, 2, 0],
        },
      });
      expect(q.type, QuestionType.matchColumns);
      expect(q.matchPairs, const [
        MatchPair('a', 'x'),
        MatchPair('b', 'y'),
        MatchPair('c', 'z'),
      ]);
      expect(QuestionModel.questionTypeToDb(QuestionType.ordering), 'ordering');
    });

    test('ordenar: nota por posição, igual à do servidor; verde = posição certa', () {
      // Casos do teste SQL (gabarito [1, 3, 0, 2]).
      const key = [1, 3, 0, 2];
      expect(orderingScore([1, 3, 0, 2], key), 1);
      expect(orderingScore([3, 0, 2, 1], key), 0); // tudo deslocado uma casa
      expect(orderingScore([2, 0, 3, 1], key), 0);
      expect(orderingScore([1, 0, 3, 2], key), 0.5); // 1º e 4º no lugar
      expect(orderingKeptPositions([1, 0, 3, 2], key), {0, 3});
      // Invertido: nada fica verde (nota 0).
      expect(orderingKeptPositions([2, 0, 3, 1], key), isEmpty);
      // Item no lugar vale mesmo com os vizinhos trocados.
      expect(orderingKeptPositions([0, 2, 1, 3], [0, 1, 2, 3]), {0, 3});
      expect(orderingScore([0, 2, 1, 3], [0, 1, 2, 3]), 0.5);
      // Os ciclos do teste no navegador: Ouro, Café, Pau-Brasil, Açúcar.
      expect(orderingKeptPositions([2, 3, 0, 1], [0, 1, 2, 3]), isEmpty);
      expect(orderingScore([2, 3, 0, 1], [0, 1, 2, 3]), 0);
    });

    test('tempo automático conta os itens (mesma conta do servidor)', () {
      // Teste SQL: "Ligue cada país à sua capital." + 3 pares → 35 s.
      const q = Question(
        id: 'q',
        text: 'Ligue cada país à sua capital.',
        options: [],
        correctAnswer: 0,
        explanation: '',
        type: QuestionType.matchColumns,
        content: {
          'left': ['Brasil', 'França', 'Japão'],
          'right': ['Tóquio', 'Brasília', 'Paris'],
        },
      );
      expect(autoTimeLimitOf(q, 'normal'), 35);
      expect(autoTimeLimitOf(q, 'short'), 20);
    });
  });

  group('tabuleiros do aluno', () {
    Future<void> pumpBoard(WidgetTester tester, Widget board) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: board),
              ),
            ),
          ),
        );

    testWidgets('ligar: toca na esquerda e na direita; tocar de novo solta',
        (tester) async {
      var match = <int?>[null, null, null];
      Future<void> pump() => pumpBoard(
            tester,
            MatchColumnsBoard(
              left: const ['Brasil', 'França', 'Japão'],
              right: const ['Tóquio', 'Brasília', 'Paris'],
              match: match,
              onChanged: (m) => match = m,
            ),
          );
      await pump();

      await tester.tap(find.text('Brasil'));
      await tester.pump();
      await tester.tap(find.text('Brasília'));
      await pump();
      expect(match, [1, null, null]);

      // A direita só aceita um fio: ligar França em Brasília solta Brasil.
      await tester.tap(find.text('França'));
      await tester.pump();
      await tester.tap(find.text('Brasília'));
      await pump();
      expect(match, [null, 1, null]);

      // Tocar na direita ligada (sem nada escolhido) solta o fio.
      await tester.tap(find.text('Brasília'));
      await pump();
      expect(match, [null, null, null]);
    });

    testWidgets('ligar travado não muda', (tester) async {
      await pumpBoard(
        tester,
        const MatchColumnsBoard(
          left: ['Brasil', 'França', 'Japão'],
          right: ['Tóquio', 'Brasília', 'Paris'],
          match: [1, 0, 2],
          reveal: [1, 2, 0],
        ),
      );
      await tester.tap(find.text('Brasil'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ordenar: setas movem o item', (tester) async {
      var order = [0, 1, 2];
      Future<void> pump() => pumpBoard(
            tester,
            OrderingBoard(
              items: const ['C', 'A', 'B'],
              order: order,
              onChanged: (o) => order = o,
            ),
          );
      await pump();
      await tester.tap(find.byTooltip('Descer').first);
      await pump();
      expect(order, [1, 0, 2]);
      await tester.tap(find.byTooltip('Subir').last);
      await pump();
      expect(order, [1, 2, 0]);
    });

    testWidgets('ordenar travado mostra a ordem certa', (tester) async {
      await pumpBoard(
        tester,
        const OrderingBoard(
          items: ['C', 'A', 'B'],
          order: [0, 1, 2],
          reveal: [1, 2, 0],
        ),
      );
      expect(find.text('Ordem certa:'), findsOneWidget);
      expect(find.text('1. A'), findsOneWidget);
      expect(find.byTooltip('Subir'), findsNothing);
    });
  });

  group('controlador com os tipos novos', () {
    final match = _forStudent(
      buildMatchQuestion(text: 'Ligue.', pairs: _pairs, random: Random(1))
          .withTimeLimit(null),
    );
    final ordering = _forStudent(
      buildOrderingQuestion(
        text: 'Ordene.',
        orderedItems: _ordered,
        random: Random(2),
      ),
    );
    final matchQ = Question(
      id: 'm',
      text: match.text,
      options: const [],
      correctAnswer: 0,
      explanation: '',
      type: match.type,
      content: match.content,
    );
    final blanks = buildFillBlanksQuestion(
      text: 'Complete.',
      template: 'Capital do [Brasil] é [Brasília].',
      random: Random(3),
    );
    final fillQ = Question(
      id: 'b',
      text: blanks.text,
      options: const [],
      correctAnswer: 0,
      explanation: '',
      type: blanks.type,
      content: blanks.content,
    );
    final orderQ = Question(
      id: 'o',
      text: ordering.text,
      options: const [],
      correctAnswer: 0,
      explanation: '',
      type: ordering.type,
      content: ordering.content,
    );
    const args = (classroomId: 'c', phaseId: 'f');

    test('ligar e lacunas só confirmam completos; ordenar manda a ordem',
        () async {
      final repo = _FakeRepo(PhaseAttempt(
        attemptId: 'a',
        phaseId: 'f',
        attemptNo: 1,
        firstAttempt: true,
        timerEnabled: false,
        timerLevel: 'normal',
        questions: [matchQ, orderQ, fillQ],
        nextQuestionId: 'm',
      ),);
      final container = ProviderContainer(
        overrides: [classroomRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(attemptControllerProvider(args), (_, __) {});
      await pumpEventQueue();
      AttemptViewState s() => container.read(attemptControllerProvider(args));
      final ctrl = container.read(attemptControllerProvider(args).notifier);

      expect(s().draft, {'match': [null, null, null]});
      expect(s().canConfirm, isFalse);
      ctrl.setDraft({'match': [0, 1, null]});
      expect(s().canConfirm, isFalse);
      await ctrl.confirm();
      expect(repo.sent, isEmpty);

      ctrl.setDraft({'match': [0, 1, 2]});
      expect(s().canConfirm, isTrue);
      await ctrl.confirm();
      expect(repo.sent.single, {'match': [0, 1, 2]});
      expect(s().stage, AttemptStage.feedback);

      await ctrl.next();
      expect(s().question!.id, 'o');
      expect(s().draft, {'order': [0, 1, 2, 3]});
      expect(s().canConfirm, isTrue);
      ctrl.setDraft({'order': [3, 2, 1, 0]});
      await ctrl.confirm();
      expect(repo.sent.last, {'order': [3, 2, 1, 0]});

      // Lacunas: só confirma com todas preenchidas.
      await ctrl.next();
      expect(s().question!.id, 'b');
      expect(s().draft, {'blanks': [null, null]});
      ctrl.setDraft({'blanks': [1, null]});
      expect(s().canConfirm, isFalse);
      ctrl.setDraft({'blanks': [1, 0]});
      expect(s().canConfirm, isTrue);
      await ctrl.confirm();
      expect(repo.sent.last, {'blanks': [1, 0]});
    });
  });
}
