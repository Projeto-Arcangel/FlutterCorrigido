import 'dart:async';

import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/core/router/app_router.dart';
import 'package:arcangel_o_oficial/features/auth/domain/entities/user.dart';
import 'package:arcangel_o_oficial/features/auth/presentation/providers/login_controller.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/entities/ia_generation_result.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/entities/ia_model_option.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/entities/study_material.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/domain/usecases/generate_questions_with_ia.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/presentation/providers/ia_quiz_providers.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/presentation/widgets/ia_generation_watcher.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Geração falsa: cada chamada só termina quando o teste libera.
class _FakeGenerate implements GenerateQuestionsWithIa {
  final calls = <Completer<Either<Failure, IaGenerationResult>>>[];

  @override
  Future<Either<Failure, IaGenerationResult>> call({
    required String topic,
    required String difficulty,
    required int quantity,
    required int alternatives,
    required String description,
    required IaModelOption model,
    String? subject,
    List<MaterialForAi>? materials,
  }) =>
      (calls..add(Completer())).last.future;
}

const _target = IaReviewTarget(
  title: 'Materiais: Fotossíntese',
  difficultyLabel: 'Médio',
  classroomId: 'turma-1',
  phaseId: 'fase-1',
  phaseTitle: 'Fase 1',
);

IaGenerationResult _result(int count) => IaGenerationResult(
      questions: [
        for (var i = 0; i < count; i++)
          Question(
            id: 'q$i',
            text: 'Pergunta $i',
            options: const ['a', 'b', 'c', 'd'],
            correctAnswer: 0,
            explanation: '',
            type: QuestionType.multipleChoice,
          ),
      ],
      modelUsed: IaModelOption.defaultOption,
      usedFallback: false,
    );

const _teacher = User(id: 'prof-1', email: 'prof@escola.br');

void main() {
  late _FakeGenerate generate;
  late StreamController<User?> auth;

  setUp(() {
    generate = _FakeGenerate();
    auth = StreamController<User?>.broadcast();
  });

  tearDown(() => auth.close());

  List<Override> overrides() => [
        generateQuestionsWithIaProvider.overrideWithValue(generate),
        authStateProvider.overrideWith((ref) => auth.stream),
      ];

  Future<void> start(IaGenerationNotifier notifier) => notifier.generate(
        topic: '',
        difficulty: 'medium',
        quantity: 2,
        alternatives: 4,
        description: '',
        model: IaModelOption.defaultOption,
        target: _target,
      );

  group('estado da geração', () {
    late ProviderContainer container;
    late IaGenerationNotifier notifier;

    setUp(() async {
      container = ProviderContainer(overrides: overrides());
      container.listen(iaGenerationNotifierProvider, (_, __) {});
      container.listen(authStateProvider, (_, __) {});
      auth.add(_teacher);
      await container.read(iaGenerationNotifierProvider.future);
      notifier = container.read(iaGenerationNotifierProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('guarda o resultado com o destino e entrega uma vez só', () async {
      final running = start(notifier);
      expect(notifier.take(), isNull, reason: 'ainda gerando');

      generate.calls.single.complete(Right(_result(2)));
      await running;

      final outcome = notifier.take()!;
      expect(outcome.result.questions, hasLength(2));
      expect(outcome.target.phaseId, 'fase-1');
      expect(outcome.reviewExtra(fromCreation: false), {
        'result': outcome.result,
        'topic': 'Materiais: Fotossíntese',
        'difficulty': 'Médio',
        'classroomId': 'turma-1',
        'phaseId': 'fase-1',
        'phaseTitle': 'Fase 1',
        'fromCreation': false,
      });
      expect(notifier.take(), isNull, reason: 'já foi entregue');
    });

    test('resultado que chega depois de sair da conta é descartado', () async {
      final running = start(notifier);
      auth.add(null);
      await pumpEventQueue();

      generate.calls.single.complete(Right(_result(2)));
      await running;

      expect(container.read(iaGenerationNotifierProvider).valueOrNull, isNull);
      expect(notifier.take(), isNull);
    });

    test('a tela de criação registra quando está aberta', () {
      expect(notifier.hasOpenScreen, isFalse);
      notifier.attachScreen();
      expect(notifier.hasOpenScreen, isTrue);
      notifier.detachScreen();
      expect(notifier.hasOpenScreen, isFalse);
    });
  });

  group('aviso em qualquer tela', () {
    late GoRouter router;

    Future<IaGenerationNotifier> pumpApp(WidgetTester tester) async {
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Turmas')),
          ),
          GoRoute(
            path: AppRoutes.teacherIaQuizReview,
            builder: (_, state) => Scaffold(
              body: Text(
                'Revisão de origem '
                '${(state.extra! as Map)['fromCreation']}',
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            appRouterProvider.overrideWithValue(router),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) => IaGenerationWatcher(child: child!),
          ),
        ),
      );
      auth.add(_teacher);
      await tester.pump();
      final container =
          ProviderScope.containerOf(tester.element(find.text('Turmas')));
      container.listen(authStateProvider, (_, __) {});
      await tester.pump();
      return container.read(iaGenerationNotifierProvider.notifier);
    }

    testWidgets('com a criação fechada, avisa e abre a revisão',
        (tester) async {
      final notifier = await pumpApp(tester);
      final running = start(notifier);
      generate.calls.single.complete(Right(_result(3)));
      await tester.pump();
      await running;
      await tester.pumpAndSettle();

      expect(
        find.text('Suas 3 questões geradas com IA estão prontas.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();

      // Aberta de outra tela: ao salvar, volta só uma tela.
      expect(find.text('Revisão de origem false'), findsOneWidget);
      expect(notifier.take(), isNull, reason: 'resultado já entregue');
    });

    testWidgets('fechar o aviso não perde as questões', (tester) async {
      final notifier = await pumpApp(tester);
      final running = start(notifier);
      generate.calls.single.complete(Right(_result(1)));
      await tester.pump();
      await running;
      await tester.pumpAndSettle();

      expect(
        find.text('Sua questão gerada com IA está pronta.'),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Revisar'), findsNothing);
      // Continua guardado: abre ao voltar para a tela de criação.
      expect(notifier.take()?.result.questions, hasLength(1));
    });

    testWidgets('aviso some quando a tela de criação entrega o resultado',
        (tester) async {
      final notifier = await pumpApp(tester);
      final running = start(notifier);
      generate.calls.single.complete(Right(_result(2)));
      await tester.pump();
      await running;
      await tester.pumpAndSettle();
      expect(find.text('Revisar'), findsOneWidget);

      // O professor voltou à tela de criação, que abre a revisão direto.
      expect(notifier.take(), isNotNull);
      await tester.pumpAndSettle();
      expect(find.text('Revisar'), findsNothing);
    });

    testWidgets('com a criação aberta, quem trata é ela (sem aviso)',
        (tester) async {
      final notifier = await pumpApp(tester);
      notifier.attachScreen();
      final running = start(notifier);
      generate.calls.single.complete(Right(_result(2)));
      await tester.pump();
      await running;
      await tester.pumpAndSettle();

      expect(find.text('Revisar'), findsNothing);
      expect(notifier.take(), isNotNull);
    });

    testWidgets('erro com a criação fechada aparece no aviso', (tester) async {
      final notifier = await pumpApp(tester);
      final running = start(notifier);
      generate.calls.single.complete(
        const Left(ValidationFailure('Limite diário de IA atingido.')),
      );
      await tester.pump();
      await running;
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não consegui gerar as questões. Limite diário de IA atingido.',
        ),
        findsOneWidget,
      );
      // Erro mostrado: o estado volta ao início.
      expect(
        ProviderScope.containerOf(tester.element(find.text('Turmas')))
            .read(iaGenerationNotifierProvider)
            .hasError,
        isFalse,
      );
      // O aviso de erro some sozinho.
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não consegui gerar'), findsNothing);
    });
  });
}
