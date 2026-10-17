import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

/// Cruzadinha: toque numa dica (ou numa casa) e escreva a palavra inteira.
/// As casas são compartilhadas: a letra escrita numa palavra aparece na
/// palavra que a cruza.
///
/// [words] é a resposta em montagem, uma por palavra da grade (espaço =
/// casa vazia). Com [onChanged] `null` a resposta está travada e, se vier
/// [reveal] (as palavras certas), cada casa mostra a letra certa — verde
/// se o aluno acertou a casa, vermelha se não.
class CrosswordBoard extends StatefulWidget {
  const CrosswordBoard({
    super.key,
    required this.rows,
    required this.cols,
    required this.slots,
    required this.words,
    this.onChanged,
    this.reveal,
  });

  final int rows;
  final int cols;
  final List<CrosswordSlot> slots;
  final List<String> words;
  final ValueChanged<List<String>>? onChanged;
  final List<String>? reveal;

  static const rightColor = Color(0xFF4CAF50);

  @override
  State<CrosswordBoard> createState() => _CrosswordBoardState();
}

class _CrosswordBoardState extends State<CrosswordBoard> {
  int? _selected;
  final _input = TextEditingController();
  final _focus = FocusNode();

  bool get _locked => widget.onChanged == null;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Letras do aluno em cada casa.
  Map<(int, int), String> get _cells {
    final cells = <(int, int), String>{};
    for (var i = 0; i < widget.slots.length; i++) {
      final s = widget.slots[i];
      final w = i < widget.words.length ? widget.words[i] : '';
      for (var k = 0; k < s.len && k < w.length; k++) {
        if (w[k] != ' ') cells[s.cell(k)] = w[k];
      }
    }
    return cells;
  }

  /// Letras certas em cada casa (depois de travar).
  Map<(int, int), String> get _rightCells {
    final cells = <(int, int), String>{};
    final reveal = widget.reveal;
    if (reveal == null) return cells;
    for (var i = 0; i < widget.slots.length && i < reveal.length; i++) {
      final s = widget.slots[i];
      for (var k = 0; k < s.len && k < reveal[i].length; k++) {
        cells[s.cell(k)] = reveal[i][k];
      }
    }
    return cells;
  }

  String _wordOf(int i, Map<(int, int), String> cells) {
    final s = widget.slots[i];
    return [for (var k = 0; k < s.len; k++) cells[s.cell(k)] ?? ' '].join();
  }

  void _select(int i) {
    if (_locked) return;
    final word = _wordOf(i, _cells);
    setState(() {
      _selected = i;
      _input.text = word.contains(' ') ? '' : word;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
    _focus.requestFocus();
  }

  void _tapCell((int, int) cell) {
    final containing = [
      for (var i = 0; i < widget.slots.length; i++)
        if (List.generate(widget.slots[i].len, widget.slots[i].cell).contains(cell)) i,
    ];
    if (containing.isEmpty) return;
    final current = _selected;
    final next = current != null && containing.contains(current) && containing.length > 1
        ? containing.firstWhere((i) => i != current)
        : containing.first;
    _select(next);
  }

  void _commit() {
    final i = _selected;
    if (i == null || _locked) return;
    final s = widget.slots[i];
    final typed = normalizeGridWord(_input.text);
    final cells = _cells;
    for (var k = 0; k < s.len && k < typed.length; k++) {
      cells[s.cell(k)] = typed[k];
    }
    widget.onChanged!([for (var j = 0; j < widget.slots.length; j++) _wordOf(j, cells)]);
    // Vai para a próxima palavra ainda incompleta.
    final order = [
      for (var j = 1; j <= widget.slots.length; j++) (i + j) % widget.slots.length,
    ];
    final next = order.where((j) => _wordOf(j, cells).contains(' ')).firstOrNull;
    if (next == null) {
      setState(() => _selected = null);
      _focus.unfocus();
    } else {
      _select(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cells = _cells;
    final right = _rightCells;
    final numbers = {for (final s in widget.slots) (s.row, s.col): s.num};
    final active = {
      for (final s in widget.slots) ...List.generate(s.len, s.cell),
    };
    final selectedCells = _selected == null
        ? const <(int, int)>{}
        : List.generate(widget.slots[_selected!].len, widget.slots[_selected!].cell).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth / widget.cols).clamp(14.0, 36.0).floorToDouble();
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < widget.rows; r++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < widget.cols; c++)
                          active.contains((r, c))
                              ? _cell(
                                  size: size,
                                  letter: right[(r, c)] ?? cells[(r, c)],
                                  number: numbers[(r, c)],
                                  selected: selectedCells.contains((r, c)),
                                  result: right.isEmpty
                                      ? null
                                      : cells[(r, c)] == right[(r, c)],
                                  isDark: isDark,
                                  onTap: () => _tapCell((r, c)),
                                )
                              : SizedBox(width: size, height: size),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        if (!_locked && _selected != null) ...[
          const SizedBox(height: 14),
          _InputBar(
            slot: widget.slots[_selected!],
            controller: _input,
            focus: _focus,
            onSubmit: _commit,
          ),
        ],
        const SizedBox(height: 16),
        for (final across in [true, false])
          if (widget.slots.any((s) => s.across == across)) ...[
            Text(
              across ? 'Horizontais' : 'Verticais',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < widget.slots.length; i++)
              if (widget.slots[i].across == across) _clue(i, cells, isDark),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _cell({
    required double size,
    required String? letter,
    required int? number,
    required bool selected,
    required bool? result,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final color = result == null
        ? (selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : (isDark ? AppColors.surfaceDark : Colors.white))
        : (result ? CrosswordBoard.rightColor : AppColors.error).withValues(alpha: 0.22);
    return GestureDetector(
      onTap: _locked ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black45),
            width: selected ? 1.6 : 0.8,
          ),
        ),
        child: Stack(
          children: [
            if (number != null)
              Positioned(
                left: 2,
                top: 1,
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: size * 0.26,
                    height: 1,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            Center(
              child: Text(
                letter ?? '',
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w800,
                  color: result == null
                      ? (isDark ? AppColors.textOnDark : AppColors.textPrimary)
                      : (result ? CrosswordBoard.rightColor : AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clue(int i, Map<(int, int), String> cells, bool isDark) {
    final s = widget.slots[i];
    final reveal = widget.reveal;
    final ok = reveal == null || i >= reveal.length
        ? null
        : _wordOf(i, cells) == reveal[i];
    final selected = _selected == i;
    return InkWell(
      onTap: _locked ? null : () => _select(i),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${s.num}.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '${s.clue} (${s.len})',
                  children: [
                    if (ok == false)
                      TextSpan(
                        text: '  ${reveal![i]}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: CrosswordBoard.rightColor,
                        ),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ),
            if (ok != null)
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 18,
                color: ok ? CrosswordBoard.rightColor : AppColors.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.slot,
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final CrosswordSlot slot;
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            textCapitalization: TextCapitalization.characters,
            maxLength: slot.len,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÀ-ÿ]')),
            ],
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              isDense: true,
              labelText:
                  '${slot.num} ${slot.across ? 'horizontal' : 'vertical'} · ${slot.len} letras',
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Escrever na grade',
          onPressed: onSubmit,
          icon: const Icon(Icons.keyboard_return_rounded),
        ),
      ],
    );
  }
}
