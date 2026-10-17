import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/kind_editors.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/question_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, Widget editor) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: editor)),
        ),
      );

  testWidgets('pares: começa com 3, preenche, adiciona e remove',
      (tester) async {
    final draft = MatchPairsDraft();
    addTearDown(draft.dispose);
    Future<void> pump() => pumpEditor(
          tester,
          StatefulBuilder(
            builder: (_, setState) => MatchPairsEditor(
              draft: draft,
              onChanged: () => setState(() {}),
            ),
          ),
        );
    await pump();

    expect(draft.length, 3);
    expect(draft.problem, contains('Preencha'));
    final fields = find.byType(TextField);
    const texts = ['Brasil', 'Brasília', 'França', 'Paris', 'Japão', 'Tóquio'];
    for (var i = 0; i < texts.length; i++) {
      await tester.enterText(fields.at(i), texts[i]);
    }
    await tester.pump();
    expect(draft.problem, isNull);
    expect(draft.pairs.last, const MatchPair('Japão', 'Tóquio'));

    // Com 3 pares não remove; depois de adicionar, remove.
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close_rounded).first).onPressed,
      isNull,
    );
    await tester.tap(find.text('Adicionar par'));
    await tester.pump();
    expect(draft.length, 4);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.close_rounded).last);
    await tester.pump();
    expect(draft.length, 3);
  });

  testWidgets('itens: escritos na ordem certa e reordenáveis', (tester) async {
    final draft = OrderingDraft(['B', 'A', 'C']);
    addTearDown(draft.dispose);
    await pumpEditor(
      tester,
      StatefulBuilder(
        builder: (_, setState) => OrderingItemsEditor(
          draft: draft,
          onChanged: () => setState(() {}),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Descer').first);
    await tester.pump();
    expect(draft.items, ['A', 'B', 'C']);
    expect(draft.problem, isNull);
  });

  group('ficha da questão de ligar colunas', () {
    final question = buildMatchQuestion(
      id: 'q9',
      text: 'Ligue cada país à capital.',
      pairs: const [
        MatchPair('Brasil', 'Brasília'),
        MatchPair('França', 'Paris'),
        MatchPair('Japão', 'Tóquio'),
      ],
      explanation: 'Capitais.',
    ).withTimeLimit(45);

    Future<List<Question?>> open(WidgetTester tester, {bool editing = false}) async {
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
                    builder: (_) => QuestionDetailSheet(
                      question: question,
                      order: 2,
                      initiallyEditing: editing,
                    ),
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
      return popped;
    }

    testWidgets('mostra os pares certos', (tester) async {
      await open(tester);
      expect(find.text('Ligar colunas · pares certos'), findsOneWidget);
      expect(find.text('Brasil'), findsOneWidget);
      expect(find.text('Brasília'), findsOneWidget);
    });

    testWidgets('editar mantém id e tempo e salva os pares', (tester) async {
      final popped = await open(tester, editing: true);
      expect(find.text('Editar questão 2'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Paris'), 'Paris (França)');
      await tester.pump();
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final saved = popped.single!;
      expect(saved.id, 'q9');
      expect(saved.timeLimitS, 45);
      expect(saved.explanation, 'Capitais.');
      expect(saved.matchPairs, const [
        MatchPair('Brasil', 'Brasília'),
        MatchPair('França', 'Paris (França)'),
        MatchPair('Japão', 'Tóquio'),
      ]);
    });

    testWidgets('par repetido não deixa salvar e explica', (tester) async {
      final popped = await open(tester, editing: true);
      await tester.enterText(find.widgetWithText(TextField, 'Tóquio'), 'brasília');
      await tester.pump();
      expect(find.textContaining('repetidos da coluna da direita'), findsOneWidget);
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(popped, isEmpty); // continua aberta
    });
  });
}
