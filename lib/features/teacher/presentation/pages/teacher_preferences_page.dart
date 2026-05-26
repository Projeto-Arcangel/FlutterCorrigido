import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/pages/preferences_page.dart'
    show preferencesProvider;

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de apoio — tons esverdeados exclusivos do professor
// ─────────────────────────────────────────────────────────────────────────────

abstract class _TP {
  static const Color accent    = Color(0xFF72D082);
  static const Color warning   = Color(0xFFFFD166);

  // Texto secundário: mais escuro no claro para contraste mínimo WCAG AA
  // (11–12 px com letter-spacing exige ≥ 4.5:1; #5A6B78 entrega ~5.6:1 sobre branco)
  static Color textMuted(bool dark) =>
      dark ? const Color(0xFF8FA3AE) : const Color(0xFF5A6B78);

  // Verde como COR DE TEXTO: vibrante no escuro, floresta no claro (~5.1:1)
  static Color accentText(bool dark) =>
      dark ? accent : const Color(0xFF2E7D42);

  static Color cardBg(bool dark) => dark ? AppColors.surfaceDark : Colors.white;
  static Color cardBorder(bool dark) =>
      dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color trackInactive(bool dark) =>
      dark ? const Color(0xFF2E373E) : const Color(0xFFCFD8DC);
  static Color iconBgOn(bool dark) =>
      accent.withValues(alpha: dark ? 0.15 : 0.12);
  static Color iconBgOff(bool dark) => dark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);
  static Color textPrimary(bool dark) =>
      dark ? Colors.white : AppColors.textPrimary;
}

// ─────────────────────────────────────────────────────────────────────────────
// TeacherPreferencesPage
//
// Heurística #1 – Visibilidade: AppBar "Preferências" + back-button.
// Heurística #3 – Controle e liberdade: botão Voltar sempre visível.
// Heurística #4 – Consistência: mesma estrutura de PreferencesPage,
//                  paleta verde exclusiva do professor.
// Heurística #5 – Prevenção de erros: toggles com estado visual explícito.
// Heurística #6 – Reconhecimento: ícones + rótulos em todos os controles.
// Heurística #8 – Minimalismo: sem informação irrelevante, hierarquia clara.
// ─────────────────────────────────────────────────────────────────────────────

class TeacherPreferencesPage extends ConsumerStatefulWidget {
  const TeacherPreferencesPage({super.key});

  @override
  ConsumerState<TeacherPreferencesPage> createState() =>
      _TeacherPreferencesPageState();
}

class _TeacherPreferencesPageState
    extends ConsumerState<TeacherPreferencesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const int _animCount = 3;
  static const Duration _totalDuration = Duration(milliseconds: 650);
  static const Duration _stagger = Duration(milliseconds: 90);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);

    _fadeAnims = List.generate(_animCount, (i) {
      final start =
          (i * _stagger.inMilliseconds) / _totalDuration.inMilliseconds;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = _fadeAnims
        .map(
          (anim) => Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(anim),
        )
        .toList();

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _animated(int slot, Widget child) => FadeTransition(
        opacity: _fadeAnims[slot],
        child: SlideTransition(position: _slideAnims[slot], child: child),
      );

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, isDark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Bloco 1: Áudio ─────────────────────────────────────────
            _animated(
              0,
              _SectionCard(
                icon: Icons.music_note_rounded,
                iconColor: _TP.accent,
                title: 'Áudio',
                isDark: isDark,
                children: [
                  _VolumeRow(
                    label: 'Música',
                    icon: Icons.library_music_outlined,
                    value: prefs.musicVolume,
                    isDark: isDark,
                    onChanged: notifier.setMusicVolume,
                  ),
                  _Separator(isDark: isDark),
                  _VolumeRow(
                    label: 'Efeitos sonoros',
                    icon: Icons.spatial_audio_off_outlined,
                    value: prefs.sfxVolume,
                    isDark: isDark,
                    onChanged: notifier.setSfxVolume,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Bloco 2: Notificações ──────────────────────────────────
            _animated(
              1,
              _SectionCard(
                icon: Icons.notifications_outlined,
                iconColor: _TP.warning,
                title: 'Notificações',
                isDark: isDark,
                children: [
                  _ToggleRow(
                    label: 'Lembretes e alertas',
                    subtitle: 'Receba dicas e avisos de sequência',
                    icon: Icons.campaign_outlined,
                    value: prefs.notificationsEnabled,
                    isDark: isDark,
                    onChanged: (_) => notifier.toggleNotifications(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Bloco 3: Aparência ─────────────────────────────────────
            _animated(
              2,
              _SectionCard(
                icon: Icons.palette_outlined,
                iconColor: const Color(0xFF72D09C),
                title: 'Aparência',
                isDark: isDark,
                children: [
                  _ToggleRow(
                    label: 'Modo claro',
                    subtitle: 'Altera o tema visual do aplicativo',
                    icon: Icons.light_mode_outlined,
                    value: prefs.lightMode,
                    isDark: isDark,
                    onChanged: (_) => notifier.toggleLightMode(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) =>
      AppBar(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Preferências',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(
            Icons.chevron_left,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de seção reutilizável
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.children,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _TP.textMuted(isDark),
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _TP.cardBg(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _TP.cardBorder(isDark)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de volume com slider
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;
  final bool isDark;

  String get _percent => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _TP.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _TP.textPrimary(isDark),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _percent,
                  key: ValueKey(_percent),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value == 0 ? _TP.textMuted(isDark) : _TP.accentText(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              inactiveTrackColor: _TP.trackInactive(isDark),
              activeTrackColor: _TP.accent,
              thumbColor: _TP.accent,
              overlayColor: _TP.accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mudo',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _TP.textMuted(isDark),
                  ),
                ),
                Text(
                  'Máximo',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _TP.textMuted(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de toggle (Switch)
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? _TP.iconBgOn(isDark) : _TP.iconBgOff(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: value ? _TP.accent : _TP.textMuted(isDark),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _TP.textPrimary(isDark),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _TP.textMuted(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _TP.accent,
            activeTrackColor: _TP.accent.withValues(alpha: 0.45),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Separador interno do card
// ─────────────────────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  const _Separator({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Divider(
          height: 1,
          color: _TP.cardBorder(isDark),
        ),
      );
}
