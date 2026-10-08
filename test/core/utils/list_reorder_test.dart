import 'package:arcangel_o_oficial/core/utils/list_reorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const itens = ['A', 'B', 'C', 'D', 'E'];

  group('reorderedList (índices do ReorderableListView)', () {
    test('primeiro para o fim', () {
      expect(reorderedList(itens, 0, 5), ['B', 'C', 'D', 'E', 'A']);
    });

    test('último para o início', () {
      expect(reorderedList(itens, 4, 0), ['E', 'A', 'B', 'C', 'D']);
    });

    test('descendo: o destino conta o próprio item', () {
      // Arrastar B para depois de D: o Flutter informa newIndex = 4.
      expect(reorderedList(itens, 1, 4), ['A', 'C', 'D', 'B', 'E']);
    });

    test('subindo', () {
      expect(reorderedList(itens, 3, 1), ['A', 'D', 'B', 'C', 'E']);
    });

    test('soltar no mesmo lugar não muda nada', () {
      expect(reorderedList(itens, 2, 2), itens);
      expect(reorderedList(itens, 2, 3), itens);
    });

    test('não altera a lista original', () {
      final original = [...itens];
      reorderedList(original, 0, 5);
      expect(original, itens);
    });

    test('todo movimento possível mantém todos os itens, sem repetir', () {
      for (var de = 0; de < itens.length; de++) {
        for (var para = 0; para <= itens.length; para++) {
          final resultado = reorderedList(itens, de, para);
          expect(resultado.length, itens.length, reason: '$de → $para');
          expect(resultado.toSet(), itens.toSet(), reason: '$de → $para');
          final destino = para > de ? para - 1 : para;
          expect(resultado[destino], itens[de], reason: '$de → $para');
        }
      }
    });
  });

  group('arrastando de verdade num ReorderableListView', () {
    Future<List<String>> arrasta(
      WidgetTester tester, {
      required int de,
      required int linhas,
    }) async {
      var atual = [...itens];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: atual.length,
                onReorder: (o, n) =>
                    setState(() => atual = reorderedList(atual, o, n)),
                itemBuilder: (_, i) => SizedBox(
                  key: ValueKey(atual[i]),
                  height: 60,
                  child: Row(
                    children: [
                      Expanded(child: Text(atual[i])),
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_handle,
                          key: Key('alça ${atual[i]}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final alca = find.byKey(Key('alça ${itens[de]}'));
      final gesto = await tester.startGesture(tester.getCenter(alca));
      // A alça (ReorderableDragStartListener) começa o arraste na hora.
      await tester.pump();
      // Desce/sobe [linhas] alturas de item, em passos (como um dedo).
      for (var i = 0; i < 12; i++) {
        await gesto.moveBy(Offset(0, linhas * 60 / 12));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesto.up();
      await tester.pumpAndSettle();
      return atual;
    }

    testWidgets('A desce 2 posições', (tester) async {
      expect(
        await arrasta(tester, de: 0, linhas: 2),
        ['B', 'C', 'A', 'D', 'E'],
      );
    });

    testWidgets('E sobe até o topo', (tester) async {
      expect(
        await arrasta(tester, de: 4, linhas: -4),
        ['E', 'A', 'B', 'C', 'D'],
      );
    });

    testWidgets('B desce até o fim', (tester) async {
      expect(
        await arrasta(tester, de: 1, linhas: 3),
        ['A', 'C', 'D', 'E', 'B'],
      );
    });

    testWidgets('D sobe 1 posição', (tester) async {
      expect(
        await arrasta(tester, de: 3, linhas: -1),
        ['A', 'B', 'D', 'C', 'E'],
      );
    });
  });
}
