import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/lesson/data/models/question_model.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question_kinds.dart';
import 'package:flutter_test/flutter_test.dart';

const _capitals = [
  CrosswordEntry('Brasília', 'Capital do Brasil'),
  CrosswordEntry('Salvador', 'Capital da Bahia'),
  CrosswordEntry('Recife', 'Capital de Pernambuco'),
  CrosswordEntry('Belém', 'Capital do Pará'),
  CrosswordEntry('Manaus', 'Capital do Amazonas'),
  CrosswordEntry('Natal', 'Capital do Rio Grande do Norte'),
  CrosswordEntry('Palmas', 'Capital do Tocantins'),
  CrosswordEntry('Curitiba', 'Capital do Paraná'),
];

/// As mesmas regras do crossword_ok do banco, mais: palavras na mesma
/// direção não se sobrepõem.
void _expectValidCrossword(CrosswordLayout layout) {
  expect(layout.rows, inInclusiveRange(1, gridMaxSize));
  expect(layout.cols, inInclusiveRange(1, gridMaxSize));
  final cells = <(int, int), String>{};
  final dirs = <(int, int), Set<bool>>{};
  for (var i = 0; i < layout.slots.length; i++) {
    final s = layout.slots[i];
    final w = layout.words[i];
    expect(w.length, s.len);
    expect(RegExp(r'^[A-Z]+$').hasMatch(w), isTrue);
    for (var k = 0; k < s.len; k++) {
      final cell = s.cell(k);
      expect(cell.$1, inInclusiveRange(0, layout.rows - 1));
      expect(cell.$2, inInclusiveRange(0, layout.cols - 1));
      if (cells.containsKey(cell)) expect(cells[cell], w[k], reason: 'cruzamento');
      cells[cell] = w[k];
      expect((dirs[cell] ??= {}).add(s.across), isTrue, reason: 'sobreposição');
    }
  }
  // Números em ordem de leitura.
  final nums = [for (final s in layout.slots) s.num];
  expect(nums, [...nums]..sort());
}

void main() {
  test('palavra da grade: maiúscula, sem acento e só letras', () {
    expect(normalizeGridWord('Pau-Brasil'), 'PAUBRASIL');
    expect(normalizeGridWord('São Paulo'), 'SAOPAULO');
    expect(normalizeGridWord('Ação 2'), 'ACAO');
    expect(normalizeGridWord('Belém'), 'BELEM');
  });

  test('cruzadinha: tudo encaixado, cruzamentos certos e mesma grade sempre',
      () {
    final layout = buildCrosswordLayout(_capitals)!;
    expect(layout.unplaced, isEmpty);
    expect(layout.words.toSet(), {
      'BRASILIA', 'SALVADOR', 'RECIFE', 'BELEM', 'MANAUS', 'NATAL', 'PALMAS',
      'CURITIBA',
    });
    _expectValidCrossword(layout);
    // Pelo menos metade das palavras cruza outra.
    final again = buildCrosswordLayout(_capitals)!;
    expect(again.words, layout.words);
    expect(again.slots.map((s) => s.toJson()), layout.slots.map((s) => s.toJson()));
  });

  test('palavra sem letra em comum entra solta, sem encostar', () {
    final layout = buildCrosswordLayout(const [
      CrosswordEntry('ABACATE', 'Fruta verde'),
      CrosswordEntry('BANANA', 'Fruta amarela'),
      CrosswordEntry('CAJU', 'Fruta do Nordeste'),
      CrosswordEntry('XYZ', 'Sem letra em comum'),
    ])!;
    expect(layout.unplaced, isEmpty);
    _expectValidCrossword(layout);
    expect(layout.words, contains('XYZ'));
  });

  test('cruzadinha vira questão e volta à forma do professor', () {
    final q = buildCrosswordQuestion(text: 'Capitais.', entries: _capitals)!;
    expect(q.type, QuestionType.crossword);
    expect(q.crosswordSlots.length, 8);
    expect(q.crosswordEntries.map((e) => e.word).toSet(), {
      'BRASILIA', 'SALVADOR', 'RECIFE', 'BELEM', 'MANAUS', 'NATAL', 'PALMAS',
      'CURITIBA',
    });
    final row = <String, dynamic>{
      'id': 'x',
      'text': q.text,
      'type': 'crossword',
      'options': <String>[],
      'content': q.content,
      'answer': q.answer,
    };
    final back = QuestionModel.fromMap(row);
    expect(back.crosswordEntries, q.crosswordEntries);
  });

  test('validação da cruzadinha', () {
    expect(validateCrossword(_capitals), isNull);
    expect(validateCrossword(_capitals.take(3).toList()), contains('4 a 10'));
    expect(
      validateCrossword([..._capitals.take(3), const CrosswordEntry('Belem', 'x'), const CrosswordEntry('belém', 'y')]),
      contains('repetida'),
    );
    expect(
      validateCrossword([..._capitals.take(3), const CrosswordEntry('Oi', 'Curta')]),
      contains('3 a 12 letras'),
    );
    expect(
      validateCrossword([..._capitals.take(3), const CrosswordEntry('Recife', ' ')]),
      contains('Preencha'),
    );
  });

  test('caça-palavras: cada posição forma a palavra', () {
    final words = ['Sol', 'Lua', 'Estrela', 'Cometa', 'Planeta', 'Galáxia', 'Órbita'];
    final layout = buildWordSearchLayout(words)!;
    expect(layout.size, inInclusiveRange(8, gridMaxSize));
    expect(layout.grid.length, layout.size);
    for (final row in layout.grid) {
      expect(row, matches(RegExp('^[A-Z]{${layout.size}}\$')));
    }
    for (var i = 0; i < layout.words.length; i++) {
      final p = layout.positions[i];
      expect(gridLine(layout.grid, p[0], p[1], p[2], p[3]), layout.words[i]);
    }
    expect(layout.words, contains('GALAXIA'));
    expect(buildWordSearchLayout(words)!.grid, layout.grid); // mesma grade
  });

  test('leitura da grade: retas, de trás para frente e fora da grade', () {
    const grid = ['SOLXYZ', 'AMARZQ', 'LUAWER', 'PLKJHG', 'MNBVCX', 'QWERTY'];
    expect(gridLine(grid, 0, 0, 0, 2), 'SOL');
    expect(gridLine(grid, 0, 2, 0, 0), 'LOS');
    expect(gridLine(grid, 0, 0, 2, 0), 'SAL');
    expect(gridLine(grid, 0, 0, 2, 2), 'SMA');
    expect(gridLine(grid, 0, 0, 1, 2), isNull); // torta
    expect(gridLine(grid, 0, 0, 0, 9), isNull); // fora
  });

  test('validação do caça-palavras', () {
    expect(validateWordSearch(['sol', 'lua', 'mar', 'céu']), isNull);
    expect(validateWordSearch(['sol', 'lua', 'mar']), contains('4 a 12'));
    expect(validateWordSearch(['sol', 'lua', 'mar', 'SOL']), contains('repetida'));
    expect(validateWordSearch(['sol', 'lua', 'mar', 'paralelepipedos']), contains('3 a 12'));
  });

  test('tempo automático: mesma conta do servidor', () {
    // Exemplos do teste SQL (grid_test.sql).
    const crossword = Question(
      id: 'c',
      text: 'Resolva a cruzadinha.',
      options: [],
      correctAnswer: 0,
      explanation: '',
      type: QuestionType.crossword,
      content: {
        'rows': 8,
        'cols': 8,
        'entries': [
          {'num': 1, 'row': 0, 'col': 0, 'dir': 'across', 'len': 8, 'clue': 'Capital do Brasil'},
          {'num': 1, 'row': 0, 'col': 0, 'dir': 'down', 'len': 5, 'clue': 'Estado do Nordeste'},
          {'num': 2, 'row': 0, 'col': 3, 'dir': 'down', 'len': 8, 'clue': 'Capital da Bahia'},
        ],
      },
    );
    expect(autoTimeLimitOf(crossword, 'normal'), 55);
    const wordSearch = Question(
      id: 'w',
      text: 'Ache as palavras.',
      options: [],
      correctAnswer: 0,
      explanation: '',
      type: QuestionType.wordSearch,
      content: {
        'rows': 6,
        'cols': 6,
        'grid': ['SOLXYZ', 'AMARZQ', 'LUAWER', 'PLKJHG', 'MNBVCX', 'QWERTY'],
        'words': ['SOL', 'MAR', 'LUA'],
      },
    );
    expect(autoTimeLimitOf(wordSearch, 'normal'), 45);
  });
}
