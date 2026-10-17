import 'dart:math';

import 'question.dart';

/// Ligar colunas, ordenar (Estágio 4, Etapa 2) e completar lacunas
/// (Etapa 3).
///
/// No banco (migrations 20261017120100_match_ordering e
/// 20261017140000_fill_blanks):
/// - ligar colunas: `content {left, right}` com a direita embaralhada e
///   `answer {match}` — esquerda i ↔ direita `match[i]`;
/// - ordenar: `content {items}` embaralhados e `answer {order}` —
///   `items[order[k]]` é o k-ésimo na ordem certa;
/// - lacunas: `content {parts, bank}` — a lacuna k fica entre `parts[k]` e
///   `parts[k+1]`; banco embaralhado com distratores — e `answer {blanks}`
///   — lacuna k ↔ `bank[blanks[k]]`.
///
/// O professor escreve na forma natural (pares em linha; itens já na
/// ordem certa) e o embaralhamento acontece ao montar a questão, sem
/// nunca deixar a ordem mostrada igual à resposta.

/// Limites (os mesmos da CHECK do banco).
const matchMinPairs = 3;
const matchMaxPairs = 6;
const orderingMinItems = 3;
const orderingMaxItems = 8;
const kindItemMaxChars = 200;
const blanksMax = 8;
const blankDistractorsMax = 6;
const blankWordMaxChars = 80;
const blankTextMaxChars = 1500;

class MatchPair {
  const MatchPair(this.left, this.right);
  final String left;
  final String right;

  @override
  bool operator ==(Object other) =>
      other is MatchPair && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => '$left ↔ $right';
}

extension QuestionKinds on Question {
  bool get isMatchColumns => type == QuestionType.matchColumns;
  bool get isOrdering => type == QuestionType.ordering;

  /// Coluna da esquerda (na ordem do professor).
  List<String> get matchLeft => _strings(content?['left']);

  /// Coluna da direita (embaralhada, como o aluno vê).
  List<String> get matchRight => _strings(content?['right']);

  /// Itens para ordenar (embaralhados, como o aluno vê).
  List<String> get orderingItems => _strings(content?['items']);

  /// Gabarito do ligar colunas (só o professor tem).
  List<int>? get matchKey => _ints(answer?['match']);

  /// Gabarito do ordenar (só o professor tem).
  List<int>? get orderKey => _ints(answer?['order']);

  /// Pares na forma do professor: esquerda i ↔ a direita certa.
  List<MatchPair> get matchPairs {
    final key = matchKey;
    final left = matchLeft;
    final right = matchRight;
    if (key == null || key.length != left.length) return const [];
    return [
      for (var i = 0; i < left.length; i++)
        if (key[i] >= 0 && key[i] < right.length) MatchPair(left[i], right[key[i]]),
    ];
  }

  /// Itens na ordem certa (forma do professor).
  List<String> get orderedItems {
    final key = orderKey;
    final items = orderingItems;
    if (key == null || key.length != items.length) return const [];
    return [
      for (final k in key)
        if (k >= 0 && k < items.length) items[k],
    ];
  }

  /// Lacunas: trechos de texto entre as lacunas.
  List<String> get blankParts => _strings(content?['parts']);

  /// Lacunas: o banco de palavras (embaralhado, com distratores).
  List<String> get blankBank => _strings(content?['bank']);

  /// Lacunas: gabarito (só o professor tem).
  List<int>? get blankKey => _ints(answer?['blanks']);

  /// Lacunas: as palavras certas, na ordem das lacunas.
  List<String> get blankAnswers {
    final key = blankKey;
    final bank = blankBank;
    if (key == null) return const [];
    return [
      for (final k in key)
        if (k >= 0 && k < bank.length) bank[k],
    ];
  }

  /// Lacunas: palavras do banco que não vão em nenhuma lacuna.
  List<String> get blankDistractors {
    final used = {...?blankKey};
    final bank = blankBank;
    return [
      for (var i = 0; i < bank.length; i++)
        if (!used.contains(i)) bank[i],
    ];
  }

  /// Lacunas na forma do professor: "O Brasil foi descoberto em [1500]".
  String get blankTemplate {
    final parts = blankParts;
    final answers = blankAnswers;
    if (parts.isEmpty || answers.length != parts.length - 1) {
      return parts.join();
    }
    final out = StringBuffer(parts.first);
    for (var k = 0; k < answers.length; k++) {
      out
        ..write('[${answers[k]}]')
        ..write(parts[k + 1]);
    }
    return out.toString();
  }

  /// Cruzadinha: tamanho da grade.
  int get gridRows => _int(content?['rows']);
  int get gridCols => _int(content?['cols']);

  /// Cruzadinha: as palavras da grade (posição, direção e dica), sem as
  /// letras.
  List<CrosswordSlot> get crosswordSlots => [
        for (final e in (content?['entries'] as List?) ?? const [])
          if (e is Map) CrosswordSlot.fromJson(Map<String, dynamic>.from(e)),
      ];

  /// Cruzadinha: as palavras certas, na ordem de [crosswordSlots] (só o
  /// professor tem).
  List<String> get crosswordWords => _strings(answer?['words']);

  /// Cruzadinha na forma do professor (palavra + dica).
  List<CrosswordEntry> get crosswordEntries {
    final slots = crosswordSlots;
    final words = crosswordWords;
    return [
      for (var i = 0; i < slots.length && i < words.length; i++)
        CrosswordEntry(words[i], slots[i].clue),
    ];
  }

  /// Caça-palavras: a grade (uma linha por item).
  List<String> get wordSearchGrid => _strings(content?['grid']);

  /// Caça-palavras: as palavras a achar (o aluno vê a lista).
  List<String> get wordSearchWords => _strings(content?['words']);

  /// Caça-palavras: onde está cada palavra, [r1, c1, r2, c2] (só o
  /// professor tem).
  List<List<int>> get wordSearchPositions => [
        for (final p in (answer?['positions'] as List?) ?? const [])
          if (p is List) [for (final v in p) _int(v)],
      ];

  /// Todos os textos do conteúdo (para o tempo automático): na cruzadinha,
  /// as dicas; nos outros, as listas de textos.
  List<String> get contentTexts => type == QuestionType.crossword
      ? [for (final s in crosswordSlots) s.clue]
      : [
          for (final value in (content ?? const <String, dynamic>{}).values)
            if (value is List)
              for (final item in value)
                if (item is String) item,
        ];

  /// Quantos pares/itens/lacunas/palavras o aluno precisa resolver.
  int get interactions => switch (type) {
        QuestionType.matchColumns => matchLeft.length,
        QuestionType.ordering => orderingItems.length,
        QuestionType.fillBlanks =>
          blankParts.isEmpty ? 0 : blankParts.length - 1,
        QuestionType.crossword => crosswordSlots.length,
        QuestionType.wordSearch => wordSearchWords.length,
        _ => 0,
      };

  /// Segundos a mais no tempo automático para mexer (mesma conta do
  /// servidor): 3 s por par/item/lacuna, 10 s por palavra da cruzadinha,
  /// 6 s por palavra do caça-palavras.
  int get extraSeconds => switch (type) {
        QuestionType.crossword => 10 * interactions,
        QuestionType.wordSearch => 6 * interactions,
        _ => 3 * interactions,
      };
}

// ─── Cruzadinha e caça-palavras (Etapa 4) ──────────────────────────────

const crosswordMinWords = 4;
const crosswordMaxWords = 10;
const wordSearchMinWords = 4;
const wordSearchMaxWords = 12;
const gridWordMinLetters = 3;
const gridWordMaxLetters = 12;
const gridMaxSize = 15;
const crosswordClueMaxChars = 200;

const _accents = {
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
  'Ç': 'C', 'Ñ': 'N',
};

/// Palavra da grade: maiúsculas, sem acento, só A–Z ("Pau-Brasil" →
/// "PAUBRASIL"), como em cruzadinha.
String normalizeGridWord(String word) {
  final out = StringBuffer();
  for (final ch in word.toUpperCase().split('')) {
    final plain = _accents[ch] ?? ch;
    if (RegExp(r'^[A-Z]$').hasMatch(plain)) out.write(plain);
  }
  return out.toString();
}

/// Palavra + dica, como o professor escreve.
class CrosswordEntry {
  const CrosswordEntry(this.word, this.clue);
  final String word;
  final String clue;

  @override
  bool operator ==(Object other) =>
      other is CrosswordEntry && other.word == word && other.clue == clue;

  @override
  int get hashCode => Object.hash(word, clue);
}

/// Uma palavra na grade da cruzadinha (sem as letras).
class CrosswordSlot {
  const CrosswordSlot({
    required this.num,
    required this.row,
    required this.col,
    required this.across,
    required this.len,
    required this.clue,
  });

  factory CrosswordSlot.fromJson(Map<String, dynamic> json) => CrosswordSlot(
        num: _int(json['num']),
        row: _int(json['row']),
        col: _int(json['col']),
        across: json['dir'] == 'across',
        len: _int(json['len']),
        clue: '${json['clue'] ?? ''}',
      );

  final int num;
  final int row;
  final int col;
  final bool across;
  final int len;
  final String clue;

  /// Casa da k-ésima letra.
  (int, int) cell(int k) => across ? (row, col + k) : (row + k, col);

  Map<String, dynamic> toJson() => {
        'num': num,
        'row': row,
        'col': col,
        'dir': across ? 'across' : 'down',
        'len': len,
        'clue': clue,
      };
}

/// Por que a cruzadinha não pode ser montada (`null` = pode).
String? validateCrossword(List<CrosswordEntry> entries) {
  if (entries.length < crosswordMinWords || entries.length > crosswordMaxWords) {
    return 'Use de $crosswordMinWords a $crosswordMaxWords palavras.';
  }
  final seen = <String>{};
  for (final e in entries) {
    final w = normalizeGridWord(e.word);
    if (w.isEmpty || e.clue.trim().isEmpty) {
      return 'Preencha a palavra e a dica de cada linha.';
    }
    if (w.length < gridWordMinLetters || w.length > gridWordMaxLetters) {
      return 'Cada palavra precisa ter de $gridWordMinLetters a '
          '$gridWordMaxLetters letras ("${e.word.trim()}").';
    }
    if (e.clue.trim().length > crosswordClueMaxChars) {
      return 'Cada dica pode ter até $crosswordClueMaxChars caracteres.';
    }
    if (!seen.add(w)) return 'A palavra "${e.word.trim()}" está repetida.';
  }
  return null;
}

/// Por que o caça-palavras não pode ser montado (`null` = pode).
String? validateWordSearch(List<String> words) {
  if (words.length < wordSearchMinWords || words.length > wordSearchMaxWords) {
    return 'Use de $wordSearchMinWords a $wordSearchMaxWords palavras.';
  }
  final seen = <String>{};
  for (final raw in words) {
    final w = normalizeGridWord(raw);
    if (w.isEmpty) return 'Preencha todas as palavras.';
    if (w.length < gridWordMinLetters || w.length > gridWordMaxLetters) {
      return 'Cada palavra precisa ter de $gridWordMinLetters a '
          '$gridWordMaxLetters letras ("${raw.trim()}").';
    }
    if (!seen.add(w)) return 'A palavra "${raw.trim()}" está repetida.';
  }
  return null;
}

/// Grade montada da cruzadinha. [unplaced]: palavras que não couberam.
class CrosswordLayout {
  const CrosswordLayout({
    required this.rows,
    required this.cols,
    required this.slots,
    required this.words,
    this.unplaced = const [],
  });

  final int rows;
  final int cols;
  final List<CrosswordSlot> slots;

  /// Letras de cada slot (mesma ordem).
  final List<String> words;
  final List<String> unplaced;
}

/// Semente estável para a mesma lista: a prévia é a grade que vai salva.
int _seedOf(Iterable<String> words) =>
    words.fold<int>(17, (h, w) => (h * 31 + w.hashCode) & 0x7fffffff);

class _Cw {
  final cells = <(int, int), String>{};
  final dirs = <(int, int), Set<bool>>{};
  final placed = <({String word, String clue, int row, int col, bool across})>[];

  bool canPlace(String w, int r, int c, bool across, {required bool needCross}) {
    final dr = across ? 0 : 1;
    final dc = across ? 1 : 0;
    if (cells.containsKey((r - dr, c - dc))) return false;
    if (cells.containsKey((r + dr * w.length, c + dc * w.length))) return false;
    var crosses = 0;
    for (var k = 0; k < w.length; k++) {
      final cell = (r + dr * k, c + dc * k);
      final existing = cells[cell];
      if (existing != null) {
        if (existing != w[k] || (dirs[cell]?.contains(across) ?? false)) {
          return false;
        }
        crosses++;
      } else {
        final (rr, cc) = cell;
        final side1 = across ? (rr - 1, cc) : (rr, cc - 1);
        final side2 = across ? (rr + 1, cc) : (rr, cc + 1);
        if (cells.containsKey(side1) || cells.containsKey(side2)) return false;
      }
    }
    return !needCross || crosses > 0;
  }

  void place(String w, String clue, int r, int c, bool across) {
    for (var k = 0; k < w.length; k++) {
      final cell = across ? (r, c + k) : (r + k, c);
      cells[cell] = w[k];
      (dirs[cell] ??= {}).add(across);
    }
    placed.add((word: w, clue: clue, row: r, col: c, across: across));
  }

  (int, int, int, int) bounds() {
    var minR = 1 << 30, minC = 1 << 30, maxR = -(1 << 30), maxC = -(1 << 30);
    for (final (r, c) in cells.keys) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
      if (r > maxR) maxR = r;
      if (c > maxC) maxC = c;
    }
    return (minR, minC, maxR, maxC);
  }

  int areaWith(String w, int r, int c, bool across) {
    var (minR, minC, maxR, maxC) = bounds();
    final endR = across ? r : r + w.length - 1;
    final endC = across ? c + w.length - 1 : c;
    if (r < minR) minR = r;
    if (c < minC) minC = c;
    if (endR > maxR) maxR = endR;
    if (endC > maxC) maxC = endC;
    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;
    // Prefere grade compacta e quadrada.
    return rows * cols + (rows - cols).abs() * 3;
  }
}

/// Monta a grade da cruzadinha: cada palavra cruza outra sempre que dá;
/// a que não cruza nenhuma entra solta, sem encostar nas outras. Tenta
/// várias ordens e fica com a menor grade que cabe em 15×15.
CrosswordLayout? buildCrosswordLayout(
  List<CrosswordEntry> entries, {
  int attempts = 24,
}) {
  final items = [
    for (final e in entries)
      (word: normalizeGridWord(e.word), clue: e.clue.trim()),
  ];
  if (items.isEmpty) return null;
  final random = Random(_seedOf(items.map((i) => '${i.word}|${i.clue}')));
  _Cw? best;
  var bestScore = 1 << 30;
  var bestUnplaced = <String>[];

  for (var a = 0; a < attempts; a++) {
    final order = [...items]..sort((x, y) => y.word.length.compareTo(x.word.length));
    if (a > 0) {
      final rest = order.sublist(1)..shuffle(random);
      order.replaceRange(1, order.length, rest);
    }
    final cw = _Cw()..place(order.first.word, order.first.clue, 0, 0, true);
    final unplaced = <({String word, String clue})>[];

    for (final item in order.skip(1)) {
      final w = item.word;
      ({int r, int c, bool across, int score})? cand;
      for (final p in cw.placed) {
        for (var i = 0; i < w.length; i++) {
          for (var j = 0; j < p.word.length; j++) {
            if (w[i] != p.word[j]) continue;
            final across = !p.across;
            final r = p.across ? p.row - i : p.row + j;
            final c = p.across ? p.col + j : p.col - i;
            if (!cw.canPlace(w, r, c, across, needCross: true)) continue;
            final score = cw.areaWith(w, r, c, across) - random.nextInt(3);
            if (cand == null || score < cand.score) {
              cand = (r: r, c: c, across: across, score: score);
            }
          }
        }
      }
      if (cand != null) {
        cw.place(w, item.clue, cand.r, cand.c, cand.across);
      } else {
        unplaced.add(item);
      }
    }

    // Quem não cruzou entra solto, perto da grade, sem encostar em nada.
    final stillOut = <String>[];
    for (final item in unplaced) {
      final (minR, minC, maxR, maxC) = cw.bounds();
      ({int r, int c, bool across, int score})? spot;
      for (final across in [true, false]) {
        for (var r = minR - 2; r <= maxR + 2; r++) {
          for (var c = minC - 2; c <= maxC + 2; c++) {
            if (!cw.canPlace(item.word, r, c, across, needCross: false)) continue;
            // Sem encostar: nenhuma casa vizinha ocupada.
            var touches = false;
            for (var k = -1; k <= item.word.length && !touches; k++) {
              for (var s = -1; s <= 1 && !touches; s++) {
                final cell = across ? (r + s, c + k) : (r + k, c + s);
                if (cw.cells.containsKey(cell)) touches = true;
              }
            }
            if (touches) continue;
            final score = cw.areaWith(item.word, r, c, across);
            if (spot == null || score < spot.score) {
              spot = (r: r, c: c, across: across, score: score);
            }
          }
        }
      }
      if (spot != null) {
        cw.place(item.word, item.clue, spot.r, spot.c, spot.across);
      } else {
        stillOut.add(item.word);
      }
    }

    final (minR, minC, maxR, maxC) = cw.bounds();
    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;
    if (rows > gridMaxSize || cols > gridMaxSize) continue;
    final crossings = cw.dirs.values.where((d) => d.length > 1).length;
    final score = stillOut.length * 100000 +
        rows * cols +
        (rows - cols).abs() * 3 -
        crossings * 4;
    if (score < bestScore) {
      bestScore = score;
      best = cw;
      bestUnplaced = stillOut;
    }
  }

  final cw = best;
  if (cw == null) return null;
  final (minR, minC, maxR, maxC) = cw.bounds();

  // Numeração: casas de início em ordem de leitura; horizontal e vertical
  // que começam na mesma casa ficam com o mesmo número.
  final starts = <(int, int)>{
    for (final p in cw.placed) (p.row - minR, p.col - minC),
  }.toList()
    ..sort((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2));
  final numbers = {for (var i = 0; i < starts.length; i++) starts[i]: i + 1};
  final ordered = [...cw.placed]..sort((x, y) {
      final nx = numbers[(x.row - minR, x.col - minC)]!;
      final ny = numbers[(y.row - minR, y.col - minC)]!;
      if (nx != ny) return nx.compareTo(ny);
      return x.across ? -1 : 1;
    });

  return CrosswordLayout(
    rows: maxR - minR + 1,
    cols: maxC - minC + 1,
    slots: [
      for (final p in ordered)
        CrosswordSlot(
          num: numbers[(p.row - minR, p.col - minC)]!,
          row: p.row - minR,
          col: p.col - minC,
          across: p.across,
          len: p.word.length,
          clue: p.clue,
        ),
    ],
    words: [for (final p in ordered) p.word],
    unplaced: bestUnplaced,
  );
}

/// Monta a questão de cruzadinha; `null` se as palavras não couberem
/// todas numa grade de até 15×15 (veja [buildCrosswordLayout]).
Question? buildCrosswordQuestion({
  String id = '',
  required String text,
  required List<CrosswordEntry> entries,
  String explanation = '',
  int? timeLimitS,
}) {
  final layout = buildCrosswordLayout(entries);
  if (layout == null || layout.unplaced.isNotEmpty) return null;
  return Question(
    id: id,
    text: text.trim(),
    options: const [],
    correctAnswer: 0,
    explanation: explanation.trim(),
    type: QuestionType.crossword,
    timeLimitS: timeLimitS,
    content: {
      'rows': layout.rows,
      'cols': layout.cols,
      'entries': [for (final s in layout.slots) s.toJson()],
    },
    answer: {'words': layout.words},
  );
}

/// Grade montada do caça-palavras.
class WordSearchLayout {
  const WordSearchLayout({
    required this.size,
    required this.grid,
    required this.words,
    required this.positions,
  });

  final int size;
  final List<String> grid;
  final List<String> words;
  final List<List<int>> positions;
}

/// Letras para completar a grade (mais as comuns em português).
const _fillLetters = 'AAAAAEEEEEIIIOOOOUUSSSRRRNNNTTTLLMMDDCCPPBGVFHQZJX';

/// Monta o caça-palavras: palavras em →, ↓, ↘ e ↗, o resto com letras
/// aleatórias. Grade quadrada de 8 a 15. `null` se não couber.
WordSearchLayout? buildWordSearchLayout(List<String> rawWords) {
  final words = [for (final w in rawWords) normalizeGridWord(w)];
  if (words.isEmpty || words.any((w) => w.length > gridMaxSize)) return null;
  final random = Random(_seedOf(words));
  final longest = words.fold<int>(0, (m, w) => max(m, w.length));
  final letters = words.fold<int>(0, (s, w) => s + w.length);
  var size = max(8, max(longest, sqrt(letters * 2.2).ceil())).clamp(6, gridMaxSize);
  const dirs = [(0, 1), (1, 0), (1, 1), (-1, 1)];
  final order = List<int>.generate(words.length, (i) => i)
    ..sort((a, b) => words[b].length.compareTo(words[a].length));

  for (var attempt = 0; attempt < 90; attempt++) {
    if (attempt > 0 && attempt % 30 == 0 && size < gridMaxSize) size++;
    final grid = List.generate(size, (_) => List<String?>.filled(size, null));
    final positions = List<List<int>>.filled(words.length, const []);
    var ok = true;
    for (final i in order) {
      final w = words[i];
      var placed = false;
      for (var t = 0; t < 400 && !placed; t++) {
        final (dr, dc) = dirs[random.nextInt(dirs.length)];
        final r0 = random.nextInt(size);
        final c0 = random.nextInt(size);
        final r1 = r0 + dr * (w.length - 1);
        final c1 = c0 + dc * (w.length - 1);
        if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size) continue;
        var fits = true;
        for (var k = 0; k < w.length && fits; k++) {
          final cell = grid[r0 + dr * k][c0 + dc * k];
          if (cell != null && cell != w[k]) fits = false;
        }
        if (!fits) continue;
        for (var k = 0; k < w.length; k++) {
          grid[r0 + dr * k][c0 + dc * k] = w[k];
        }
        positions[i] = [r0, c0, r1, c1];
        placed = true;
      }
      if (!placed) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    return WordSearchLayout(
      size: size,
      grid: [
        for (final row in grid)
          row
              .map((ch) => ch ?? _fillLetters[random.nextInt(_fillLetters.length)])
              .join(),
      ],
      words: words,
      positions: positions,
    );
  }
  return null;
}

/// Monta a questão de caça-palavras; `null` se não couber.
Question? buildWordSearchQuestion({
  String id = '',
  required String text,
  required List<String> words,
  String explanation = '',
  int? timeLimitS,
}) {
  final layout = buildWordSearchLayout(words);
  if (layout == null) return null;
  return Question(
    id: id,
    text: text.trim(),
    options: const [],
    correctAnswer: 0,
    explanation: explanation.trim(),
    type: QuestionType.wordSearch,
    timeLimitS: timeLimitS,
    content: {
      'rows': layout.size,
      'cols': layout.size,
      'grid': layout.grid,
      'words': layout.words,
    },
    answer: {'positions': layout.positions},
  );
}

/// Letras de (r1, c1) até (r2, c2) em linha reta; `null` se não for reta
/// ou sair da grade. Mesma leitura do servidor (grid_line).
String? gridLine(List<String> grid, int r1, int c1, int r2, int c2) {
  if (grid.isEmpty) return null;
  final rows = grid.length;
  final cols = grid.first.length;
  if ([r1, c1, r2, c2].any((v) => v < 0) ||
      max(r1, r2) >= rows ||
      max(c1, c2) >= cols) {
    return null;
  }
  if (!(r1 == r2 || c1 == c2 || (r2 - r1).abs() == (c2 - c1).abs())) {
    return null;
  }
  final dr = (r2 - r1).sign;
  final dc = (c2 - c1).sign;
  final n = max((r2 - r1).abs(), (c2 - c1).abs());
  return [for (var k = 0; k <= n; k++) grid[r1 + k * dr][c1 + k * dc]].join();
}

/// O texto do professor com as respostas entre colchetes, já separado.
class BlankTemplate {
  const BlankTemplate(this.parts, this.answers);

  /// Trechos entre as lacunas (um a mais que [answers]).
  final List<String> parts;

  /// As palavras certas, na ordem das lacunas.
  final List<String> answers;
}

final _bracket = RegExp(r'\[([^\[\]]*)\]');

/// Separa "O Brasil foi descoberto em [1500] por [Cabral]." em trechos e
/// respostas. `null` se os colchetes não fecham (ver [validateFillBlanks]).
BlankTemplate? parseBlankTemplate(String template) {
  final parts = <String>[];
  final answers = <String>[];
  var last = 0;
  for (final m in _bracket.allMatches(template)) {
    parts.add(template.substring(last, m.start));
    answers.add(m.group(1)!.trim());
    last = m.end;
  }
  parts.add(template.substring(last));
  // Sobrou colchete solto (aberto sem fechar, ou fechado sem abrir).
  if (parts.any((p) => p.contains('[') || p.contains(']'))) return null;
  return BlankTemplate(parts, answers);
}

/// Por que as lacunas não podem ser salvas (`null` = podem). Mesmas regras
/// do banco, e um distrator não pode ser igual a uma resposta (valeria como
/// certo).
String? validateFillBlanks(String template, List<String> distractors) {
  final parsed = parseBlankTemplate(template);
  if (parsed == null) {
    return 'Feche cada colchete: [palavra].';
  }
  if (parsed.answers.isEmpty) {
    return 'Coloque entre colchetes as palavras que o aluno vai completar.';
  }
  if (parsed.answers.length > blanksMax) {
    return 'Use no máximo $blanksMax lacunas.';
  }
  if (parsed.answers.any((a) => a.isEmpty)) {
    return 'Há colchetes vazios: escreva a palavra dentro deles.';
  }
  if (parsed.parts.fold<int>(0, (s, p) => s + p.length) > blankTextMaxChars) {
    return 'O texto pode ter até $blankTextMaxChars caracteres.';
  }
  final words = [...parsed.answers, ...distractors.map((d) => d.trim())];
  if (words.any((w) => w.length > blankWordMaxChars)) {
    return 'Cada palavra pode ter até $blankWordMaxChars caracteres.';
  }
  final extra = distractors.where((d) => d.trim().isNotEmpty).toList();
  if (extra.length > blankDistractorsMax) {
    return 'Use no máximo $blankDistractorsMax palavras extras.';
  }
  final answers = {for (final a in parsed.answers) a.toLowerCase()};
  for (final d in extra) {
    if (answers.contains(d.trim().toLowerCase())) {
      return 'A palavra extra "${d.trim()}" também é resposta: troque por '
          'outra.';
    }
  }
  return null;
}

/// Monta uma questão de completar lacunas: o banco reúne as respostas e
/// as palavras extras (distratores), embaralhado.
Question buildFillBlanksQuestion({
  String id = '',
  required String text,
  required String template,
  List<String> distractors = const [],
  String explanation = '',
  int? timeLimitS,
  String? imageUrl,
  String? imageAuthor,
  String? imageSource,
  Random? random,
}) {
  final parsed = parseBlankTemplate(template)!;
  final words = [
    ...parsed.answers,
    for (final d in distractors)
      if (d.trim().isNotEmpty) d.trim(),
  ];
  final perm = _shuffledNotIdentity(words.length, random ?? Random());
  // Banco na posição p mostra words[perm[p]]; a resposta k está em
  // perm.indexOf(k).
  final bank = [for (final i in perm) words[i]];
  final blanks = [for (var k = 0; k < parsed.answers.length; k++) perm.indexOf(k)];
  return Question(
    id: id,
    text: text.trim(),
    options: const [],
    correctAnswer: 0,
    explanation: explanation.trim(),
    type: QuestionType.fillBlanks,
    imageUrl: imageUrl,
    imageAuthor: imageAuthor,
    imageSource: imageSource,
    timeLimitS: timeLimitS,
    content: {'parts': parsed.parts, 'bank': bank},
    answer: {'blanks': blanks},
  );
}

/// Monta uma questão de ligar colunas a partir dos pares do professor,
/// embaralhando a direita (nunca na mesma ordem dos pares).
Question buildMatchQuestion({
  String id = '',
  required String text,
  required List<MatchPair> pairs,
  String explanation = '',
  int? timeLimitS,
  String? imageUrl,
  String? imageAuthor,
  String? imageSource,
  Random? random,
}) {
  final n = pairs.length;
  final perm = _shuffledNotIdentity(n, random ?? Random());
  // A direita na posição p mostra o par perm[p]; logo o par i está em
  // p = perm.indexOf(i).
  final right = [for (final i in perm) pairs[i].right.trim()];
  final match = [for (var i = 0; i < n; i++) perm.indexOf(i)];
  return Question(
    id: id,
    text: text.trim(),
    options: const [],
    correctAnswer: 0,
    explanation: explanation.trim(),
    type: QuestionType.matchColumns,
    imageUrl: imageUrl,
    imageAuthor: imageAuthor,
    imageSource: imageSource,
    timeLimitS: timeLimitS,
    content: {
      'left': [for (final p in pairs) p.left.trim()],
      'right': right,
    },
    answer: {'match': match},
  );
}

/// Monta uma questão de ordenar a partir dos itens na ordem certa,
/// embaralhando (nunca já na ordem certa).
Question buildOrderingQuestion({
  String id = '',
  required String text,
  required List<String> orderedItems,
  String explanation = '',
  int? timeLimitS,
  String? imageUrl,
  String? imageAuthor,
  String? imageSource,
  Random? random,
}) {
  final n = orderedItems.length;
  final perm = _shuffledNotIdentity(n, random ?? Random());
  // Posição p mostra o item perm[p]; o k-ésimo certo está em perm.indexOf(k).
  final items = [for (final k in perm) orderedItems[k].trim()];
  final order = [for (var k = 0; k < n; k++) perm.indexOf(k)];
  return Question(
    id: id,
    text: text.trim(),
    options: const [],
    correctAnswer: 0,
    explanation: explanation.trim(),
    type: QuestionType.ordering,
    imageUrl: imageUrl,
    imageAuthor: imageAuthor,
    imageSource: imageSource,
    timeLimitS: timeLimitS,
    content: {'items': items},
    answer: {'order': order},
  );
}

/// Por que os pares não podem ser salvos (`null` = podem). Mesmas regras
/// do banco.
String? validateMatchPairs(List<MatchPair> pairs) {
  if (pairs.length < matchMinPairs || pairs.length > matchMaxPairs) {
    return 'Use de $matchMinPairs a $matchMaxPairs pares.';
  }
  return _validateTexts([for (final p in pairs) p.left], 'da coluna da esquerda') ??
      _validateTexts([for (final p in pairs) p.right], 'da coluna da direita');
}

/// Por que os itens não podem ser salvos (`null` = podem).
String? validateOrderingItems(List<String> items) {
  if (items.length < orderingMinItems || items.length > orderingMaxItems) {
    return 'Use de $orderingMinItems a $orderingMaxItems itens.';
  }
  return _validateTexts(items, 'da lista');
}

String? _validateTexts(List<String> texts, String where) {
  if (texts.any((t) => t.trim().isEmpty)) {
    return 'Preencha todos os itens $where.';
  }
  if (texts.any((t) => t.trim().length > kindItemMaxChars)) {
    return 'Cada item pode ter até $kindItemMaxChars caracteres.';
  }
  final seen = <String>{};
  for (final t in texts) {
    if (!seen.add(t.trim().toLowerCase())) {
      return 'Há itens repetidos $where: "${t.trim()}".';
    }
  }
  return null;
}

/// Ordenar: posições em que o aluno deixou o item certo — cada uma vale
/// sozinha, sem depender dos vizinhos (a nota do servidor é acertos / n).
/// [order]: o que o aluno deixou; [key]: o gabarito.
Set<int> orderingKeptPositions(List<int> order, List<int> key) {
  if (order.isEmpty || key.length != order.length) return const {};
  return {
    for (var p = 0; p < order.length; p++)
      if (order[p] == key[p]) p,
  };
}

/// A nota do servidor para ordenar (só para mostrar e testar).
double orderingScore(List<int> order, List<int> key) {
  if (order.isEmpty || key.length != order.length) return 0;
  return orderingKeptPositions(order, key).length / order.length;
}

List<int> _shuffledNotIdentity(int n, Random random) {
  final perm = List<int>.generate(n, (i) => i);
  if (n < 2) return perm;
  do {
    perm.shuffle(random);
  } while (_isIdentity(perm));
  return perm;
}

bool _isIdentity(List<int> perm) {
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) return false;
  }
  return true;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

List<String> _strings(Object? value) =>
    value is List ? [for (final v in value) '$v'] : const [];

List<int>? _ints(Object? value) => value is List
    ? [for (final v in value) v is num ? v.toInt() : int.tryParse('$v') ?? -1]
    : null;
