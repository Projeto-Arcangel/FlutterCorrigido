import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ligar colunas no estilo fios: cada item da esquerda ganha um fio
/// colorido até o par dele na direita.
///
/// Ligar: toque no item da esquerda e depois no da direita, ou arraste o
/// fio da esquerda até a direita. Tocar num item da direita já ligado
/// (sem nenhum da esquerda escolhido) solta o fio.
///
/// [match] é a resposta em montagem: esquerda i → direita `match[i]`
/// (`null` = solto). Com [onChanged] `null` a resposta está travada e,
/// se vier [reveal] (o gabarito), os fios ficam verdes ou vermelhos e o
/// fio certo aparece tracejado onde o aluno errou.
class MatchColumnsBoard extends StatefulWidget {
  const MatchColumnsBoard({
    super.key,
    required this.left,
    required this.right,
    required this.match,
    this.onChanged,
    this.reveal,
  });

  final List<String> left;
  final List<String> right;
  final List<int?> match;
  final ValueChanged<List<int?>>? onChanged;
  final List<int>? reveal;

  /// Cores dos fios (sem verde e vermelho, que ficam para certo/errado).
  static const wireColors = [
    Color(0xFF42A5F5),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
    Color(0xFFD4C21A),
  ];

  static const rightColor = Color(0xFF4CAF50);
  static const wrongColor = AppColors.error;

  @override
  State<MatchColumnsBoard> createState() => _MatchColumnsBoardState();
}

class _MatchColumnsBoardState extends State<MatchColumnsBoard> {
  final _boardKey = GlobalKey();
  late List<GlobalKey> _leftKeys;
  late List<GlobalKey> _rightKeys;

  /// Pontas dos fios, nas coordenadas do tabuleiro.
  List<Offset> _leftAnchors = const [];
  List<Offset> _rightAnchors = const [];
  List<Rect> _rightRects = const [];

  int? _selected;
  int? _dragFrom;
  Offset? _dragPoint;

  bool get _locked => widget.onChanged == null;

  @override
  void initState() {
    super.initState();
    _makeKeys();
  }

  @override
  void didUpdateWidget(MatchColumnsBoard old) {
    super.didUpdateWidget(old);
    if (old.left.length != widget.left.length ||
        old.right.length != widget.right.length) {
      _makeKeys();
    }
    if (_locked) _selected = null;
  }

  void _makeKeys() {
    _leftKeys = List.generate(widget.left.length, (_) => GlobalKey());
    _rightKeys = List.generate(widget.right.length, (_) => GlobalKey());
  }

  Color _wireColor(int left) =>
      MatchColumnsBoard.wireColors[left % MatchColumnsBoard.wireColors.length];

  /// Mede onde ficaram os cartões (o texto pode quebrar linha) e redesenha
  /// os fios só se algo mudou.
  void _measure() {
    if (!mounted) return;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || !board.hasSize) return;
    Rect? rectOf(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return box.localToGlobal(Offset.zero, ancestor: board) & box.size;
    }

    final lefts = _leftKeys.map(rectOf).toList();
    final rights = _rightKeys.map(rectOf).toList();
    if (lefts.contains(null) || rights.contains(null)) return;
    final leftAnchors = [for (final r in lefts) r!.centerRight];
    final rightAnchors = [for (final r in rights) r!.centerLeft];
    final rightRects = [for (final r in rights) r!];
    if (_same(leftAnchors, _leftAnchors) && _same(rightAnchors, _rightAnchors)) {
      return;
    }
    setState(() {
      _leftAnchors = leftAnchors;
      _rightAnchors = rightAnchors;
      _rightRects = rightRects;
    });
  }

  static bool _same(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).distanceSquared > 0.25) return false;
    }
    return true;
  }

  void _connect(int left, int right) {
    final next = [...widget.match];
    for (var k = 0; k < next.length; k++) {
      if (next[k] == right) next[k] = null; // a direita só aceita um fio
    }
    next[left] = right;
    setState(() => _selected = null);
    widget.onChanged!(next);
  }

  void _tapLeft(int i) {
    if (_locked) return;
    setState(() => _selected = _selected == i ? null : i);
  }

  void _tapRight(int j) {
    if (_locked) return;
    final selected = _selected;
    if (selected != null) {
      _connect(selected, j);
      return;
    }
    final owner = widget.match.indexOf(j);
    if (owner >= 0) {
      final next = [...widget.match]..[owner] = null;
      widget.onChanged!(next);
    }
  }

  Offset? _toBoard(Offset global) {
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    return board?.globalToLocal(global);
  }

  void _dragStart(int i, DragStartDetails d) {
    if (_locked) return;
    setState(() {
      _dragFrom = i;
      _selected = i;
      _dragPoint = _toBoard(d.globalPosition);
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_dragFrom == null) return;
    setState(() => _dragPoint = _toBoard(d.globalPosition));
  }

  void _dragEnd() {
    final from = _dragFrom;
    final point = _dragPoint;
    setState(() {
      _dragFrom = null;
      _dragPoint = null;
    });
    if (from == null || point == null) return;
    for (var j = 0; j < _rightRects.length; j++) {
      if (_rightRects[j].inflate(8).contains(point)) {
        _connect(from, j);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final reveal = widget.reveal;

    return Stack(
      key: _boardKey,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < widget.left.length; i++)
                    _Card(
                      key: _leftKeys[i],
                      text: widget.left[i],
                      side: _Side.left,
                      dotColor: widget.match[i] != null || _selected == i
                          ? _resultColor(i) ?? _wireColor(i)
                          : null,
                      highlight: _selected == i ? _wireColor(i) : null,
                      border: _resultColor(i),
                      onTap: _locked ? null : () => _tapLeft(i),
                      onPanStart: _locked ? null : (d) => _dragStart(i, d),
                      onPanUpdate: _locked ? null : _dragUpdate,
                      onPanEnd: _locked ? null : (_) => _dragEnd(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              child: Column(
                children: [
                  for (var j = 0; j < widget.right.length; j++)
                    _Card(
                      key: _rightKeys[j],
                      text: widget.right[j],
                      side: _Side.right,
                      dotColor: _rightDot(j),
                      highlight: null,
                      border: null,
                      onTap: _locked ? null : () => _tapRight(j),
                    ),
                ],
              ),
            ),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _WiresPainter(
                leftAnchors: _leftAnchors,
                rightAnchors: _rightAnchors,
                match: widget.match,
                reveal: reveal,
                colorOf: _wireColor,
                dragFrom: _dragFrom,
                dragPoint: _dragPoint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Depois de travar: verde se o fio da esquerda i está certo.
  Color? _resultColor(int i) {
    final reveal = widget.reveal;
    if (reveal == null || i >= reveal.length) return null;
    return widget.match[i] == reveal[i]
        ? MatchColumnsBoard.rightColor
        : MatchColumnsBoard.wrongColor;
  }

  Color? _rightDot(int j) {
    final owner = widget.match.indexOf(j);
    if (owner < 0) return null;
    return _resultColor(owner) ?? _wireColor(owner);
  }
}

enum _Side { left, right }

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.text,
    required this.side,
    required this.dotColor,
    required this.highlight,
    required this.border,
    required this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  final String text;
  final _Side side;

  /// Cor da tomada (ponta do fio); `null` = solta.
  final Color? dotColor;

  /// Item escolhido, esperando o par.
  final Color? highlight;

  /// Certo/errado depois de travar.
  final Color? border;
  final VoidCallback? onTap;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleBorder =
        isDark ? Colors.white12 : AppColors.borderBlue.withValues(alpha: 0.25);
    final borderColor = border ?? highlight ?? idleBorder;
    final dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor ?? Colors.transparent,
        border: Border.all(
          color: dotColor ??
              (isDark ? Colors.white38 : AppColors.textSecondary.withValues(alpha: 0.5)),
          width: 2,
        ),
      ),
    );
    final label = Expanded(
      child: Text(
        text,
        textAlign: side == _Side.left ? TextAlign.start : TextAlign.end,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: onTap != null,
        label: text,
        child: GestureDetector(
          onTap: onTap,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: highlight != null
                  ? highlight!.withValues(alpha: 0.14)
                  : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: border != null || highlight != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: side == _Side.left
                  ? [label, const SizedBox(width: 8), dot]
                  : [dot, const SizedBox(width: 8), label],
            ),
          ),
        ),
      ),
    );
  }
}

class _WiresPainter extends CustomPainter {
  _WiresPainter({
    required this.leftAnchors,
    required this.rightAnchors,
    required this.match,
    required this.reveal,
    required this.colorOf,
    required this.dragFrom,
    required this.dragPoint,
  });

  final List<Offset> leftAnchors;
  final List<Offset> rightAnchors;
  final List<int?> match;
  final List<int>? reveal;
  final Color Function(int left) colorOf;
  final int? dragFrom;
  final Offset? dragPoint;

  Path _wire(Offset a, Offset b) {
    final dx = (b.dx - a.dx).abs() * 0.5;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (leftAnchors.isEmpty || rightAnchors.isEmpty) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Gabarito tracejado onde o aluno errou (ou deixou solto).
    final key = reveal;
    if (key != null) {
      final dashed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = MatchColumnsBoard.rightColor.withValues(alpha: 0.9);
      for (var i = 0; i < leftAnchors.length && i < key.length; i++) {
        if (match[i] == key[i] || key[i] >= rightAnchors.length) continue;
        _dash(canvas, _wire(leftAnchors[i], rightAnchors[key[i]]), dashed);
      }
    }

    for (var i = 0; i < leftAnchors.length && i < match.length; i++) {
      final j = match[i];
      if (j == null || j >= rightAnchors.length || i == dragFrom) continue;
      stroke.color = key == null
          ? colorOf(i)
          : (j == key[i]
              ? MatchColumnsBoard.rightColor
              : MatchColumnsBoard.wrongColor);
      canvas.drawPath(_wire(leftAnchors[i], rightAnchors[j]), stroke);
    }

    final from = dragFrom;
    final point = dragPoint;
    if (from != null && point != null && from < leftAnchors.length) {
      stroke.color = colorOf(from);
      canvas.drawPath(_wire(leftAnchors[from], point), stroke);
      canvas.drawCircle(point, 6, Paint()..color = colorOf(from));
    }
  }

  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final PathMetric metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_WiresPainter old) =>
      old.leftAnchors != leftAnchors ||
      old.rightAnchors != rightAnchors ||
      old.match != match ||
      old.reveal != reveal ||
      old.dragFrom != dragFrom ||
      old.dragPoint != dragPoint;
}
