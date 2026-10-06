import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/password_policy.dart';

/// Força da senha + lista do que ela precisa ter, atualizadas a cada tecla.
///
/// Usado em todo lugar onde se cria ou troca a senha. A lista aparece desde o
/// início (o usuário já sabe a regra antes de errar); a barra de força só
/// depois que algo é digitado. Enquanto estiver "Fraca", o validador
/// `AuthValidators.newPassword` não deixa enviar.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = PasswordPolicy.strengthOf(password);
    final colors = _MeterColors(isDark);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (strength != PasswordStrength.empty) ...[
            _StrengthBar(strength: strength, colors: colors),
            const SizedBox(height: 10),
          ],
          // Sem liveRegion: anunciar a cada tecla interromperia a digitação.
          // O leitor de tela lê a lista ao passar por ela.
          for (final requirement in PasswordPolicy.requirements)
            _RequirementRow(
              label: requirement.label,
              met: PasswordPolicy.isMet(requirement, password),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

/// Cores vivas nas barras/ícones; texto com variações de contraste ≥ 4,5:1
/// no fundo claro (as vivas ficam em ~2:1 sobre branco).
class _MeterColors {
  const _MeterColors(this.isDark);

  final bool isDark;

  Color get weakBar => const Color(0xFFE53935);
  Color get goodBar => const Color(0xFFE8A838);
  Color get strongBar => const Color(0xFF2ECC71);

  Color get weakText =>
      isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);
  Color get goodText =>
      isDark ? const Color(0xFFE8A838) : const Color(0xFF8A5A10);
  Color get strongText =>
      isDark ? const Color(0xFF2ECC71) : const Color(0xFF1A7F4B);

  Color get pending =>
      isDark ? const Color(0xFF8FA3AE) : AppColors.textSecondary;
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.strength, required this.colors});

  final PasswordStrength strength;
  final _MeterColors colors;

  @override
  Widget build(BuildContext context) {
    final (label, barColor, textColor, filledBars) = switch (strength) {
      PasswordStrength.empty => ('', Colors.transparent, Colors.transparent, 0),
      PasswordStrength.weak => ('Fraca', colors.weakBar, colors.weakText, 1),
      PasswordStrength.good => ('Boa', colors.goodBar, colors.goodText, 2),
      PasswordStrength.strong => (
          'Forte',
          colors.strongBar,
          colors.strongText,
          3
        ),
    };

    return Semantics(
      label: 'Força da senha: $label',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledBars
                      ? barColor
                      : barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.met,
    required this.colors,
  });

  final String label;
  final bool met;
  final _MeterColors colors;

  @override
  Widget build(BuildContext context) {
    final color = met ? colors.strongText : colors.pending;

    return Semantics(
      label: '$label: ${met ? 'atendido' : 'pendente'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: met ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
