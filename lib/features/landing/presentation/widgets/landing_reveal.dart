import 'package:flutter/material.dart';

/// Faz o conteúdo surgir (fade + leve subida) na primeira vez que entra na
/// tela durante a rolagem. Depois de revelado, fica parado.
///
/// Com "reduzir movimento" ligado no sistema (`disableAnimations`), o
/// conteúdo aparece direto, sem animação. O conteúdo ainda não revelado
/// continua na árvore de acessibilidade e no foco por teclado: focar nele
/// rola a página até ele, o que o revela.
class LandingReveal extends StatefulWidget {
  const LandingReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;

  /// Atraso extra, para revelar itens vizinhos em sequência.
  final Duration delay;

  @override
  State<LandingReveal> createState() => _LandingRevealState();
}

class _LandingRevealState extends State<LandingReveal> {
  static const _duration = Duration(milliseconds: 600);

  /// Fração da altura visível que o topo do conteúdo precisa ultrapassar.
  static const _threshold = 0.9;

  ScrollPosition? _position;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_revealed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Ainda antes do build: basta marcar, sem setState.
      _stopListening();
      _revealed = true;
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_check);
      _position = position?..addListener(_check);
    }
    // O que já está na tela ao abrir a página é revelado no primeiro frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _stopListening() {
    _position?.removeListener(_check);
    _position = null;
  }

  void _check() {
    if (_revealed || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    if (top < viewportHeight * _threshold) {
      _stopListening();
      setState(() => _revealed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    // O atraso entra na própria curva (Interval), sem Timer: a animação só
    // começa a andar depois de `delay`.
    final total = _duration + widget.delay;
    final start = widget.delay.inMicroseconds / total.inMicroseconds;
    final curve = Interval(start, 1, curve: Curves.easeOutCubic);

    return AnimatedOpacity(
      opacity: _revealed ? 1 : 0,
      duration: total,
      curve: curve,
      child: AnimatedSlide(
        offset: _revealed ? Offset.zero : const Offset(0, 0.06),
        duration: total,
        curve: curve,
        child: widget.child,
      ),
    );
  }
}
