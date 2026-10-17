import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/entities/phase_rules.dart';
import 'classroom_palette.dart';

/// Menu para escolher o tempo de UMA questão no relógio da fase:
/// "Automático (25 s)" ou um tempo fixo. [onSelected] recebe `null` para
/// automático.
class QuestionTimeMenu extends StatelessWidget {
  const QuestionTimeMenu({
    super.key,
    required this.value,
    required this.autoSeconds,
    required this.onSelected,
    required this.child,
    this.enabled = true,
  });

  /// Tempo escolhido (`null` = automático).
  final int? value;

  /// Quanto daria o automático para esta questão.
  final int autoSeconds;
  final ValueChanged<int?> onSelected;
  final Widget child;
  final bool enabled;

  static const _auto = -1;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: 'Tempo para responder',
      onSelected: (v) => onSelected(v == _auto ? null : v),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: _auto,
          checked: value == null,
          child: Text('Automático (${formatSeconds(autoSeconds)})'),
        ),
        const PopupMenuDivider(),
        for (final s in questionTimeChoices)
          CheckedPopupMenuItem(
            value: s,
            checked: value == s,
            child: Text(formatSeconds(s)),
          ),
      ],
      child: child,
    );
  }
}

/// Etiqueta do tempo da questão na lista da fase: "30 s" (escolhido, em
/// destaque) ou "auto · 25 s".
class QuestionTimeChip extends StatelessWidget {
  const QuestionTimeChip({
    super.key,
    required this.value,
    required this.autoSeconds,
  });

  final int? value;
  final int autoSeconds;

  @override
  Widget build(BuildContext context) {
    final custom = value != null;
    final color = custom ? AppColors.primary : ClassroomPalette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: custom ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: custom ? 0.5 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            custom
                ? formatSeconds(value!)
                : 'auto · ${formatSeconds(autoSeconds)}',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
