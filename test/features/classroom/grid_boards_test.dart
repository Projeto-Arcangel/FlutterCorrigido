import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/crossword_board.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/word_search_board.dart';
import 'package:arcangel_o_oficial/features/ia_quiz/data/models/ia_question_response_model.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Cruzadinha 8×8 do teste SQL: BRASILIA (→ 0,0), BAHIA (↓ 0,0),
// SALVADOR (↓ 0,3).
const _slots = [
  CrosswordSlot(num: 1, row: 0, col: 0, across: true, len: 8, clue: 'Capital do Brasil'),
  CrosswordSlot(num: 1, row: 0, col: 0, across: false, len: 5, clue: 'Estado do Nordeste'),
  CrosswordSlot(num: 2, row: 0, col: 3, across: false, len: 8, clue: 'Capital da Bahia'),
];
const _grid = ['SOLXYZ', 'AMARZQ', 'LUAWER', 'PLKJHG', 'MNBVCX', 'QWERTY'];

Future<void> _pump(WidgetTester tester, Widget board) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 400, child: board),
          ),
        ),
      ),
    );

void main() {
  group('cruzadinha do aluno', () {
    testWidgets('escreve pela dica e a letra vai para a palavra que cruza',
        (tester) async {
      var words = ['        ', '     ', '        '];
      Future<void> pump() => _pump(
            tester,
            CrosswordBoard(
              rows: 8,
              cols: 8,
              slots: _slots,
              words: words,
              onChanged: (w) => words = w,
            ),
          );
      await pump();

      await tester.tap(find.textContaining('Capital do Brasil'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Brasília');
      await tester.tap(find.byTooltip('Escrever na grade'));
      await pump();

      expect(words[0], 'BRASILIA');
      // Cruzamentos: B em BAHIA, S em SALVADOR.
      expect(words[1], 'B    ');
      expect(words[2], 'S       ');
    });

    testWidgets('travada: letras certas, verde ou vermelho por casa',
        (tester) async {
      await _pump(
        tester,
        const CrosswordBoard(
          rows: 8,
          cols: 8,
          slots: _slots,
          words: ['BRASILIA', 'BAHIA', 'SALVADO '],
          reveal: ['BRASILIA', 'BAHIA', 'SALVADOR'],
        ),
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      expect(find.text('  SALVADOR', findRichText: true), findsNothing);
      expect(find.textContaining('SALVADOR', findRichText: true), findsOneWidget);
    });
  });

  group('caça-palavras do aluno', () {
    testWidgets('marca primeira e última letra; de trás para frente vale',
        (tester) async {
      var found = <List<int>>[];
      Future<void> pump() => _pump(
            tester,
            WordSearchBoard(
              grid: _grid,
              words: const ['SOL', 'MAR', 'LUA'],
              found: found,
              onChanged: (f) => found = f,
            ),
          );
      await pump();
      // Grade 6×6 em 400 px: casas de 34 px, centralizadas.
      final origin = tester.getTopLeft(find.byType(CustomPaint).last);
      Offset cell(int r, int c) => origin + Offset(c * 34 + 17, r * 34 + 17);

      await tester.tapAt(cell(0, 2));
      await tester.pump();
      await tester.tapAt(cell(0, 0)); // L → S: "LOS" = SOL ao contrário
      await pump();
      expect(found, [
        [0, 2, 0, 0],
      ]);

      // Marcação que não forma palavra não entra.
      await tester.tapAt(cell(3, 0));
      await tester.pump();
      await tester.tapAt(cell(3, 2));
      await pump();
      expect(found.length, 1);
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('travado: achadas riscadas, faltantes em vermelho', (tester) async {
      await _pump(
        tester,
        const WordSearchBoard(
          grid: _grid,
          words: ['SOL', 'MAR', 'LUA'],
          found: [
            [0, 0, 0, 2],
          ],
          reveal: [
            [0, 0, 0, 2],
            [1, 1, 1, 3],
            [2, 0, 2, 2],
          ],
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('IA: grade montada no app', () {
    test('cruzadinha e caça-palavras viram questões', () {
      final parsed = IaQuestionResponseModel.questionsFromResponse({
        'questions': [
          {
            'type': 'crossword',
            'text': 'Resolva.',
            'explanation': '',
            'entries': [
              {'word': 'BRASILIA', 'clue': 'Capital do Brasil'},
              {'word': 'SALVADOR', 'clue': 'Capital da Bahia'},
              {'word': 'RECIFE', 'clue': 'Capital de Pernambuco'},
              {'word': 'BELEM', 'clue': 'Capital do Pará'},
            ],
          },
          {
            'type': 'word_search',
            'text': 'Ache.',
            'explanation': '',
            'words': ['SOL', 'LUA', 'ESTRELA', 'COMETA'],
          },
        ],
      });
      expect(parsed.skipped, 0);
      expect(parsed.questions.map((q) => q.type), [QuestionType.crossword, QuestionType.wordSearch]);
      expect(parsed.questions.first.crosswordWords.toSet(), {'BRASILIA', 'SALVADOR', 'RECIFE', 'BELEM'});
      expect(parsed.questions.last.wordSearchPositions.length, 4);
    });

    test('caça-palavras que não cabe fica de fora e é contado', () {
      final parsed = IaQuestionResponseModel.questionsFromResponse({
        'questions': [
          {
            'type': 'word_search',
            'text': 'Ache.',
            'explanation': '',
            'words': ['ABCDEFGHIJKLMNOP', 'SOL', 'LUA', 'MAR'],
          },
        ],
      });
      expect(parsed.questions, isEmpty);
      expect(parsed.skipped, 1);
    });
  });
}
