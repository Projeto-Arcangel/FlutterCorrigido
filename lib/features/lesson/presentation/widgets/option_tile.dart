import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum OptionState { idle, selected, correct, wrong }

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.index,
    required this.label,
    required this.optionState,
    this.onTap,
  });

  final int index;
  final String label;
  final OptionState optionState;
  final VoidCallback? onTap;

  static const _letters = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final letter = index < _letters.length ? _letters[index] : '${index + 1}';

    Color bgColor;
    Color borderColor;
    Color badgeBg;
    Color badgeTextColor;
    Widget? trailingIcon;

    switch (optionState) {
      case OptionState.idle:
        bgColor     = isDark ? AppColors.surfaceDark : Colors.white;
        borderColor = isDark ? Colors.white12 : AppColors.borderBlue.withValues(alpha: 0.25);
        badgeBg     = isDark ? const Color(0xFF3A3D4A) : const Color(0xFFE5E7EB);
        badgeTextColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;
        trailingIcon = null;
        break;

      case OptionState.selected:
        bgColor     = AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10);
        borderColor = AppColors.primary;
        badgeBg     = AppColors.primary;
        badgeTextColor = Colors.white;
        trailingIcon = null;
        break;

      case OptionState.correct:
        bgColor     = const Color(0xFF4CAF50).withValues(alpha: 0.14);
        borderColor = const Color(0xFF4CAF50);
        badgeBg     = const Color(0xFF4CAF50);
        badgeTextColor = Colors.white;
        trailingIcon = const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 22,
        );
        break;

      case OptionState.wrong:
        bgColor     = AppColors.error.withValues(alpha: 0.14);
        borderColor = AppColors.error;
        badgeBg     = AppColors.error;
        badgeTextColor = Colors.white;
        trailingIcon = const Icon(
          Icons.cancel_rounded,
          color: AppColors.error,
          size: 22,
        );
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: optionState == OptionState.idle ? 1.0 : 2.0,
          ),
        ),
        child: Row(
          children: [
            // ── Letter badge ─────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: badgeTextColor,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Option text ──────────────────────────────────────────
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: optionState != OptionState.idle
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ),

            // ── Trailing icon (correct / wrong) ──────────────────────
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              trailingIcon,
            ],
          ],
        ),
      ),
    );
  }
}
