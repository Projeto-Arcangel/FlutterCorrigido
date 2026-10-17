import 'dart:math';

import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/fill_blanks_board.dart';
import 'package:arcangel_o_oficial/features/lesson/data/models/question_model.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/question_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _template = 'O Brasil foi descoberto em [1500] por [Cabral].';

void main() {
  group('texto do professor', () {
    test('separa trechos e respostas', () {
      final parsed = parseBlankTemplate(_template)!;
      expect(parsed.parts, ['O Brasil foi descoberto em ', ' por ', '.']);
      expect(parsed.answers, ['1500', 'Cabral']);
      expect(parseBlankTemplate('[Brasília] é a capital.')!.parts, ['', ' é a capital.']);
      expect(parseBlankTemplate('Falta fechar [isto.'), isNull);
      expect(parseBlankTemplate('Sobrou ] aqui [x].'), isNull);
    });

    test('validação com as regras do banco', () {
      expect(validateFillBlanks(_template, ['1822']), isNull);
      expect(validateFillBlanks('Sem lacuna.', []), contains('colchetes'));
      expect(validateFillBlanks('Falta [fechar.', []), contains('Feche'));
      expect(validateFillBlanks('Vazio [ ].', []), contains('vazios'));
      expect(
        validateFillBlanks(List.generate(9, (i) => '[w$i]').join(' '), []),
        contains('no máximo 8'),
      );
      expect(validateFillBlanks(_template, ['cabral']), contains('também é resposta'));
      expect(
        validateFillBlanks(_template, List.generate(7, (i) => 'x$i')),
        contains('no máximo 6'),
      );
    });

    test('monta embaralhado e volta ao texto do professor', () {
      for (var seed = 0; seed < 30; seed++) {
        final q = buildFillBlanksQuestion(
          text: 'Complete a frase.',
          template: _template,
          distractors: const ['1822', 'Vasco da Gama'],
          random: Random(seed),
        );
        expect(q.type, QuestionType.fillBlanks);
        expect(q.blankParts, ['O Brasil foi descoberto em ', ' por ', '.']);
        expect(q.blankAnswers, ['1500', 'Cabral']);
        expect(q.blankTemplate, _template);
        expect(q.blankDistractors.toSet(), {'1822', 'Vasco da Gama'});
        expect(q.blankBank.length, 4);
        expect(q.blankBank, isNot(['1500', 'Cabral', '1822', 'Vasco da Gama']));
        expect(q.interactions, 2);
      }
    });

    test('lê do banco e calcula o tempo como o servidor', () {
      final q = QuestionModel.fromMap(const {
        'id': 'q',
        'text': 'Complete a frase.',
        'type': 'fill_blanks',
        'options': <String>[],
        'content': {
          'parts': ['O Brasil foi descoberto em ', ' por ', '.'],
          'bank': ['Cabral', '1822', '1500', 'Vasco da Gama'],
        },
        'answer': {
          'blanks': [2, 0],
        },
      });
      expect(q.type, QuestionType.fillBlanks);
      expect(q.blankAnswers, ['1500', 'Cabral']);
      // Teste SQL: 30 s normal, 20 s curto.
      expect(autoTimeLimitOf(q, 'normal'), 30);
      expect(autoTimeLimitOf(q, 'short'), 20);
    });
  });

  group('tabuleiro do aluno', () {
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

    testWidgets('palavras vão para as lacunas em ordem; tocar tira',
        (tester) async {
      var blanks = <int?>[null, null];
      Future<void> pump() => pumpBoard(
            tester,
            FillBlanksBoard(
              parts: const ['O Brasil foi descoberto em ', ' por ', '.'],
              bank: const ['Cabral', '1822', '1500', 'Vasco da Gama'],
              blanks: blanks,
              onChanged: (b) => blanks = b,
            ),
          );
      await pump();

      await tester.tap(find.text('1500'));
      await pump();
      expect(blanks, [2, null]);
      await tester.tap(find.text('Cabral'));
      await pump();
      expect(blanks, [2, 0]);

      // Tocar na lacuna preenchida devolve a palavra.
      await tester.tap(find.text('1500').first);
      await pump();
      expect(blanks, [null, 0]);
      await tester.tap(find.text('1822'));
      await pump();
      expect(blanks, [1, 0]);
    });

    testWidgets('travado mostra a palavra certa ao lado da errada',
        (tester) async {
      await pumpBoard(
        tester,
        const FillBlanksBoard(
          parts: ['O Brasil foi descoberto em ', ' por ', '.'],
          bank: ['Cabral', '1822', '1500', 'Vasco da Gama'],
          blanks: [1, 0],
          reveal: [2, 0],
        ),
      );
      expect(find.text('1822'), findsOneWidget); // a escolhida, riscada
      expect(find.text('1500'), findsOneWidget); // a certa, ao lado
      expect(find.text('Vasco da Gama'), findsNothing); // banco some
    });
  });

  group('ficha da questão', () {
    final question = buildFillBlanksQuestion(
      id: 'q7',
      text: 'Complete a frase.',
      template: _template,
      distractors: const ['1822'],
    ).withTimeLimit(60);

    testWidgets('mostra e edita o texto com lacunas', (tester) async {
      final popped = <Question?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => popped.add(
                  await showModalBottomSheet<Question>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        QuestionDetailSheet(question: question, order: 1),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Completar lacunas · respostas em verde'), findsOneWidget);
      expect(find.text('Palavras extras: 1822'), findsOneWidget);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('2 lacunas'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, _template),
        'O Brasil foi descoberto em [1500].',
      );
      await tester.pump();
      expect(find.text('1 lacuna'), findsOneWidget);
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final saved = popped.single!;
      expect(saved.id, 'q7');
      expect(saved.timeLimitS, 60);
      expect(saved.blankTemplate, 'O Brasil foi descoberto em [1500].');
      expect(saved.blankDistractors, ['1822']);
    });
  });
}
