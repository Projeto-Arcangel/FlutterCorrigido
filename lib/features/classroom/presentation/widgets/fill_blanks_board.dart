import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Completar lacunas com um banco de palavras.
///
/// Toque numa palavra do banco: ela vai para a lacuna escolhida (ou para a
/// primeira vazia). Toque numa lacuna preenchida para devolver a palavra.
///
/// [blanks] é a resposta em montagem: lacuna k ← `bank[blanks[k]]`
/// (`null` = vazia). Com [onChanged] `null` a resposta está travada e, se
/// vier [reveal] (o gabarito), cada lacuna fica verde ou vermelha — com a
/// palavra certa ao lado quando errou. A conferência é pelo texto (o banco
/// pode repetir palavra), como no servidor.
class FillBlanksBoard extends StatefulWidget {
  const FillBlanksBoard({
    super.key,
    required this.parts,
    required this.bank,
    required this.blanks,
    this.onChanged,
    this.reveal,
  });

  final List<String> parts;
  final List<String> bank;
  final List<int?> blanks;
  final ValueChanged<List<int?>>? onChanged;
  final List<int>? reveal;

  static const rightColor = Color(0xFF4CAF50);

  @override
  State<FillBlanksBoard> createState() => _FillBlanksBoardState();
}

class _FillBlanksBoardState extends State<FillBlanksBoard> {
  /// Lacuna escolhida para receber a próxima palavra.
  int? _target;

  bool get _locked => widget.onChanged == null;

  static String _norm(String s) => s.trim().toLowerCase();

  String? _wordAt(int? i) =>
      i == null || i < 0 || i >= widget.bank.length ? null : widget.bank[i];

  /// Depois de travar: a lacuna k está certa?
  bool? _isRight(int k) {
    final key = widget.reveal;
    if (key == null || k >= key.length) return null;
    final chosen = _wordAt(widget.blanks[k]);
    final right = _wordAt(key[k]);
    return chosen != null && right != null && _norm(chosen) == _norm(right);
  }

  void _tapBlank(int k) {
    if (_locked) return;
    if (widget.blanks[k] != null) {
      final next = [...widget.blanks]..[k] = null;
      setState(() => _target = k);
      widget.onChanged!(next);
    } else {
      setState(() => _target = _target == k ? null : k);
    }
  }

  void _tapWord(int i) {
    if (_locked || widget.blanks.contains(i)) return;
    var k = _target;
    if (k == null || widget.blanks[k] != null) {
      k = widget.blanks.indexOf(null);
    }
    if (k < 0) return; // tudo preenchido: toque numa lacuna para trocar
    final next = [...widget.blanks]..[k] = i;
    final after = next.indexOf(null);
    setState(() => _target = after < 0 ? null : after);
    widget.onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;
    final textStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: textColor,
    );

    // Palavra por palavra, para o texto quebrar linha junto com as lacunas.
    final pieces = <Widget>[];
    for (var k = 0; k < widget.parts.length; k++) {
      for (final word in widget.parts[k].split(RegExp(r'(?<=\s)'))) {
        if (word.isEmpty) continue;
        pieces.add(Text(word, style: textStyle));
      }
      if (k < widget.parts.length - 1) {
        pieces.add(_blank(k, isDark));
        final right = _isRight(k);
        if (right == false) {
          pieces.add(_correctWord(k));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: pieces,
        ),
        if (!_locked) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.bank.length; i++)
                _WordChip(
                  text: widget.bank[i],
                  used: widget.blanks.contains(i),
                  onTap: () => _tapWord(i),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _blank(int k, bool isDark) {
    final word = _wordAt(widget.blanks[k]);
    final right = _isRight(k);
    final selected = !_locked && _target == k;
    final color = right == null
        ? (selected ? AppColors.primary : null)
        : (right ? FillBlanksBoard.rightColor : AppColors.error);
    final idle = isDark ? Colors.white38 : AppColors.textSecondary.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: !_locked,
        label: word == null ? 'Lacuna ${k + 1}, vazia' : 'Lacuna ${k + 1}: $word',
        child: GestureDetector(
          onTap: _locked ? null : () => _tapBlank(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (color ?? (word == null ? Colors.transparent : AppColors.primary))
                  .withValues(alpha: word == null && color == null ? 0 : 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color ?? (word == null ? idle : AppColors.primary),
                width: color != null || word != null ? 2 : 1.5,
              ),
            ),
            child: Text(
              word ?? '${k + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: word == null ? idle : (color ?? AppColors.primary),
                decoration: right == false ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _correctWord(int k) {
    final right = _wordAt(widget.reveal![k]) ?? '';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FillBlanksBoard.rightColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          right,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: FillBlanksBoard.rightColor,
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.text, required this.used, required this.onTap});

  final String text;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: !used,
      label: used ? '$text (já usada)' : text,
      child: GestureDetector(
        onTap: used ? null : onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: used ? 0.3 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white24 : AppColors.borderBlue.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
