import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/lesson/data/models/question_model.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/widgets/question_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _question = Question(
  id: 'q1',
  text: 'Qual é a capital da França?',
  options: ['Roma', 'Paris', 'Lima'],
  correctAnswer: 1,
  explanation: 'Paris.',
  type: QuestionType.multipleChoice,
);

void main() {
  group('tempo automático (mesma conta do servidor)', () {
    test('mesmos valores do teste SQL de question_time_limit', () {
      expect(autoTimeLimit('Capital?', ['A', 'B'], 'short'), 15);
      final long = 'a' * 1500;
      expect(autoTimeLimit(long, ['a'], 'short'), 85);
      expect(autoTimeLimit(long, ['a'], 'normal'), 145);
      expect(autoTimeLimit(long, ['a'], 'long'), 220);
      expect(autoTimeLimit('a' * 9000, ['a'], 'long'), 300);
    });

    test('formato do tempo', () {
      expect(formatSeconds(45), '45 s');
      expect(formatSeconds(60), '1 min');
      expect(formatSeconds(90), '1 min 30 s');
      expect(formatSeconds(600), '10 min');
    });

    test('lê o tempo da questão do banco', () {
      expect(
        QuestionModel.fromMap(const {'id': 'q', 'time_limit_s': 45}).timeLimitS,
        45,
      );
      expect(QuestionModel.fromMap(const {'id': 'q'}).timeLimitS, isNull);
      expect(_question.withTimeLimit(30).timeLimitS, 30);
      expect(_question.withTimeLimit(30).withTimeLimit(null), _question);
    });
  });

  group('ficha da questão', () {
    Future<List<Question?>> open(
      WidgetTester tester, {
      Question question = _question,
      bool timerEnabled = true,
    }) async {
      final popped = <Question?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped.add(
                    await showModalBottomSheet<Question>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => QuestionDetailSheet(
                        question: question,
                        order: 1,
                        timerEnabled: timerEnabled,
                        timerLevel: 'normal',
                      ),
                    ),
                  );
                },
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

    testWidgets('mostra o automático e salva o tempo escolhido',
        (tester) async {
      final popped = await open(tester);
      expect(
        find.text('Tempo para responder: automático (25 s)'),
        findsOneWidget,
      );

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Automático (25 s)'));
      await tester.tap(find.text('Automático (25 s)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, '45 s'));
      await tester.pumpAndSettle();
      expect(find.text('45 s'), findsOneWidget);

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(popped.single, _question.withTimeLimit(45));
    });

    testWidgets('editar o texto mantém o tempo escolhido', (tester) async {
      final popped = await open(tester, question: _question.withTimeLimit(90));
      expect(find.text('Tempo para responder: 1 min 30 s'), findsOneWidget);

      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Qual é a capital da França?'),
        'Capital da França?',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      expect(popped.single!.text, 'Capital da França?');
      expect(popped.single!.timeLimitS, 90);
    });

    testWidgets('com o relógio desligado, avisa que o tempo não vale ainda',
        (tester) async {
      await open(
        tester,
        question: _question.withTimeLimit(30),
        timerEnabled: false,
      );
      expect(
        find.textContaining('Vale quando o relógio da fase estiver ligado'),
        findsOneWidget,
      );
    });
  });
}
