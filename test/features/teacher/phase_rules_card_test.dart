import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/phase_rules_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<PhaseRules>> pump(
    WidgetTester tester, {
    PhaseRules rules = const PhaseRules(),
    String? error,
  }) async {
    final saved = <PhaseRules>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PhaseRulesCard(
              rules: rules,
              onSave: (r) async {
                saved.add(r);
                return error;
              },
            ),
          ),
        ),
      ),
    );
    return saved;
  }

  testWidgets('fechado mostra o resumo; sem ajustes, explica o padrão',
      (tester) async {
    await pump(tester);
    expect(find.text('Prazo, nota mínima e relógio'), findsOneWidget);
    expect(
      find.text('Sempre aberta · basta concluir para liberar a próxima'),
      findsOneWidget,
    );
    expect(find.text('ABERTURA'), findsNothing);
  });

  testWidgets('liga a nota mínima e salva 75%', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.text('Prazo, nota mínima e relógio'));
    await tester.pumpAndSettle();

    expect(find.text('Aberta desde já'), findsOneWidget);
    expect(find.text('Sem prazo'), findsOneWidget);

    await tester
        .tap(find.text('Exigir nota mínima para liberar a próxima fase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '75');
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved, [const PhaseRules(passPct: 75)]);
  });

  testWidgets('nota mínima fora da faixa não salva e explica', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.text('Prazo, nota mínima e relógio'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('Exigir nota mínima para liberar a próxima fase'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.text('A nota mínima vai de 1% a 100%.'), findsOneWidget);
  });

  testWidgets('erro do servidor aparece no cartão', (tester) async {
    await pump(
      tester,
      error: 'Não foi possível salvar o prazo e a nota mínima.',
    );
    await tester.tap(find.text('Prazo, nota mínima e relógio'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.text('Exigir nota mínima para liberar a próxima fase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar o prazo e a nota mínima.'),
      findsOneWidget,
    );
  });

  testWidgets('liga o relógio no nível curto', (tester) async {
    final saved = await pump(tester);
    await tester.tap(find.text('Prazo, nota mínima e relógio'));
    await tester.pumpAndSettle();
    expect(find.text('Curto'), findsNothing);

    await tester.tap(find.text('Relógio: tempo para responder cada questão'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tempo esgotado vale 0'), findsOneWidget);
    await tester.tap(find.text('Curto'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved, [const PhaseRules(timerEnabled: true, timerLevel: 'short')]);
  });

  testWidgets('relógio salvo aparece no resumo', (tester) async {
    await pump(
      tester,
      rules: const PhaseRules(timerEnabled: true, timerLevel: 'long'),
    );
    expect(find.text('Relógio longo'), findsOneWidget);
  });

  testWidgets('remover a data e cancelar volta ao que estava salvo',
      (tester) async {
    final opens = DateTime.utc(2026, 10, 20, 11);
    await pump(tester, rules: PhaseRules(opensAt: opens, passPct: 70));
    await tester.tap(find.text('Prazo, nota mínima e relógio'));
    await tester.pumpAndSettle();

    expect(find.text(PhaseDateFormat.short(opens)), findsOneWidget);
    await tester.tap(find.byTooltip('Remover data'));
    await tester.pumpAndSettle();
    expect(find.text('Aberta desde já'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text(PhaseDateFormat.short(opens)), findsOneWidget);
  });
}
