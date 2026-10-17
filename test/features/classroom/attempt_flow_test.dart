import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/auth/presentation/providers/login_controller.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/classroom.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/classroom_phase.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_attempt.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/repositories/classroom_repository.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/pages/classroom_lesson_page.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/attempt_controller.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/classroom_providers.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Servidor de mentira: devolve, em ordem, o que o teste enfileirar e
/// guarda o que o app mandou.
class _FakeRepo extends Mock implements ClassroomRepository {
  final starts = <Either<Failure, PhaseAttempt>>[];
  final opens = <Either<Failure, OpenedQuestion>>[];
  final answers = <Either<Failure, AnswerOutcome>>[];
  final sent = <({String questionId, Map<String, dynamic>? response})>[];
  final opened = <String>[];

  @override
  Future<Either<Failure, PhaseAttempt>> startAttempt({
    required String classroomId,
    required String phaseId,
  }) async =>
      starts.removeAt(0);

  @override
  Future<Either<Failure, OpenedQuestion>> openQuestion({
    required String attemptId,
    required String questionId,
  }) async {
    opened.add(questionId);
    return opens.removeAt(0);
  }

  @override
  Future<Either<Failure, AnswerOutcome>> answerQuestion({
    required String attemptId,
    required String questionId,
    Map<String, dynamic>? response,
  }) async {
    sent.add((questionId: questionId, response: response));
    return answers.removeAt(0);
  }
}

const _questions = [
  Question(
    id: 'q1',
    text: 'Qual é a capital da França?',
    options: ['Roma', 'Paris', 'Lima'],
    correctAnswer: 0, // o aluno nunca recebe o gabarito
    explanation: '',
    type: QuestionType.multipleChoice,
  ),
  Question(
    id: 'q2',
    text: 'Quanto é 2 + 2?',
    options: ['3', '5', '4'],
    correctAnswer: 0,
    explanation: '',
    type: QuestionType.multipleChoice,
  ),
];

PhaseAttempt _attempt({
  bool timer = false,
  List<AnswerFeedback> answers = const [],
  String? next = 'q1',
  AttemptResult? result,
  int points = 0,
  int streak = 0,
}) =>
    PhaseAttempt(
      attemptId: 'a1',
      phaseId: 'f1',
      attemptNo: 1,
      firstAttempt: true,
      timerEnabled: timer,
      timerLevel: 'short',
      questions: _questions,
      timeLimits: timer ? const {'q1': 15, 'q2': 15} : const {},
      answers: answers,
      points: points,
      streak: streak,
      nextQuestionId: next,
      result: result,
    );

AnswerFeedback _fb(
  String q, {
  bool correct = true,
  bool timedOut = false,
  int points = 10,
  int streak = 1,
  required int right,
}) =>
    AnswerFeedback(
      questionId: q,
      score: correct ? 1 : 0,
      correct: correct,
      timedOut: timedOut,
      streak: streak,
      multiplier: 1,
      points: points,
      reveal: {'correct_answer': right},
    );

const _result = AttemptResult(
  attemptId: 'a1',
  attemptNo: 1,
  firstAttempt: true,
  total: 2,
  score: 1,
  pct: 50,
  stars: 0,
  points: 10,
  bestStreak: 1,
  xp: 7,
  gold: 0,
  officialTotal: 2,
  officialCorrect: 1,
  officialPct: 50,
  bestPct: 50,
  bestStars: 0,
  review: [
    AttemptReviewItem(
      questionId: 'q1',
      score: 1,
      correct: true,
      answered: true,
      timedOut: false,
      response: {'choice': 1},
      reveal: {'correct_answer': 1},
      explanation: 'Paris é a capital desde o século X.',
    ),
    AttemptReviewItem(
      questionId: 'q2',
      score: 0,
      correct: false,
      answered: true,
      timedOut: false,
      response: {'choice': 0},
      reveal: {'correct_answer': 2},
      explanation: 'Dois mais dois são quatro.',
    ),
  ],
);

const _args = (classroomId: 'c1', phaseId: 'f1');

void main() {
  group('controlador da tentativa', () {
    late _FakeRepo repo;
    late ProviderContainer container;

    AttemptViewState state() => container.read(attemptControllerProvider(_args));
    AttemptController ctrl() =>
        container.read(attemptControllerProvider(_args).notifier);

    Future<void> open() async {
      container.listen(attemptControllerProvider(_args), (_, __) {});
      await pumpEventQueue();
    }

    setUp(() {
      repo = _FakeRepo();
      container = ProviderContainer(
        overrides: [classroomRepositoryProvider.overrideWithValue(repo)],
      );
    });
    tearDown(() => container.dispose());

    test('responde, vê a correção na hora, avança e termina', () async {
      repo
        ..starts.add(Right(_attempt()))
        ..answers.add(Right(AnswerOutcome(
          feedback: _fb('q1', right: 1),
          totalPoints: 10,
        ),),)
        ..answers.add(const Right(AnswerOutcome(
          feedback: AnswerFeedback(
            questionId: 'q2',
            score: 0,
            correct: false,
            timedOut: false,
            streak: 0,
            multiplier: 1,
            points: 0,
            reveal: {'correct_answer': 2},
          ),
          totalPoints: 10,
          result: _result,
        ),),);
      await open();

      expect(state().stage, AttemptStage.playing);
      expect(state().question!.id, 'q1');

      await ctrl().confirm(); // nada marcado: não envia
      expect(repo.sent, isEmpty);

      ctrl().select(1);
      await ctrl().confirm();
      expect(repo.sent.single.questionId, 'q1');
      expect(repo.sent.single.response, {'choice': 1});
      expect(state().stage, AttemptStage.feedback);
      expect(state().feedback!.correct, isTrue);
      expect(state().points, 10);
      expect(state().streak, 1);

      ctrl().select(0); // resposta travada
      expect(state().selected, 1);

      await ctrl().next();
      expect(state().stage, AttemptStage.playing);
      expect(state().index, 1);
      expect(state().selected, isNull);

      ctrl().select(0);
      await ctrl().confirm();
      expect(state().stage, AttemptStage.feedback);
      expect(state().streak, 0);
      expect(state().result, _result);

      await ctrl().next();
      expect(state().stage, AttemptStage.finished);
    });

    test('retoma de onde parou', () async {
      repo.starts.add(Right(_attempt(
        answers: [_fb('q1', right: 1)],
        next: 'q2',
        points: 10,
        streak: 1,
      ),),);
      await open();

      expect(state().stage, AttemptStage.playing);
      expect(state().index, 1);
      expect(state().answers.keys, ['q1']);
      expect(state().points, 10);
      expect(state().streak, 1);
    });

    test('tentativa já entregue abre direto no resultado', () async {
      repo.starts.add(Right(_attempt(next: null, result: _result)));
      await open();
      expect(state().stage, AttemptStage.finished);
      expect(state().result, _result);
    });

    test('falha de rede: repetir manda a mesma resposta', () async {
      repo
        ..starts.add(Right(_attempt()))
        ..answers.add(const Left(NetworkFailure('Sem conexão.')))
        ..answers.add(Right(AnswerOutcome(
          feedback: _fb('q1', right: 1),
          totalPoints: 10,
        ),),);
      await open();
      ctrl().select(1);
      await ctrl().confirm();
      expect(state().stage, AttemptStage.error);
      expect(state().errorIsFinal, isFalse);

      await ctrl().retry();
      expect(state().stage, AttemptStage.feedback);
      expect(repo.sent.map((s) => s.response), [
        {'choice': 1},
        {'choice': 1},
      ]);
    });

    test('fase fechou no meio: recusa final, sem repetir', () async {
      repo
        ..starts.add(Right(_attempt()))
        ..answers.add(const Left(
          ValidationFailure('Esta fase já fechou e não aceita mais respostas.'),
        ),);
      await open();
      ctrl().select(1);
      await ctrl().confirm();
      expect(state().stage, AttemptStage.error);
      expect(state().errorIsFinal, isTrue);
      expect(state().error, 'Esta fase já fechou e não aceita mais respostas.');
    });

    test('voltou depois do tempo na última: mostra e o servidor entrega',
        () async {
      repo
        ..starts.add(Right(_attempt(
          timer: true,
          answers: [_fb('q1', right: 1)],
          next: 'q2',
        ),),)
        ..opens.add(Right(OpenedQuestion(
          questionId: 'q2',
          limitS: 15,
          elapsedS: 15,
          expired: _fb('q2', correct: false, timedOut: true, points: 0, streak: 0, right: 2),
        ),),)
        ..starts.add(Right(_attempt(timer: true, next: null, result: _result)));
      await open();

      expect(repo.opened, ['q2']);
      expect(state().stage, AttemptStage.feedback);
      expect(state().feedback!.timedOut, isTrue);

      await ctrl().next();
      expect(state().stage, AttemptStage.finished);
    });
  });

  group('tela da fase', () {
    final classroom = Classroom(
      id: 'c1',
      code: 'ABC123',
      name: 'Turma',
      description: '',
      teacherId: 't1',
      teacherName: 'Prof',
      studentIds: const ['s1'],
      createdAt: DateTime(2026),
      isActive: true,
      questions: const [],
    );
    final phase = ClassroomPhase(
      id: 'f1',
      classroomId: 'c1',
      title: 'Fase 1',
      description: '',
      order: 1,
      createdAt: DateTime(2026),
      questions: _questions,
    );

    Future<_FakeRepo> pump(
      WidgetTester tester,
      void Function(_FakeRepo) script, {
      DateTime Function()? clock,
    }) async {
      final repo = _FakeRepo();
      script(repo);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classroomRepositoryProvider.overrideWithValue(repo),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            if (clock != null) attemptClockProvider.overrideWithValue(clock),
          ],
          child: MaterialApp(
            home: ClassroomLessonPage(classroom: classroom, phase: phase),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return repo;
    }

    testWidgets('acerto e erro na hora; no fim, estrelas e explicação',
        (tester) async {
      await pump(tester, (repo) {
        repo
          ..starts.add(Right(_attempt()))
          ..answers.add(Right(AnswerOutcome(
            feedback: _fb('q1', right: 1),
            totalPoints: 10,
          ),),)
          ..answers.add(Right(AnswerOutcome(
            feedback: _fb('q2', correct: false, points: 0, streak: 0, right: 2),
            totalPoints: 10,
            result: _result,
          ),),);
      });

      expect(find.text('Pergunta 1 de 2'), findsOneWidget);
      expect(find.text('Qual é a capital da França?'), findsOneWidget);

      await tester.tap(find.text('Paris'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Acertou! +10 pontos'), findsOneWidget);
      expect(find.text('Sequência 1'), findsOneWidget);
      expect(find.text('10 pts'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump();
      expect(find.text('Pergunta 2 de 2'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Não foi dessa vez'), findsOneWidget);
      expect(find.text('Dois mais dois são quatro.'), findsNothing);

      await tester.tap(find.text('Ver resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Quase lá!'), findsOneWidget);
      expect(find.text('Você acertou 1 de 2.'), findsOneWidget);
      expect(find.text('+7 XP'), findsOneWidget);
      expect(find.bySemanticsLabel('0 de 3 estrelas'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Dois mais dois são quatro.'), 200);
      expect(find.text('Dois mais dois são quatro.'), findsOneWidget);
    });

    testWidgets('relógio: quando o tempo acaba, manda sem resposta',
        (tester) async {
      var now = DateTime(2026, 10, 16, 10);
      final repo = await pump(
        tester,
        (repo) {
          repo
            ..starts.add(Right(_attempt(timer: true)))
            ..opens.add(const Right(OpenedQuestion(questionId: 'q1', limitS: 15)))
            ..answers.add(Right(AnswerOutcome(
              feedback: _fb('q1', correct: false, timedOut: true, points: 0, streak: 0, right: 1),
              totalPoints: 0,
            ),),);
        },
        clock: () => now,
      );
      await tester.pump();

      expect(repo.opened, ['q1']);
      expect(find.text('15 s'), findsOneWidget);

      await tester.tap(find.text('Roma')); // marcou e não confirmou
      now = now.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      expect(repo.sent.single, (questionId: 'q1', response: null));
      expect(find.text('Tempo esgotado'), findsOneWidget);
      expect(find.text('0 s'), findsOneWidget); // relógio parado no lugar
    });

    testWidgets('fase que fechou: diz por que e não oferece repetir',
        (tester) async {
      await pump(tester, (repo) {
        repo.starts.add(const Left(
          ValidationFailure('Esta fase já fechou e não aceita mais respostas.'),
        ),);
      });
      expect(
        find.text('Esta fase já fechou e não aceita mais respostas.'),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsNothing);
      expect(find.text('Voltar à turma'), findsOneWidget);
    });

    testWidgets('resultado mostra as conquistas liberadas na entrega',
        (tester) async {
      const result = AttemptResult(
        attemptId: 'a1',
        attemptNo: 1,
        firstAttempt: true,
        total: 2,
        score: 2,
        pct: 100,
        stars: 3,
        points: 20,
        bestStreak: 2,
        xp: 9,
        gold: 15,
        officialTotal: 2,
        officialCorrect: 2,
        officialPct: 100,
        bestPct: 100,
        bestStars: 3,
        achievements: [
          UnlockedAchievement(id: 'three_stars', title: 'Três estrelas', gold: 10),
        ],
      );
      await pump(tester, (repo) {
        repo.starts.add(Right(_attempt(next: null, result: result)));
      });
      await tester.pumpAndSettle();
      expect(find.text('Perfeito!'), findsOneWidget);
      expect(find.text('Conquista liberada!'), findsOneWidget);
      expect(find.text('Três estrelas'), findsOneWidget);
      expect(find.text('+10'), findsOneWidget);
      // As moedas da conquista não se misturam com as das estrelas.
      expect(find.text('+9 XP  •  +15 moedas'), findsOneWidget);
    });
  });
}
