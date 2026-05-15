import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado das preferências (Riverpod)
// Segue o padrão do projeto: Provider simples com StateNotifier
// ─────────────────────────────────────────────────────────────────────────────

class PreferencesState {
  final double musicVolume;
  final double sfxVolume;
  final bool notificationsEnabled;
  final bool lightMode;

  const PreferencesState({
    this.musicVolume = 0.3,
    this.sfxVolume = 0.6,
    this.notificationsEnabled = true,
    this.lightMode = false,
  });

  PreferencesState copyWith({
    double? musicVolume,
    double? sfxVolume,
    bool? notificationsEnabled,
    bool? lightMode,
  }) {
    return PreferencesState(
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lightMode: lightMode ?? this.lightMode,
    );
  }
}

class PreferencesNotifier extends StateNotifier<PreferencesState> {
  PreferencesNotifier() : super(const PreferencesState());

  void setMusicVolume(double v) => state = state.copyWith(musicVolume: v);
  void setSfxVolume(double v) => state = state.copyWith(sfxVolume: v);
  void toggleNotifications() =>
      state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  void toggleLightMode() =>
      state = state.copyWith(lightMode: !state.lightMode);
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, PreferencesState>(
  (_) => PreferencesNotifier(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local
// ─────────────────────────────────────────────────────────────────────────────

abstract class _PrefsColors {
  static const Color cardBorder = Color(0x1AFFFFFF);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color trackInactive = Color(0xFF2E373E);
  static const Color toggleInactive = Color(0xFF3D4A54);
  static const Color warningSubtle = Color(0x1AFFD166);
  static const Color warning = Color(0xFFFFD166);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page principal
//
// Heurística #1 – Visibilidade: título + back-button deixam claro o contexto.
// Heurística #3 – Controle e liberdade: botão Voltar sempre visível.
// Heurística #4 – Consistência: mesma AppBar, tipografia e cores do app.
// Heurística #5 – Prevenção de erros: toggles com estado visual explícito.
// Heurística #6 – Reconhecimento: ícones + rótulos em todos os controles.
// Heurística #8 – Minimalismo: sem informação irrelevante, hierarquia clara.
// ─────────────────────────────────────────────────────────────────────────────

class PreferencesPage extends ConsumerStatefulWidget {
  const PreferencesPage({super.key});

  @override
  ConsumerState<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends ConsumerState<PreferencesPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  // 3 blocos animados: áudio, notificações, aparência
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // ── Bloco 1: Áudio ────────────────────────────────────────
            _animated(
              0,
              _SectionCard(
                icon: Icons.music_note_rounded,
                iconColor: AppColors.primary,
                title: 'Áudio',
                children: [
                  _VolumeRow(
                    label: 'Música',
                    icon: Icons.library_music_outlined,
                    value: prefs.musicVolume,
                    onChanged: notifier.setMusicVolume,
                  ),
                  const _Separator(),
                  _VolumeRow(
                    label: 'Efeitos sonoros',
                    icon: Icons.spatial_audio_off_outlined,
                    value: prefs.sfxVolume,
                    onChanged: notifier.setSfxVolume,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Bloco 2: Notificações ─────────────────────────────────
            _animated(
              1,
              _SectionCard(
                icon: Icons.notifications_outlined,
                iconColor: _PrefsColors.warning,
                title: 'Notificações',
                children: [
                  _ToggleRow(
                    label: 'Lembretes e alertas',
                    subtitle: 'Receba dicas e avisos de sequência',
                    icon: Icons.campaign_outlined,
                    value: prefs.notificationsEnabled,
                    onChanged: (_) => notifier.toggleNotifications(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Bloco 3: Aparência ────────────────────────────────────
            _animated(
              2,
              _SectionCard(
                icon: Icons.palette_outlined,
                iconColor: const Color(0xFF72D09C),
                title: 'Aparência',
                children: [
                  _ToggleRow(
                    label: 'Modo claro',
                    subtitle: 'Altera o tema visual do aplicativo',
                    icon: Icons.light_mode_outlined,
                    value: prefs.lightMode,
                    onChanged: (_) => notifier.toggleLightMode(),
                    // Heurística #5: aviso sobre recurso ainda não funcional
                    badge: 'Em breve',
                    disabled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Preferências',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(
            Icons.chevron_left,
            color: Colors.white,
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label de seção com ícone decorativo
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
                  color: _PrefsColors.textMuted,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),

        // Container do card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _PrefsColors.cardBorder),
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
//
// Heurística #1: valor percentual exibido ao lado do label para feedback
//               imediato — o usuário sabe exatamente em que nível está.
// Heurística #6: ícone + rótulo tornam a função reconhecível sem instrução.
// ─────────────────────────────────────────────────────────────────────────────

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  String get _percent => '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + ícone + valor percentual
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Heurística #1 – visibilidade do estado
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _percent,
                  key: ValueKey(_percent),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: value == 0
                        ? _PrefsColors.textMuted
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Slider customizado
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: _PrefsColors.trackInactive,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: AppColors.primary.withOpacity(0.15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),

          // Rótulos min/max – Heurística #6 (reconhecimento sem memorização)
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
                    color: _PrefsColors.textMuted,
                  ),
                ),
                Text(
                  'Máximo',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _PrefsColors.textMuted,
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
//
// Heurística #1: cor do switch muda com o estado — on=azul, off=cinza.
// Heurística #4: padrão visual de toggle consistente com o restante do app.
// Heurística #5: badge "Em breve" previne frustração com opção desabilitada.
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.badge,
    this.disabled = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? badge;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: AbsorbPointer(
        absorbing: disabled,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // Ícone com fundo sutil
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: value ? AppColors.primary : _PrefsColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          _Badge(label: badge!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _PrefsColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Switch customizado
              _AppSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Switch no estilo do app
// ─────────────────────────────────────────────────────────────────────────────

class _AppSwitch extends StatelessWidget {
  const _AppSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: AppColors.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: _PrefsColors.toggleInactive,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge informativo (ex: "Em breve")
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _PrefsColors.warningSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _PrefsColors.warning.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _PrefsColors.warning,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Separador interno do card
// ─────────────────────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Divider(height: 1, color: _PrefsColors.divider),
      );
}