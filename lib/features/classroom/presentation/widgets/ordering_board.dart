import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

/// Ordenar: o aluno arrasta os itens (ou usa as setas) até a ordem certa.
///
/// [order] é a resposta em montagem: a posição p mostra `items[order[p]]`.
/// Com [onChanged] `null` a resposta está travada e, se vier [reveal] (o
/// gabarito, no mesmo formato), ficam verdes os itens na posição certa (cada
/// um vale ponto sozinho), vermelhos os fora do lugar, e a ordem certa
/// aparece embaixo.
class OrderingBoard extends StatelessWidget {
  const OrderingBoard({
    super.key,
    required this.items,
    required this.order,
    this.onChanged,
    this.reveal,
  });

  final List<String> items;
  final List<int> order;
  final ValueChanged<List<int>>? onChanged;
  final List<int>? reveal;

  static const _right = Color(0xFF4CAF50);

  void _move(int from, int to) {
    if (to < 0 || to >= order.length) return;
    final next = [...order];
    final item = next.removeAt(from);
    next.insert(to, item);
    onChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    if (onChanged == null) return _locked(context);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: order.length,
      // ReorderableListView passa o destino "antes do item"; ajusta para a
      // posição final.
      onReorder: (from, to) => _move(from, to > from ? to - 1 : to),
      proxyDecorator: (child, _, __) => Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
      itemBuilder: (_, p) => _OrderTile(
        key: ValueKey(order[p]),
        position: p,
        text: items[order[p]],
        dragHandle: ReorderableDragStartListener(
          index: p,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.drag_indicator_rounded),
          ),
        ),
        onUp: p == 0 ? null : () => _move(p, p - 1),
        onDown: p == order.length - 1 ? null : () => _move(p, p + 1),
      ),
    );
  }

  Widget _locked(BuildContext context) {
    final key = reveal;
    final allRight = key != null &&
        key.length == order.length &&
        List.generate(order.length, (p) => order[p] == key[p]).every((ok) => ok);
    // Verde = item na posição certa (vale ponto, como na nota do
    // servidor); vermelho = fora do lugar.
    final kept = key == null ? const <int>{} : orderingKeptPositions(order, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var p = 0; p < order.length; p++)
          _OrderTile(
            position: p,
            text: items[order[p]],
            result: key == null || p >= key.length
                ? null
                : (kept.contains(p) ? _right : AppColors.error),
          ),
        if (key != null && !allRight) ...[
          const SizedBox(height: 6),
          Text(
            'Ordem certa:',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800, color: _right),
          ),
          const SizedBox(height: 6),
          for (var p = 0; p < key.length; p++)
            if (key[p] >= 0 && key[p] < items.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${p + 1}. ${items[key[p]]}'),
              ),
        ],
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    super.key,
    required this.position,
    required this.text,
    this.dragHandle,
    this.onUp,
    this.onDown,
    this.result,
  });

  final int position;
  final String text;
  final Widget? dragHandle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  /// Verde/vermelho depois de travar.
  final Color? result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movable = dragHandle != null;
    final badge = result ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: EdgeInsets.fromLTRB(10, 6, movable ? 2 : 12, 6),
        decoration: BoxDecoration(
          color: result != null
              ? result!.withValues(alpha: 0.12)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: result ??
                (isDark
                    ? Colors.white12
                    : AppColors.borderBlue.withValues(alpha: 0.25)),
            width: result != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badge.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${position + 1}',
                style: TextStyle(fontWeight: FontWeight.w800, color: badge),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ),
            if (movable) ...[
              IconButton(
                tooltip: 'Subir',
                visualDensity: VisualDensity.compact,
                onPressed: onUp,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Descer',
                visualDensity: VisualDensity.compact,
                onPressed: onDown,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              dragHandle!,
            ],
            if (result != null)
              Icon(
                result == AppColors.error
                    ? Icons.cancel_rounded
                    : Icons.check_circle_rounded,
                color: result,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
