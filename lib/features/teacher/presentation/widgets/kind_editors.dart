import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question.dart';
import '../../../lesson/domain/entities/question_kinds.dart';
import 'classroom_palette.dart';

/// Tipos que o professor escolhe ao criar (ENEM e verdadeiro/falso ficam
/// de fora: vêm de outros caminhos).
const authorableTypes = [
  QuestionType.multipleChoice,
  QuestionType.matchColumns,
  QuestionType.ordering,
  QuestionType.fillBlanks,
  QuestionType.crossword,
  QuestionType.wordSearch,
];

IconData questionTypeIcon(QuestionType type) => switch (type) {
      QuestionType.matchColumns => Icons.cable_rounded,
      QuestionType.ordering => Icons.format_list_numbered_rounded,
      QuestionType.fillBlanks => Icons.edit_note_rounded,
      QuestionType.crossword => Icons.grid_on_rounded,
      QuestionType.wordSearch => Icons.manage_search_rounded,
      _ => Icons.radio_button_checked_rounded,
    };

/// Escolha do tipo da questão.
class QuestionTypeSelector extends StatelessWidget {
  const QuestionTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final QuestionType value;
  final ValueChanged<QuestionType>? onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in authorableTypes)
          ChoiceChip(
            avatar: Icon(
              questionTypeIcon(type),
              size: 16,
              color: value == type ? accent : ClassroomPalette.textMuted,
            ),
            label: Text(type.label),
            selected: value == type,
            showCheckmark: false,
            // Compacto: os três cabem numa linha no celular.
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.only(left: 2, right: 6),
            selectedColor: accent.withValues(alpha: 0.16),
            side: BorderSide(
              color: value == type ? accent : ClassroomPalette.textMuted.withValues(alpha: 0.4),
            ),
            labelStyle: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: value == type ? accent : ClassroomPalette.textMuted,
            ),
            onSelected: onChanged == null ? null : (_) => onChanged!(type),
          ),
      ],
    );
  }
}

// ─── Ligar colunas ───────────────────────────────────────────────────────────

/// Pares em edição. Os controladores ficam com a tela (não se perdem ao
/// reconstruir); [dispose] quando a tela sai.
class MatchPairsDraft {
  MatchPairsDraft([List<MatchPair>? pairs]) {
    final initial = pairs == null || pairs.isEmpty
        ? List.filled(matchMinPairs, const MatchPair('', ''))
        : pairs;
    for (final p in initial) {
      _rows.add((TextEditingController(text: p.left), TextEditingController(text: p.right)));
    }
  }

  final _rows = <(TextEditingController, TextEditingController)>[];

  int get length => _rows.length;
  bool get canAdd => _rows.length < matchMaxPairs;
  bool get canRemove => _rows.length > matchMinPairs;

  List<MatchPair> get pairs =>
      [for (final (l, r) in _rows) MatchPair(l.text.trim(), r.text.trim())];

  /// Por que ainda não dá para salvar (`null` = pode).
  String? get problem => validateMatchPairs(pairs);

  void add() {
    if (canAdd) _rows.add((TextEditingController(), TextEditingController()));
  }

  void removeAt(int i) {
    if (!canRemove) return;
    final (l, r) = _rows.removeAt(i);
    l.dispose();
    r.dispose();
  }

  void dispose() {
    for (final (l, r) in _rows) {
      l.dispose();
      r.dispose();
    }
  }
}

class MatchPairsEditor extends StatelessWidget {
  const MatchPairsEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final MatchPairsDraft draft;
  final VoidCallback onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva cada par na mesma linha. O app embaralha a coluna da '
          'direita para o aluno.',
          style: GoogleFonts.nunito(fontSize: 11, color: ClassroomPalette.textMuted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < draft.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _KindField(
                    controller: draft._rows[i].$1,
                    hint: 'Item ${i + 1}',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.cable_rounded, size: 18, color: accent),
                ),
                Expanded(
                  child: _KindField(
                    controller: draft._rows[i].$2,
                    hint: 'Par do item ${i + 1}',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover par',
                  visualDensity: VisualDensity.compact,
                  onPressed: draft.canRemove
                      ? () {
                          draft.removeAt(i);
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (draft.canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.add();
                onChanged();
              },
              icon: Icon(Icons.add_rounded, size: 18, color: accent),
              label: Text(
                'Adicionar par',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Ordenar ─────────────────────────────────────────────────────────────────

/// Itens em edição, já na ordem certa.
class OrderingDraft {
  OrderingDraft([List<String>? items]) {
    final initial = items == null || items.isEmpty
        ? List.filled(orderingMinItems, '')
        : items;
    for (final t in initial) {
      _items.add(TextEditingController(text: t));
    }
  }

  final _items = <TextEditingController>[];

  int get length => _items.length;
  bool get canAdd => _items.length < orderingMaxItems;
  bool get canRemove => _items.length > orderingMinItems;

  List<String> get items => [for (final c in _items) c.text.trim()];

  String? get problem => validateOrderingItems(items);

  void add() {
    if (canAdd) _items.add(TextEditingController());
  }

  void removeAt(int i) {
    if (canRemove) _items.removeAt(i).dispose();
  }

  void move(int from, int to) {
    if (to < 0 || to >= _items.length) return;
    _items.insert(to, _items.removeAt(from));
  }

  void dispose() {
    for (final c in _items) {
      c.dispose();
    }
  }
}

class OrderingItemsEditor extends StatelessWidget {
  const OrderingItemsEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final OrderingDraft draft;
  final VoidCallback onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva os itens já na ordem certa. O app embaralha para o aluno.',
          style: GoogleFonts.nunito(fontSize: 11, color: ClassroomPalette.textMuted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < draft.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KindField(
                    controller: draft._items[i],
                    hint: '${i + 1}º item',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Subir',
                  visualDensity: VisualDensity.compact,
                  onPressed: i == 0
                      ? null
                      : () {
                          draft.move(i, i - 1);
                          onChanged();
                        },
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Descer',
                  visualDensity: VisualDensity.compact,
                  onPressed: i == draft.length - 1
                      ? null
                      : () {
                          draft.move(i, i + 1);
                          onChanged();
                        },
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Remover item',
                  visualDensity: VisualDensity.compact,
                  onPressed: draft.canRemove
                      ? () {
                          draft.removeAt(i);
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (draft.canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.add();
                onChanged();
              },
              icon: Icon(Icons.add_rounded, size: 18, color: accent),
              label: Text(
                'Adicionar item',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Completar lacunas ───────────────────────────────────────────────────────

/// Texto com as respostas entre colchetes + palavras extras (distratores).
class FillBlanksDraft {
  FillBlanksDraft([String template = '', List<String>? distractors])
      : templateCtrl = TextEditingController(text: template) {
    for (final d in distractors ?? const <String>[]) {
      _extras.add(TextEditingController(text: d));
    }
  }

  final TextEditingController templateCtrl;
  final _extras = <TextEditingController>[];

  String get template => templateCtrl.text;
  List<String> get distractors => [
        for (final c in _extras)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ];

  /// Quantas lacunas o texto tem (0 se os colchetes não fecham).
  int get blankCount => parseBlankTemplate(template)?.answers.length ?? 0;

  bool get canAddExtra => _extras.length < blankDistractorsMax;

  String? get problem => validateFillBlanks(template, distractors);

  void addExtra() {
    if (canAddExtra) _extras.add(TextEditingController());
  }

  void removeExtraAt(int i) => _extras.removeAt(i).dispose();

  void dispose() {
    templateCtrl.dispose();
    for (final c in _extras) {
      c.dispose();
    }
  }
}

class FillBlanksEditor extends StatelessWidget {
  const FillBlanksEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final FillBlanksDraft draft;
  final VoidCallback onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = draft.blankCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva o texto e coloque entre colchetes as palavras que o aluno '
          'vai completar. O app tira as palavras do texto e mostra num banco '
          'embaralhado.',
          style: GoogleFonts.nunito(fontSize: 11, color: ClassroomPalette.textMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: draft.templateCtrl,
          onChanged: (_) => onChanged(),
          minLines: 2,
          maxLines: 6,
          maxLength: blankTextMaxChars,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ClassroomPalette.primaryText(isDark),
          ),
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: 'O Brasil foi descoberto em [1500] por [Cabral].',
            counterText: '',
            hintStyle: GoogleFonts.nunito(fontSize: 13, color: ClassroomPalette.textMuted),
            filled: true,
            fillColor: ClassroomPalette.fieldFill(isDark),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accent, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count == 0
              ? 'Nenhuma lacuna ainda.'
              : '$count lacuna${count == 1 ? '' : 's'}',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: count == 0 ? ClassroomPalette.textMuted : accent,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PALAVRAS EXTRAS (OPCIONAL) · aparecem no banco para confundir',
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ClassroomPalette.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < draft._extras.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _KindField(
                    controller: draft._extras[i],
                    hint: 'Palavra extra ${i + 1}',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                    maxChars: blankWordMaxChars,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover palavra extra',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    draft.removeExtraAt(i);
                    onChanged();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (draft.canAddExtra)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.addExtra();
                onChanged();
              },
              icon: Icon(Icons.add_rounded, size: 18, color: accent),
              label: Text(
                'Adicionar palavra extra',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Cruzadinha ──────────────────────────────────────────────────────────────

/// Palavras e dicas em edição; a grade é montada na hora (a mesma lista
/// sempre dá a mesma grade, então a prévia é o que vai salvo).
class CrosswordDraft {
  CrosswordDraft([List<CrosswordEntry>? entries]) {
    final initial = entries == null || entries.isEmpty
        ? List.filled(crosswordMinWords, const CrosswordEntry('', ''))
        : entries;
    for (final e in initial) {
      _rows.add((TextEditingController(text: e.word), TextEditingController(text: e.clue)));
    }
  }

  final _rows = <(TextEditingController, TextEditingController)>[];
  String? _cacheKey;
  CrosswordLayout? _cache;

  int get length => _rows.length;
  bool get canAdd => _rows.length < crosswordMaxWords;
  bool get canRemove => _rows.length > crosswordMinWords;

  List<CrosswordEntry> get entries => [
        for (final (w, c) in _rows) CrosswordEntry(w.text.trim(), c.text.trim()),
      ];

  /// Grade montada (`null` enquanto a lista não é válida ou não cabe).
  CrosswordLayout? get layout {
    final list = entries;
    if (validateCrossword(list) != null) return null;
    final key = [for (final e in list) '${e.word}|${e.clue}'].join('\u0001');
    if (key != _cacheKey) {
      _cacheKey = key;
      _cache = buildCrosswordLayout(list);
    }
    return _cache;
  }

  String? get problem {
    final invalid = validateCrossword(entries);
    if (invalid != null) return invalid;
    final l = layout;
    if (l == null) {
      return 'As palavras não couberam numa grade de 15×15: use palavras '
          'menores ou menos palavras.';
    }
    if (l.unplaced.isNotEmpty) {
      return 'Não consegui encaixar: ${l.unplaced.join(', ')}. Troque ou '
          'remova.';
    }
    return null;
  }

  void add() {
    if (canAdd) _rows.add((TextEditingController(), TextEditingController()));
  }

  void removeAt(int i) {
    if (!canRemove) return;
    final (w, c) = _rows.removeAt(i);
    w.dispose();
    c.dispose();
  }

  void dispose() {
    for (final (w, c) in _rows) {
      w.dispose();
      c.dispose();
    }
  }
}

class CrosswordEditor extends StatelessWidget {
  const CrosswordEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final CrosswordDraft draft;
  final VoidCallback onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = draft.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva cada palavra e a dica dela. O app monta a grade (acentos '
          'e espaços saem: "São Paulo" vira SAOPAULO).',
          style: GoogleFonts.nunito(fontSize: 11, color: ClassroomPalette.textMuted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < draft.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _KindField(
                    controller: draft._rows[i].$1,
                    hint: 'Palavra ${i + 1}',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                    maxChars: 30,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: _KindField(
                    controller: draft._rows[i].$2,
                    hint: 'Dica',
                    isDark: isDark,
                    accent: accent,
                    onChanged: onChanged,
                    maxChars: crosswordClueMaxChars,
                  ),
                ),
                IconButton(
                  tooltip: 'Remover palavra',
                  visualDensity: VisualDensity.compact,
                  onPressed: draft.canRemove
                      ? () {
                          draft.removeAt(i);
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (draft.canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.add();
                onChanged();
              },
              icon: Icon(Icons.add_rounded, size: 18, color: accent),
              label: Text(
                'Adicionar palavra',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ),
        if (layout != null && layout.unplaced.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'PRÉVIA · grade de ${layout.rows}×${layout.cols}',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ClassroomPalette.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          GridPreview.crossword(layout.rows, layout.cols, layout.slots, layout.words),
        ],
      ],
    );
  }
}

// ─── Caça-palavras ───────────────────────────────────────────────────────────

class WordSearchDraft {
  WordSearchDraft([List<String>? words]) {
    final initial = words == null || words.isEmpty
        ? List.filled(wordSearchMinWords, '')
        : words;
    for (final w in initial) {
      _words.add(TextEditingController(text: w));
    }
  }

  final _words = <TextEditingController>[];
  String? _cacheKey;
  WordSearchLayout? _cache;

  int get length => _words.length;
  bool get canAdd => _words.length < wordSearchMaxWords;
  bool get canRemove => _words.length > wordSearchMinWords;

  List<String> get words => [for (final c in _words) c.text.trim()];

  WordSearchLayout? get layout {
    final list = words;
    if (validateWordSearch(list) != null) return null;
    final key = list.join('\u0001');
    if (key != _cacheKey) {
      _cacheKey = key;
      _cache = buildWordSearchLayout(list);
    }
    return _cache;
  }

  String? get problem =>
      validateWordSearch(words) ??
      (layout == null ? 'As palavras não couberam numa grade de 15×15.' : null);

  void add() {
    if (canAdd) _words.add(TextEditingController());
  }

  void removeAt(int i) {
    if (canRemove) _words.removeAt(i).dispose();
  }

  void dispose() {
    for (final c in _words) {
      c.dispose();
    }
  }
}

class WordSearchEditor extends StatelessWidget {
  const WordSearchEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final WordSearchDraft draft;
  final VoidCallback onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layout = draft.layout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Escreva as palavras que o aluno vai procurar. O app monta a grade '
          '(→ ↓ ↘ ↗) e completa com letras aleatórias.',
          style: GoogleFonts.nunito(fontSize: 11, color: ClassroomPalette.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < draft.length; i++)
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: _KindField(
                        controller: draft._words[i],
                        hint: 'Palavra ${i + 1}',
                        isDark: isDark,
                        accent: accent,
                        onChanged: onChanged,
                        maxChars: 30,
                      ),
                    ),
                    if (draft.canRemove)
                      IconButton(
                        tooltip: 'Remover palavra',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          draft.removeAt(i);
                          onChanged();
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (draft.canAdd)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                draft.add();
                onChanged();
              },
              icon: Icon(Icons.add_rounded, size: 18, color: accent),
              label: Text(
                'Adicionar palavra',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ),
        if (layout != null) ...[
          const SizedBox(height: 8),
          Text(
            'PRÉVIA · grade de ${layout.size}×${layout.size}',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ClassroomPalette.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          GridPreview.wordSearch(layout.grid, layout.positions),
        ],
      ],
    );
  }
}

/// Grade pequena para o professor: a cruzadinha com as respostas, ou o
/// caça-palavras com as palavras destacadas.
class GridPreview extends StatelessWidget {
  GridPreview.crossword(this.rows, this.cols, List<CrosswordSlot> slots, List<String> words, {super.key})
      : letters = {
          for (var i = 0; i < slots.length && i < words.length; i++)
            for (var k = 0; k < slots[i].len && k < words[i].length; k++)
              slots[i].cell(k): words[i][k],
        },
        numbers = {for (final s in slots) (s.row, s.col): s.num},
        highlight = const {};

  GridPreview.wordSearch(List<String> grid, List<List<int>> positions, {super.key})
      : rows = grid.length,
        cols = grid.isEmpty ? 0 : grid.first.length,
        letters = {
          for (var r = 0; r < grid.length; r++)
            for (var c = 0; c < grid[r].length; c++) (r, c): grid[r][c],
        },
        numbers = const {},
        highlight = {
          for (final p in positions)
            if (p.length == 4)
              for (var k = 0; k <= max((p[2] - p[0]).abs(), (p[3] - p[1]).abs()); k++)
                (p[0] + k * (p[2] - p[0]).sign, p[1] + k * (p[3] - p[1]).sign),
        };

  final int rows;
  final int cols;
  final Map<(int, int), String> letters;
  final Map<(int, int), int> numbers;
  final Set<(int, int)> highlight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crossword = numbers.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth / max(cols, 1)).clamp(10.0, 22.0).floorToDouble();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var c = 0; c < cols; c++)
                      if (letters[(r, c)] case final letter?)
                        Container(
                          width: size,
                          height: size,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: highlight.contains((r, c))
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
                                : (crossword
                                    ? (isDark ? AppColors.surfaceDark : Colors.white)
                                    : null),
                            border: crossword
                                ? Border.all(
                                    color: isDark ? Colors.white30 : Colors.black26,
                                    width: 0.6,
                                  )
                                : null,
                          ),
                          child: Text(
                            letter,
                            style: GoogleFonts.nunito(
                              fontSize: size * 0.55,
                              fontWeight: FontWeight.w800,
                              color: ClassroomPalette.primaryText(isDark),
                            ),
                          ),
                        )
                      else
                        SizedBox(width: size, height: size),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Cruzadinha para o professor: a grade com as respostas e as dicas.
class CrosswordView extends StatelessWidget {
  const CrosswordView({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slots = question.crosswordSlots;
    final words = question.crosswordWords;
    final style = GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ClassroomPalette.primaryText(isDark),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridPreview.crossword(question.gridRows, question.gridCols, slots, words),
        const SizedBox(height: 10),
        for (var i = 0; i < slots.length && i < words.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                style: style,
                children: [
                  TextSpan(
                    text: '${slots[i].num} ${slots[i].across ? '→' : '↓'}  ',
                    style: style.copyWith(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: '${slots[i].clue}  '),
                  TextSpan(
                    text: words[i],
                    style: style.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Caça-palavras para o professor: a grade com as palavras destacadas.
class WordSearchView extends StatelessWidget {
  const WordSearchView({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridPreview.wordSearch(question.wordSearchGrid, question.wordSearchPositions),
        const SizedBox(height: 10),
        Text(
          question.wordSearchWords.join(' · '),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}

class _KindField extends StatelessWidget {
  const _KindField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.accent,
    required this.onChanged,
    this.maxChars = kindItemMaxChars,
  });

  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final Color accent;
  final VoidCallback onChanged;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      maxLength: maxChars,
      minLines: 1,
      maxLines: 3,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ClassroomPalette.primaryText(isDark),
      ),
      cursorColor: accent,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        isDense: true,
        hintStyle: GoogleFonts.nunito(fontSize: 13, color: ClassroomPalette.textMuted),
        filled: true,
        fillColor: ClassroomPalette.fieldFill(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      ),
    );
  }
}

// ─── Visualização (professor) ────────────────────────────────────────────────

/// Pares da questão de ligar, como o professor escreveu.
class MatchPairsView extends StatelessWidget {
  const MatchPairsView({super.key, required this.pairs});

  final List<MatchPair> pairs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: ClassroomPalette.primaryText(isDark),
    );
    return Column(
      children: [
        for (final p in pairs)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ClassroomPalette.fieldFill(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClassroomPalette.border(isDark)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(p.left, style: style)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.cable_rounded, size: 16, color: Color(0xFF4CAF50)),
                ),
                Expanded(
                  child: Text(p.right, style: style, textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Itens da questão de ordenar, na ordem certa.
class OrderedItemsView extends StatelessWidget {
  const OrderedItemsView({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ClassroomPalette.fieldFill(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ClassroomPalette.border(isDark)),
            ),
            child: Row(
              children: [
                Text(
                  '${i + 1}.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ClassroomPalette.primaryText(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Texto com as lacunas preenchidas pelas respostas (em verde) e as
/// palavras extras.
class FillBlanksView extends StatelessWidget {
  const FillBlanksView({super.key, required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parts = question.blankParts;
    final answers = question.blankAnswers;
    final extras = question.blankDistractors;
    final base = GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: ClassroomPalette.primaryText(isDark),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClassroomPalette.fieldFill(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: base,
              children: [
                for (var k = 0; k < parts.length; k++) ...[
                  TextSpan(text: parts[k]),
                  if (k < answers.length)
                    TextSpan(
                      text: '[${answers[k]}]',
                      style: base.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Palavras extras: ${extras.join(' · ')}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ClassroomPalette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Visualização do professor conforme o tipo (pares, ordem ou lacunas);
/// `null` na múltipla escolha (cada tela mostra as alternativas do seu
/// jeito).
Widget? questionKindView(Question q) => switch (q.type) {
      QuestionType.matchColumns => MatchPairsView(pairs: q.matchPairs),
      QuestionType.ordering => OrderedItemsView(items: q.orderedItems),
      QuestionType.fillBlanks => FillBlanksView(question: q),
      QuestionType.crossword => CrosswordView(question: q),
      QuestionType.wordSearch => WordSearchView(question: q),
      _ => null,
    };
