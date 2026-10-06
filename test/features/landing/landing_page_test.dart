import 'package:arcangel_o_oficial/features/landing/presentation/pages/landing_page.dart';
import 'package:arcangel_o_oficial/features/landing/presentation/widgets/landing_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renderiza a landing inteira (viewport alto) para que todas as seções sejam
/// construídas e qualquer overflow de layout falhe o teste.
Future<void> _pumpLanding(
  WidgetTester tester, {
  required Size size,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool reduceMotion = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: const LandingPage(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Opacidade do [LandingReveal] mais próximo acima do texto.
double _revealOpacity(WidgetTester tester, String text) {
  final opacity = tester.widget<AnimatedOpacity>(
    find
        .ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity))
        .first,
  );
  return opacity.opacity;
}

void main() {
  const widths = [320.0, 390.0, 700.0, 1000.0, 1440.0];

  for (final width in widths) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'renderiza sem overflow em ${width.toInt()}px '
          '(${brightness.name})', (tester) async {
        await _pumpLanding(
          tester,
          size: Size(width, 9000),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mostra as seções Sobre, Planos e Suporte e o rodapé',
      (tester) async {
    await _pumpLanding(tester, size: const Size(1440, 9000));

    expect(find.text('Conheça o Arcangel'), findsOneWidget);
    expect(find.text('Como funciona'), findsOneWidget);
    expect(find.text('Grátis'), findsOneWidget);
    expect(find.text(r'R$ 15/mês', findRichText: true), findsOneWidget);
    expect(find.text(r'R$ 40/mês', findRichText: true), findsOneWidget);
    expect(find.text('Começar grátis'), findsOneWidget);
    expect(find.text('Assinar por e-mail'), findsNWidgets(2));
    expect(find.text('O Arcangel é gratuito?'), findsOneWidget);
    expect(find.text('Ainda precisa de ajuda?'), findsOneWidget);
    expect(find.textContaining('Todos os direitos reservados'), findsOneWidget);
  });

  testWidgets('pergunta do FAQ expande e mostra a resposta', (tester) async {
    await _pumpLanding(tester, size: const Size(1440, 9000));

    const answerStart = 'Sim. O plano Free não tem custo';
    expect(find.textContaining(answerStart), findsNothing);

    await tester.tap(find.text('O Arcangel é gratuito?'));
    await tester.pumpAndSettle();

    expect(find.textContaining(answerStart), findsOneWidget);
  });

  // WCAG 1.4.4: o conteúdo continua utilizável com o texto ampliado em 200%.
  for (final width in [390.0, 1440.0]) {
    testWidgets('texto em 200% não estoura o layout em ${width.toInt()}px',
        (tester) async {
      await _pumpLanding(tester, size: Size(width, 16000), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conteúdo fora da tela só aparece ao rolar até ele',
      (tester) async {
    await _pumpLanding(tester, size: const Size(1440, 900));

    expect(_revealOpacity(tester, 'Ainda precisa de ajuda?'), 0);

    await tester.scrollUntilVisible(
      find.text('Ainda precisa de ajuda?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(_revealOpacity(tester, 'Ainda precisa de ajuda?'), 1);
  });

  testWidgets('com "reduzir movimento" tudo aparece sem animação',
      (tester) async {
    await _pumpLanding(
      tester,
      size: const Size(1440, 900),
      reduceMotion: true,
      settle: false,
    );
    await tester.pump();

    // Nada fica escondido esperando rolagem nem animação.
    expect(
      find.descendant(
        of: find.byType(LandingReveal),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );
    expect(find.text('Ainda precisa de ajuda?'), findsOneWidget);
  });
}
