import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo do Arcangel com suporte automático a modo claro/escuro.
///
/// Heurística Nielsen #4 (consistência): widget centralizado usado em todas
/// as telas que precisam exibir a marca, garantindo aparência uniforme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark
          ? 'assets/images/modo_escuro.png'
          : 'assets/images/modo_claro.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo Arcangel',
      errorBuilder: (_, __, ___) => _FallbackLogo(size: size),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Icon(
        Icons.school_outlined,
        color: AppColors.primary,
        size: size * 0.5,
      ),
    );
  }
}
