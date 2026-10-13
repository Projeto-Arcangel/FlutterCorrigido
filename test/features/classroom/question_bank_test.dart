import 'package:arcangel_o_oficial/features/classroom/domain/entities/bank_question.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/question_bank.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:flutter_test/flutter_test.dart';

BankQuestion _q(
  String id,
  String text, {
  String phase = 'f1',
  String classroom = 'c1',
  List<String> options = const ['A', 'B'],
}) =>
    BankQuestion(
      question: Question(
        id: id,
        text: text,
        options: options,
        correctAnswer: 0,
        explanation: '',
        type: QuestionType.multipleChoice,
      ),
      classroomId: classroom,
      classroomName: classroom == 'c1' ? 'Turma 8A' : 'Turma 9B',
      phaseId: phase,
      phaseTitle: 'Fase $phase',
      aiGenerated: false,
      createdAt: null,
    );

void main() {
  // Da mais nova para a mais antiga, como vem do banco.
  final all = [
    _q('1', 'Quem foi Getúlio Vargas?', phase: 'f2'),
    _q('2', 'Quem  foi getúlio vargas?', phase: 'f3', classroom: 'c2'),
    _q('3', 'O que é fotossíntese?', phase: 'f2'),
    _q('4', 'Revolução de 1930', phase: 'destino'),
    _q('5', 'Revolução de 1930', phase: 'f2'),
    _q('6', 'Quem foi Getúlio Vargas?', phase: 'f2', options: ['X', 'Y']),
  ];

  test('tira as da própria fase e junta as repetidas (fica a mais nova)', () {
    final entries = buildBankEntries(all, phaseId: 'destino');
    expect(entries.map((e) => e.id), ['1', '3', '5', '6']);
    expect(entries.first.copies, 2); // "1" e "2": mesmo texto e alternativas
    expect(entries.last.copies, 1); // alternativas diferentes = outra questão
  });

  test('marca as que já existem na fase de destino e esconde por padrão', () {
    final entries = buildBankEntries(all, phaseId: 'destino');
    expect(entries.firstWhere((e) => e.id == '5').inThisPhase, isTrue);
    expect(filterBank(entries).map((e) => e.id), ['1', '3', '6']);
    expect(filterBank(entries, showInPhase: true), hasLength(4));
  });

  test('busca sem acento, todas as palavras, e por turma', () {
    final entries = buildBankEntries(all, phaseId: 'destino');
    expect(filterBank(entries, query: 'getulio').map((e) => e.id), ['1', '6']);
    expect(filterBank(entries, query: 'FOTOSSÍNTESE').map((e) => e.id), ['3']);
    expect(filterBank(entries, query: 'vargas x').map((e) => e.id), ['6']);
    expect(filterBank(entries, query: 'turma 8a fase f2'), hasLength(3));
    expect(filterBank(entries, classroomId: 'c2'), isEmpty);
  });

  test('foldForSearch', () {
    expect(foldForSearch('  Ação   ÉPICA çã '), 'acao epica ca');
  });
}
