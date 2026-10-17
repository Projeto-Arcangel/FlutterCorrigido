import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

/// Caça-palavras: toque na primeira e na última letra da palavra (ou
/// arraste). A marcação vale se as letras formam uma palavra da lista (de
/// trás para frente também) — o servidor relê cada marcação na grade.
///
/// [found] é a resposta em montagem: as marcações certas, [r1, c1, r2, c2].
/// Com [onChanged] `null` a resposta está travada e, se vier [reveal] (onde
/// estava cada palavra), as que faltaram aparecem tracejadas.
class WordSearchBoard extends StatefulWidget {
  const WordSearchBoard({
    super.key,
    required this.grid,
    required this.words,
    required this.found,
    this.onChanged,
    this.reveal,
  });

  final List<String> grid;
  final List<String> words;
  final List<List<int>> found;
  final ValueChanged<List<List<int>>>? onChanged;
  final List<List<int>>? reveal;

  static const rightColor = Color(0xFF4CAF50);

  /// Cores das palavras achadas.
  static const colors = [
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
    Color(0xFFD4C21A),
  ];

  @override
  State<WordSearchBoard> createState() => _WordSearchBoardState();
}

class _WordSearchBoardState extends State<WordSearchBoard> {
  (int, int)? _start;
  (int, int)? _dragEnd;

  /// Marcação errada, piscando em vermelho.
  List<int>? _bad;
  Timer? _badTimer;

  bool get _locked => widget.onChanged == null;
  int get _rows => widget.grid.length;
  int get _cols => widget.grid.isEmpty ? 0 : widget.grid.first.length;

  @override
  void dispose() {
    _badTimer?.cancel();
    super.dispose();
  }

  /// Palavra que a marcação forma (ou `null`).
  String? _wordFor(List<int> sel) {
    final line = gridLine(widget.grid, sel[0], sel[1], sel[2], sel[3]);
    if (line == null) return null;
    final back = line.split('').reversed.join();
    for (final w in widget.words) {
      if (w == line || w == back) return w;
    }
    return null;
  }

  Set<String> get _foundWords => {
        for (final sel in widget.found)
          if (_wordFor(sel) case final w?) w,
      };

  (int, int) _cellAt(Offset p, double size) => (
        (p.dy ~/ size).clamp(0, _rows - 1),
        (p.dx ~/ size).clamp(0, _cols - 1),
      );

  void _evaluate((int, int) a, (int, int) b) {
    if (a == b) return;
    final sel = [a.$1, a.$2, b.$1, b.$2];
    final word = _wordFor(sel);
    if (word != null && !_foundWords.contains(word)) {
      widget.onChanged!([...widget.found, sel]);
      return;
    }
    _badTimer?.cancel();
    setState(() => _bad = sel);
    _badTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _bad = null);
    });
  }

  void _tap((int, int) cell) {
    if (_locked) return;
    final start = _start;
    if (start == null) {
      setState(() => _start = cell);
    } else {
      setState(() => _start = null);
      _evaluate(start, cell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final found = _foundWords;
    final textColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth / _cols).clamp(16.0, 34.0).floorToDouble();
            final pending = _start == null
                ? null
                : [_start!.$1, _start!.$2, (_dragEnd ?? _start!).$1, (_dragEnd ?? _start!).$2];
            return Center(
              child: GestureDetector(
                onTapUp: _locked ? null : (d) => _tap(_cellAt(d.localPosition, size)),
                onPanStart: _locked
                    ? null
                    : (d) => setState(() {
                          _start = _cellAt(d.localPosition, size);
                          _dragEnd = _start;
                        }),
                onPanUpdate: _locked
                    ? null
                    : (d) => setState(() => _dragEnd = _cellAt(d.localPosition, size)),
                onPanEnd: _locked
                    ? null
                    : (_) {
                        final a = _start;
                        final b = _dragEnd;
                        setState(() {
                          _start = null;
                          _dragEnd = null;
                        });
                        if (a != null && b != null) _evaluate(a, b);
                      },
                child: SizedBox(
                  width: size * _cols,
                  height: size * _rows,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MarksPainter(
                            size: size,
                            found: widget.found,
                            missed: _missed(found),
                            pending: pending,
                            bad: _bad,
                            locked: _locked,
                          ),
                        ),
                      ),
                      for (var r = 0; r < _rows; r++)
                        for (var c = 0; c < _cols; c++)
                          Positioned(
                            left: c * size,
                            top: r * size,
                            width: size,
                            height: size,
                            child: Center(
                              child: Text(
                                widget.grid[r][c],
                                style: TextStyle(
                                  fontSize: size * 0.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in widget.words)
              _WordTag(
                word: w,
                found: found.contains(w),
                missed: _locked && widget.reveal != null && !found.contains(w),
              ),
          ],
        ),
      ],
    );
  }

  /// Depois de travar: onde estavam as palavras que o aluno não achou.
  List<List<int>> _missed(Set<String> found) {
    final reveal = widget.reveal;
    if (reveal == null) return const [];
    return [
      for (var i = 0; i < widget.words.length && i < reveal.length; i++)
        if (!found.contains(widget.words[i])) reveal[i],
    ];
  }
}

class _WordTag extends StatelessWidget {
  const _WordTag({required this.word, required this.found, required this.missed});

  final String word;
  final bool found;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final color = found
        ? WordSearchBoard.rightColor
        : (missed ? AppColors.error : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (found) ...[
            const Icon(Icons.check_rounded, size: 14, color: WordSearchBoard.rightColor),
            const SizedBox(width: 3),
          ],
          Text(
            word,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              decoration: found ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.size,
    required this.found,
    required this.missed,
    required this.pending,
    required this.bad,
    required this.locked,
  });

  final double size;
  final List<List<int>> found;
  final List<List<int>> missed;
  final List<int>? pending;
  final List<int>? bad;
  final bool locked;

  Offset _center(int r, int c) => Offset((c + 0.5) * size, (r + 0.5) * size);

  void _capsule(Canvas canvas, List<int> s, Paint paint) {
    canvas.drawLine(_center(s[0], s[1]), _center(s[2], s[3]), paint);
  }

  @override
  void paint(Canvas canvas, Size _) {
    Paint stroke(Color color) => Paint()
      ..color = color
      ..strokeWidth = size * 0.78
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < found.length; i++) {
      final color = locked
          ? WordSearchBoard.rightColor
          : WordSearchBoard.colors[i % WordSearchBoard.colors.length];
      _capsule(canvas, found[i], stroke(color.withValues(alpha: 0.32)));
    }
    final outline = Paint()
      ..color = WordSearchBoard.rightColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final s in missed) {
      final a = _center(s[0], s[1]);
      final b = _center(s[2], s[3]);
      final rect = RRect.fromLTRBR(
        -size * 0.42,
        -size * 0.42,
        (b - a).distance + size * 0.42,
        size * 0.42,
        Radius.circular(size * 0.42),
      );
      canvas
        ..save()
        ..translate(a.dx, a.dy)
        ..rotate((b - a).direction);
      for (final PathMetric m in (Path()..addRRect(rect)).computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 9) {
          canvas.drawPath(m.extractPath(d, d + 5), outline);
        }
      }
      canvas.restore();
    }
    if (pending case final p?) {
      _capsule(canvas, p, stroke(AppColors.primary.withValues(alpha: 0.35)));
    }
    if (bad case final b?) {
      _capsule(canvas, b, stroke(AppColors.error.withValues(alpha: 0.35)));
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.found != found ||
      old.missed != missed ||
      old.pending != pending ||
      old.bad != bad ||
      old.size != size ||
      old.locked != locked;
}
