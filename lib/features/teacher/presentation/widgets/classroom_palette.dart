import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Paleta compartilhada pelas telas e widgets de turma.
///
/// Mantida em um único lugar para garantir consistência entre a
/// listagem de turmas, detalhe e formulários de criação/edição.
abstract class ClassroomPalette {
  static const Color gold = Color(0xFFE8A020);
  static const Color goldDim = Color(0x80E8A020);
  static const Color goldSubtle = Color(0x1AE8A020);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color danger = Color(0xFFFF5963);
  static const Color dangerSubtle = Color(0x26FF5963);
  static const Color success = Color(0xFF72D09C);

  static Color cardBg(bool dark) =>
      dark ? AppColors.surfaceDark : Colors.white;
  static Color border(bool dark) =>
      dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color divider(bool dark) =>
      dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color primaryText(bool dark) =>
      dark ? Colors.white : AppColors.textPrimary;
  static Color fieldFill(bool dark) =>
      dark ? AppColors.backgroundDark : AppColors.background;
}