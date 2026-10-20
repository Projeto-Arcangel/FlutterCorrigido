import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_attempt.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/repositories/classroom_repository.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/attempt_controller.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/providers/classroom_providers.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/crossword_board.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/word_search_board.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/kind_editors.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Caça-palavras 6×6 do teste SQL: SOL (→ 0,0), MAR (→ 1,1), LUA (→ 2,0).
const _grid = ['SOLXYZ', 'AMARZQ', 'LUAWER', 'PLKJHG', 'MNBVCX', 'QWERTY'];

// Cruzadinha 8×8: BRASILIA (→ 0,0), BAHIA (↓ 0,0), SALVADOR (↓ 0,3).
const _slots = [
  CrosswordSlot(num: 1, row: 0, col: 0, across: true, len: 8, clue: 'Capital do Brasil'),
  CrosswordSlot(num: 1, row: 0, col: 0, across: false, len: 5, clue: 'Estado do Nordeste'),
  CrosswordSlot(num: 2, row: 0, col: 3, across: false, len: 8, clue: 'Capital da Bahia'),
];

Future<void> _pump(WidgetTester tester, Widget board) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: board),
          ),
        ),
      ),
    );

/// Centro da casa (r, c) da grade 6×6 (casas de 34 px em 400 px).
Offset Function(int, int) _cells(WidgetTester tester) {
  final origin = tester.getTopLeft(find.byType(CustomPaint).last);
  return (r, c) => origin + Offset(c * 34 + 17, r * 34 + 17);
}

Future<void> _mark(WidgetTester tester, Offset a, Offset b) async {
  await tester.tapAt(a);
  await tester.pump();
  await tester.tapAt(b);
  await tester.pump();
}

class _FakeRepo extends Mock implements ClassroomRepository {
  final checks = <Either<Failure, PartCheck>>[];
  final parts = <Map<String, dynamic>>[];

  @override
  Future<Either<Failure, PhaseAttempt>> startAttempt({
    required String classroomId,
    required String phaseId,
  }) async =>
      Right(
        PhaseAttempt(
          attemptId: 'a1',
          phaseId: 'f1',
          attemptNo: 1,
          firstAttempt: true,
          timerEnabled: false,
          timerLevel: 'normal',
          questions: [
            buildCrosswordQuestion(
              id: 'q1',
              text: 'Cruzadinha',
              entries: const [
                CrosswordEntry('Brasilia', 'Capital do Brasil'),
                CrosswordEntry('Bahia', 'Estado'),
                CrosswordEntry('Salvador', 'Capital da Bahia'),
                CrosswordEntry('Belem', 'Capital do Pará'),
              ],
              instant: true,
            )!,
          ],
          nextQuestionId: 'q1',
        ),
      );

  @override
  Future<Either<Failure, PartCheck>> checkAnswerPart({
    required String attemptId,
    required String questionId,
    required Map<String, dynamic> part,
  }) async {
    parts.add(part);
    return checks.removeAt(0);
  }
}

void main() {
  group('opções gravadas na questão', () {
    test('acertos na hora: padrão de cada tipo e o que o professor escolhe', () {
      const words = ['Sol', 'Mar', 'Lua', 'Céu'];
      final ws = buildWordSearchQuestion(text: 'Ache', words: words)!;
      expect(ws.gridInstant, isTrue);
      expect(ws.content!['instant'], isTrue);
      expect(ws.content!.containsKey('hidden'), isFalse);

      final hidden = buildWordSearchQuestion(
        text: 'Ache',
        words: words,
        instant: false,
        hidden: {3, 1},
      )!;
      expect(hidden.gridInstant, isFalse);
      expect(hidden.content!['hidden'], [1, 3]);
      expect(hidden.wordSearchHidden, {1, 3});

      const entries = [
        CrosswordEntry('Brasilia', 'a'),
        CrosswordEntry('Bahia', 'b'),
        CrosswordEntry('Salvador', 'c'),
        CrosswordEntry('Belem', 'd'),
      ];
      expect(buildCrosswordQuestion(text: 'x', entries: entries)!.gridInstant, isFalse);
      expect(
        buildCrosswordQuestion(text: 'x', entries: entries, instant: true)!.gridInstant,
        isTrue,
      );
    });

    test('questões antigas, sem a opção, continuam como eram', () {
      const old = Question(
        id: 'q',
        text: 't',
        options: [],
        correctAnswer: 0,
        explanation: '',
        type: QuestionType.wordSearch,
        content: <String, dynamic>{
          'words': <String>['SOL', '', 'LUA'],
          'lens': <int>[3, 3, 3],
        },
      );
      expect(old.gridInstant, isTrue);
      expect(old.wordSearchLens, [3, 3, 3]);
      const oldCw = Question(
        id: 'q',
        text: 't',
        options: [],
        correctAnswer: 0,
        explanation: '',
        type: QuestionType.crossword,
        content: <String, dynamic>{'entries': <Object>[]},
      );
      expect(oldCw.gridInstant, isFalse);
    });
  });

  group('caça-palavras do aluno', () {
    testWidgets('acertos só no fim: qualquer linha, uma por palavra, e desfaz',
        (tester) async {
      var found = <List<int>>[];
      Future<void> pump() => _pump(
            tester,
            WordSearchBoard(
              grid: _grid,
              words: const ['SOL', 'MAR', 'LUA'],
              instant: false,
              found: found,
              onChanged: (f) => found = f,
            ),
          );
      await pump();
      final cell = _cells(tester);

      await _mark(tester, cell(3, 0), cell(3, 2)); // PLK: não é palavra, entra
      await pump();
      await _mark(tester, cell(0, 0), cell(0, 2)); // SOL
      await pump();
      expect(found, [
        [3, 0, 3, 2],
        [0, 0, 0, 2],
      ]);
      // A lista não entrega o acerto enquanto joga.
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Suas marcações: 2 de 3'), findsOneWidget);

      // Marcar a mesma linha (ao contrário) desfaz.
      await _mark(tester, cell(3, 2), cell(3, 0));
      await pump();
      expect(found, [
        [0, 0, 0, 2],
      ]);

      await _mark(tester, cell(4, 0), cell(4, 2));
      await pump();
      await _mark(tester, cell(5, 0), cell(5, 2));
      await pump();
      expect(found.length, 3);
      // A 4ª é recusada, com o motivo.
      await _mark(tester, cell(2, 0), cell(2, 2));
      await pump();
      expect(found.length, 3);
      expect(find.textContaining('Você já marcou 3'), findsOneWidget);

      // O x do chip também desfaz.
      await tester.tap(find.byTooltip('Desfazer esta marcação').first);
      await pump();
      expect(found.length, 2);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('palavra oculta: aparece _ _ _ e é conferida no servidor',
        (tester) async {
      var found = <List<int>>[];
      var known = <int, String>{};
      final checked = <List<int>>[];
      Future<void> pump() => _pump(
            tester,
            WordSearchBoard(
              grid: _grid,
              words: const ['SOL', '', 'LUA'],
              lens: const [3, 3, 3],
              found: found,
              known: known,
              onChanged: (f) => found = f,
              onCheck: (sel) async {
                checked.add(sel);
                // O servidor acha MAR: o controlador grava marcação e palavra.
                if (sel[0] == 1) {
                  found = [...found, sel];
                  known = {...known, 1: 'MAR'};
                  return true;
                }
                return false;
              },
            ),
          );
      await pump();
      expect(find.text('_ _ _'), findsOneWidget);
      expect(find.text('MAR'), findsNothing);
      final cell = _cells(tester);

      await _mark(tester, cell(3, 0), cell(3, 2)); // PLK: confere e não acha
      await pump();
      expect(checked.length, 1);
      expect(found, isEmpty);

      await _mark(tester, cell(1, 3), cell(1, 1)); // RAM = MAR ao contrário
      await pump();
      expect(checked.length, 2);
      expect(found, [
        [1, 3, 1, 1],
      ]);
      expect(find.text('MAR'), findsOneWidget);
      expect(find.text('_ _ _'), findsNothing);

      // Palavra visível não vai ao servidor.
      await _mark(tester, cell(0, 0), cell(0, 2));
      await pump();
      expect(checked.length, 2);
      expect(found.length, 2);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('travado: a oculta aparece pelo gabarito', (tester) async {
      await _pump(
        tester,
        const WordSearchBoard(
          grid: _grid,
          words: ['SOL', '', 'LUA'],
          lens: [3, 3, 3],
          instant: false,
          found: [
            [1, 1, 1, 3],
          ],
          reveal: [
            [0, 0, 0, 2],
            [1, 1, 1, 3],
            [2, 0, 2, 2],
          ],
          revealWords: ['SOL', 'MAR', 'LUA'],
        ),
      );
      expect(find.text('MAR'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('_ _ _'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('cruzadinha do aluno com acertos na hora', () {
    testWidgets('errada fica marcada; certa trava e não deixa trocar a letra',
        (tester) async {
      var words = ['        ', '     ', '        '];
      var confirmed = <int>{};
      final checks = <(int, String)>[];
      Future<void> pump() => _pump(
            tester,
            CrosswordBoard(
              rows: 8,
              cols: 8,
              slots: _slots,
              words: words,
              confirmed: confirmed,
              onChanged: (w) => words = w,
              onCheck: (slot, word) async {
                checks.add((slot, word));
                final ok = word == 'BRASILIA';
                if (ok) confirmed = {...confirmed, slot};
                return ok;
              },
            ),
          );
      await pump();

      await tester.tap(find.textContaining('Capital do Brasil'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Brasilha');
      await tester.tap(find.byTooltip('Escrever na grade'));
      await tester.pump();
      await pump();
      expect(checks.last, (0, 'BRASILHA'));
      expect(find.bySemanticsLabel(RegExp('errada')), findsOneWidget);

      await tester.tap(find.textContaining('Capital do Brasil'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Brasília');
      await tester.tap(find.byTooltip('Escrever na grade'));
      await tester.pump();
      await pump();
      expect(checks.last, (0, 'BRASILIA'));
      expect(confirmed, {0});
      expect(find.bySemanticsLabel(RegExp('certa')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('errada')), findsNothing);

      // Palavra incompleta não é conferida; letra travada não muda.
      await tester.tap(find.textContaining('Estado do Nordeste'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Xahia');
      await tester.tap(find.byTooltip('Escrever na grade'));
      await tester.pump();
      expect(find.textContaining('A 1ª letra é B'), findsOneWidget);
      expect(words[1], 'B    '); // só o B que vem de BRASILIA
      expect(checks.length, 2);
    });
  });

  group('controlador', () {
    late _FakeRepo repo;
    late ProviderContainer container;
    const args = (classroomId: 'c1', phaseId: 'f1');

    setUp(() async {
      repo = _FakeRepo();
      container = ProviderContainer(
        overrides: [classroomRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(attemptControllerProvider(args), (_, __) {});
      await pumpEventQueue();
    });
    tearDown(() => container.dispose());

    AttemptController ctrl() => container.read(attemptControllerProvider(args).notifier);
    AttemptViewState state() => container.read(attemptControllerProvider(args));

    test('palavra certa da cruzadinha entra em "ok"; erro vira mensagem', () async {
      repo.checks
        ..add(const Right(PartCheck(index: 2, correct: true)))
        ..add(const Right(PartCheck(index: 1)))
        ..add(const Left(ValidationFailure('Você já conferiu muitas vezes nesta questão.')));
      ctrl().patchDraft({'words': ['        ', '     ', 'SALVADOR', '     ']});

      final a = await ctrl().checkCrosswordWord(2, 'SALVADOR');
      expect(a, (correct: true, error: null));
      expect(repo.parts.first, {'index': 2, 'word': 'SALVADOR'});
      expect(state().draft!['ok'], [2]);
      expect(state().draft!['words'], ['        ', '     ', 'SALVADOR', '     ']);

      final b = await ctrl().checkCrosswordWord(1, 'BAHIO');
      expect(b, (correct: false, error: null));
      expect(state().draft!['ok'], [2]);

      final c = await ctrl().checkCrosswordWord(1, 'BAHIA');
      expect(c.correct, isNull);
      expect(c.error, contains('muitas vezes'));
    });

    test('caça-palavras: a oculta achada entra em found e known', () async {
      repo.checks
        ..add(const Right(PartCheck(index: 1, word: 'MAR')))
        ..add(const Right(PartCheck()));
      ctrl().setDraft({'found': <List<int>>[]});

      final a = await ctrl().checkWordSearchMark([1, 3, 1, 1]);
      expect(a, (found: true, error: null));
      expect(repo.parts.first, {
        'sel': [1, 3, 1, 1],
      });
      expect(state().draft!['found'], [
        [1, 3, 1, 1],
      ]);
      expect(state().draft!['known'], {'1': 'MAR'});

      final b = await ctrl().checkWordSearchMark([3, 0, 3, 2]);
      expect(b.found, isFalse);
      expect((state().draft!['found'] as List).length, 1);
    });
  });

  group('editor do professor', () {
    testWidgets('caça-palavras: olho oculta a palavra e o interruptor muda',
        (tester) async {
      final draft = WordSearchDraft(words: ['Sol', 'Mar', 'Lua', 'Céu']);
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (_, setState) => WordSearchEditor(
                  draft: draft,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(draft.instant, isTrue);
      expect(find.text('Mostrar cada acerto na hora'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar para o aluno').at(1));
      await tester.pump();
      expect(draft.hidden, {1});
      expect(find.byTooltip('Mostrar para o aluno'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(draft.instant, isFalse);
      expect(find.textContaining('só vê o que acertou depois'), findsOneWidget);

      // Remover uma palavra antes da oculta mantém a oculta certa.
      draft.add();
      await tester.pump();
      draft.removeAt(0);
      expect(draft.hidden, {0});
      expect(draft.words.first, 'Mar');
    });

    test('cruzadinha começa com os acertos só no fim', () {
      final draft = CrosswordDraft();
      addTearDown(draft.dispose);
      expect(draft.instant, isFalse);
    });
  });
}
