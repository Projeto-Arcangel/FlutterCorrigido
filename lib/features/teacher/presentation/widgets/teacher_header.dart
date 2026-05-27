import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

abstract class _TeacherColors {
  static const Color accent       = Color(0xFF72D082);
  static const Color accentSubtle = Color(0x1A72D082);

  // Variante do accent para uso como COR DE TEXTO.
  // No modo claro, o verde vibrante (#72D082) tem contraste ~1.8:1 sobre
  // branco — usamos um verde-floresta mais escuro (#2E7D42, ~5.1:1).
  static Color accentText(bool dark) =>
      dark ? accent : const Color(0xFF2E7D42);

  static Color primaryText(bool dark) => dark ? Colors.white : AppColors.textPrimary;
  static Color settingsIcon(bool dark)=> dark ? Colors.white54 : AppColors.textSecondary;
}

// ─────────────────────────────────────────────────────────────────────────────
// TeacherHeader
//
// Heurística #1 – Visibilidade: engrenagem sempre visível no topo-direito,
//   mesmo padrão que o ProfilePage do aluno (consistência #4).
// Heurística #3 – Controle: settings acessíveis em 1 toque.
// Heurística #5 – Prevenção de erros: logout explícito dentro de SettingsPage,
//   sem ação oculta via long-press.
// ─────────────────────────────────────────────────────────────────────────────

class TeacherHeader extends StatelessWidget {
  const TeacherHeader({
    super.key,
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return _HeaderBar(displayName: displayName);
  }
}

// ── Barra superior: saudação + botão de configurações ────────────────────────

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Saudação ────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Área do Professor',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _TeacherColors.accentText(isDark),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prof. $displayName',
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _TeacherColors.primaryText(isDark),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),

          // ── Botão de configurações ───────────────────────────────────────
          // Mesmo padrão do ProfilePage do aluno: ícone de engrenagem
          // no topo-direito, tooltip explícito, toque único para navegar.
          Tooltip(
            message: 'Configurações',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(AppRoutes.teacherSettings),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _TeacherColors.accentSubtle,
                    border: Border.all(
                      color: _TeacherColors.accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: _TeacherColors.settingsIcon(isDark),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

