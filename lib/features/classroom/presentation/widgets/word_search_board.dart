import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

/// Caça-palavras: toque na primeira e na última letra da palavra (ou
/// arraste). O servidor relê cada marcação na grade (de trás para frente
/// também vale).
///
/// [words] traz a lista; as palavras ocultas vêm vazias ("") e aparecem
/// como _ _ _ com o tamanho de [lens]. [found] é a resposta em montagem,
/// [r1, c1, r2, c2] por marcação.
///
/// - Com [instant] (acertos na hora), só entra marcação que forma palavra
///   da lista. As ocultas são conferidas no servidor por [onCheck] e, achadas,
///   chegam em [known] (índice → palavra).
/// - Sem [instant], entra qualquer linha reta, no máximo uma por palavra;
///   marcar a mesma linha de novo (ou tocar no x) desfaz. O aluno só vê o
///   que acertou no fim.
///
/// Com [onChanged] `null` a resposta está travada; [reveal] (onde estava
/// cada palavra) e [revealWords] (todas, inclusive as ocultas) mostram as
/// que faltaram, tracejadas.
class WordSearchBoard extends StatefulWidget {
  const WordSearchBoard({
    super.key,
    required this.grid,
    required this.words,
    required this.found,
    this.lens,
    this.known = const {},
    this.instant = true,
    this.onChanged,
    this.onCheck,
    this.reveal,
    this.revealWords,
  });

  final List<String> grid;
  final List<String> words;
  final List<List<int>> found;
  final List<int>? lens;
  final Map<int, String> known;
  final bool instant;
  final ValueChanged<List<List<int>>>? onChanged;

  /// Confere no servidor uma marcação que pode ser uma palavra oculta;
  /// `true` = achou (a marcação já entrou na resposta).
  final Future<bool> Function(List<int> sel)? onCheck;
  final List<List<int>>? reveal;
  final List<String>? revealWords;

  static const rightColor = Color(0xFF4CAF50);

  /// Cores das marcações.
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

  /// Marcação recusada, piscando em vermelho (com o motivo, se houver).
  List<int>? _bad;
  String? _message;
  Timer? _badTimer;

  /// Marcação sendo conferida no servidor.
  List<int>? _checking;

  bool get _locked => widget.onChanged == null;
  int get _rows => widget.grid.length;
  int get _cols => widget.grid.isEmpty ? 0 : widget.grid.first.length;

  @override
  void dispose() {
    _badTimer?.cancel();
    super.dispose();
  }

  int _lenOf(int i) {
    final lens = widget.lens;
    return lens != null && i < lens.length ? lens[i] : widget.words[i].length;
  }

  /// Texto de cada palavra, quando se sabe: a visível, a oculta já achada
  /// ou, depois de travar, a do gabarito.
  List<String?> get _texts => [
        for (var i = 0; i < widget.words.length; i++)
          widget.words[i].isNotEmpty
              ? widget.words[i]
              : (widget.known[i] ??
                  ((widget.revealWords?.length ?? 0) > i ? widget.revealWords![i] : null)),
      ];

  String? _line(List<int> sel) => gridLine(widget.grid, sel[0], sel[1], sel[2], sel[3]);

  /// Índice da palavra (de texto conhecido) que a marcação forma.
  int? _indexFor(List<int> sel, List<String?> texts) {
    final line = _line(sel);
    if (line == null) return null;
    final back = line.split('').reversed.join();
    for (var i = 0; i < texts.length; i++) {
      final t = texts[i];
      if (t != null && (t == line || t == back)) return i;
    }
    return null;
  }

  Set<int> _foundIdx(List<String?> texts) => {
        for (final sel in widget.found)
          if (_indexFor(sel, texts) case final i?) i,
      };

  static bool _sameLine(List<int> a, List<int> b) =>
      (a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3]) ||
      (a[0] == b[2] && a[1] == b[3] && a[2] == b[0] && a[3] == b[1]);

  (int, int) _cellAt(Offset p, double size) => (
        (p.dy ~/ size).clamp(0, _rows - 1),
        (p.dx ~/ size).clamp(0, _cols - 1),
      );

  void _flashBad(List<int> sel, [String? message]) {
    _badTimer?.cancel();
    setState(() {
      _bad = sel;
      _message = message;
    });
    _badTimer = Timer(Duration(milliseconds: message == null ? 600 : 2500), () {
      if (mounted) {
        setState(() {
          _bad = null;
          _message = null;
        });
      }
    });
  }

  void _evaluate((int, int) a, (int, int) b) {
    final sel = [a.$1, a.$2, b.$1, b.$2];
    if (widget.instant) {
      _evaluateInstant(a, b, sel);
    } else {
      _evaluateFree(a, b, sel);
    }
  }

  /// Acertos na hora: só entra palavra da lista (a oculta, pelo servidor).
  void _evaluateInstant((int, int) a, (int, int) b, List<int> sel) {
    final texts = _texts;
    final found = _foundIdx(texts);
    final i = _indexFor(sel, texts);
    if (i != null && !found.contains(i)) {
      widget.onChanged!([...widget.found, sel]);
      return;
    }
    final line = _line(sel);
    final mayBeHidden = i == null &&
        line != null &&
        widget.onCheck != null &&
        _checking == null &&
        [
          for (var j = 0; j < texts.length; j++)
            if (texts[j] == null && !found.contains(j) && _lenOf(j) == line.length) j,
        ].isNotEmpty;
    if (mayBeHidden) {
      _check(sel);
      return;
    }
    // Mesma casa duas vezes sem palavra de 1 letra: só desmarca.
    if (a == b) return;
    _flashBad(sel);
  }

  Future<void> _check(List<int> sel) async {
    setState(() => _checking = sel);
    final ok = await widget.onCheck!(sel);
    if (!mounted) return;
    setState(() => _checking = null);
    if (!ok) _flashBad(sel);
  }

  /// Acertos só no fim: qualquer linha reta, uma por palavra.
  void _evaluateFree((int, int) a, (int, int) b, List<int> sel) {
    if (_line(sel) == null) {
      if (a != b) _flashBad(sel);
      return;
    }
    final same = widget.found.indexWhere((s) => _sameLine(s, sel));
    if (same >= 0) {
      widget.onChanged!([...widget.found]..removeAt(same));
      return;
    }
    // Uma casa só vale como marcação se há palavra de 1 letra.
    if (a == b && !List.generate(widget.words.length, _lenOf).contains(1)) return;
    final n = widget.words.length;
    if (widget.found.length >= n) {
      _flashBad(sel, 'Você já marcou $n: desfaça uma marcação para marcar outra.');
      return;
    }
    widget.onChanged!([...widget.found, sel]);
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
    final texts = _texts;
    final found = _foundIdx(texts);
    final textColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;
    // Sem acertos na hora, enquanto joga, a lista não entrega nada.
    final showFound = _locked || widget.instant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth / _cols).clamp(16.0, 34.0).floorToDouble();
            final pending = _checking ??
                (_start == null
                    ? null
                    : [_start!.$1, _start!.$2, (_dragEnd ?? _start!).$1, (_dragEnd ?? _start!).$2]);
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
                            // Travado: marcação que não forma palavra fica
                            // vermelha (sem acertos na hora ela pode existir).
                            ok: [
                              for (final sel in widget.found) _indexFor(sel, texts) != null,
                            ],
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
        if (_message case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.words.length; i++)
              _WordTag(
                text: texts[i],
                length: _lenOf(i),
                found: showFound && found.contains(i),
                missed: _locked && widget.reveal != null && !found.contains(i),
              ),
          ],
        ),
        if (!_locked && !widget.instant) ...[
          const SizedBox(height: 14),
          Text(
            'Suas marcações: ${widget.found.length} de ${widget.words.length}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (widget.found.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var k = 0; k < widget.found.length; k++)
                  InputChip(
                    label: Text(_line(widget.found[k]) ?? ''),
                    deleteButtonTooltipMessage: 'Desfazer esta marcação',
                    onDeleted: () =>
                        widget.onChanged!([...widget.found]..removeAt(k)),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  /// Depois de travar: onde estavam as palavras que o aluno não achou.
  List<List<int>> _missed(Set<int> found) {
    final reveal = widget.reveal;
    if (reveal == null) return const [];
    return [
      for (var i = 0; i < widget.words.length && i < reveal.length; i++)
        if (!found.contains(i)) reveal[i],
    ];
  }
}

class _WordTag extends StatelessWidget {
  const _WordTag({
    required this.text,
    required this.length,
    required this.found,
    required this.missed,
  });

  /// `null` = palavra oculta ainda não achada (aparece _ _ _).
  final String? text;
  final int length;
  final bool found;
  final bool missed;

  @override
  Widget build(BuildContext context) {
    final color = found
        ? WordSearchBoard.rightColor
        : (missed ? AppColors.error : AppColors.textSecondary);
    final hidden = text == null;
    return Semantics(
      label: hidden ? 'Palavra oculta de $length letra${length == 1 ? '' : 's'}' : null,
      excludeSemantics: hidden,
      child: Container(
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
              text ?? List.filled(length, '_').join(' '),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: hidden ? 1 : null,
                decoration: found ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.size,
    required this.found,
    required this.ok,
    required this.missed,
    required this.pending,
    required this.bad,
    required this.locked,
  });

  final double size;
  final List<List<int>> found;
  final List<bool> ok;
  final List<List<int>> missed;
  final List<int>? pending;
  final List<int>? bad;
  final bool locked;

  Offset _center(int r, int c) => Offset((c + 0.5) * size, (r + 0.5) * size);

  void _capsule(Canvas canvas, List<int> s, Paint paint) {
    final a = _center(s[0], s[1]);
    final b = _center(s[2], s[3]);
    // Uma casa só (palavra de 1 letra): um círculo, sem depender de como o
    // navegador desenha uma linha de comprimento zero.
    if (a == b) {
      canvas.drawCircle(
        a,
        paint.strokeWidth / 2,
        Paint()..color = paint.color,
      );
      return;
    }
    canvas.drawLine(a, b, paint);
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
          ? (i < ok.length && !ok[i] ? AppColors.error : WordSearchBoard.rightColor)
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
      !listEquals(old.ok, ok) ||
      old.missed != missed ||
      old.pending != pending ||
      old.bad != bad ||
      old.size != size ||
      old.locked != locked;
}
