import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local — tons esverdeados exclusivos da área do professor.
// Espelha a estrutura de _C em settings_page.dart com accent verde.
// ─────────────────────────────────────────────────────────────────────────────

abstract class _TC {
  static const Color accent       = Color(0xFF72D082);
  static const Color accentSubtle = Color(0x1F72D082);
  static const Color danger       = Color(0xFFFF5963);
  static const Color textMuted    = Color(0xFF8FA3AE);

  static Color cardBg(bool dark)      => dark ? AppColors.surfaceDark  : Colors.white;
  static Color cardBorder(bool dark)  => dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color divider(bool dark)     => dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color textPrimary(bool dark) => dark ? Colors.white : AppColors.textPrimary;
  static Color bgPage(bool dark)      => dark ? AppColors.backgroundDark : AppColors.background;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidade local de tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// TeacherSettingsPage
//
// Heurística #1 – Visibilidade: AppBar "Configurações" + back-button.
// Heurística #3 – Controle: conta e preferências acessíveis em 1 toque.
// Heurística #4 – Consistência: mesma estrutura da SettingsPage do aluno,
//                  paleta verde exclusiva do professor.
// Heurística #8 – Minimalismo: hierarquia clara, sem ruído visual.
// ─────────────────────────────────────────────────────────────────────────────

class TeacherSettingsPage extends ConsumerStatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  ConsumerState<TeacherSettingsPage> createState() =>
      _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends ConsumerState<TeacherSettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const int _animCount = 5;
  static const Duration _totalDuration = Duration(milliseconds: 700);
  static const Duration _stagger = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);

    _fadeAnims = List.generate(_animCount, (i) {
      final start =
          (i * _stagger.inMilliseconds) / _totalDuration.inMilliseconds;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnims = _fadeAnims
        .map(
          (anim) => Tween<Offset>(
            begin: const Offset(0, 0.12),
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

  void _onContaTap() => context.push(AppRoutes.teacherAccount);
  void _onPreferencesTap() =>
      context.push(AppRoutes.teacherSettingsPreferences);

  Future<void> _onSignOutTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutDialog(),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(loginControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).valueOrNull;

    final tiles = <_SettingsTile>[
      _SettingsTile(
        icon: Icons.manage_accounts_outlined,
        label: 'Conta',
        subtitle: 'Edite seus dados pessoais e senha',
        onTap: _onContaTap,
      ),
      _SettingsTile(
        icon: Icons.tune_outlined,
        label: 'Preferências',
        subtitle: 'Notificações, idioma e aparência',
        onTap: _onPreferencesTap,
      ),
    ];

    return Scaffold(
      backgroundColor: _TC.bgPage(isDark),
      appBar: _buildAppBar(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                children: [
                  _AnimatedSlot(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: _UserInfoCard(
                      displayName: user?.displayName ??
                          user?.email.split('@').first ??
                          'Professor',
                      email: user?.email ?? '',
                      photoUrl: user?.photoUrl,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SectionLabel(label: 'GERAL', isDark: isDark),
                  const SizedBox(height: 10),
                  ...List.generate(tiles.length, (i) {
                    return _AnimatedSlot(
                      fade: _fadeAnims[i + 1],
                      slide: _slideAnims[i + 1],
                      child: Column(
                        children: [
                          _SettingsTileWidget(tile: tiles[i], isDark: isDark),
                          if (i < tiles.length - 1)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(
                                color: _TC.divider(isDark),
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 28),
                  _SectionLabel(label: 'SUPORTE', isDark: isDark),
                  const SizedBox(height: 10),
                  _AnimatedSlot(
                    fade: _fadeAnims[3],
                    slide: _slideAnims[3],
                    child: _SupportCard(isDark: isDark),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _AnimatedSlot(
              fade: _fadeAnims[4],
              slide: _slideAnims[4],
              child: _SignOutButton(onTap: _onSignOutTap, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) => AppBar(
        backgroundColor: _TC.bgPage(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Configurações',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _TC.textPrimary(isDark),
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(
            Icons.chevron_left,
            color: _TC.textPrimary(isDark),
            size: 28,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot animado reutilizável (fade + slide)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedSlot extends StatelessWidget {
  const _AnimatedSlot({
    required this.fade,
    required this.slide,
    required this.child,
  });
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de informações do usuário
// ─────────────────────────────────────────────────────────────────────────────

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.displayName,
    required this.email,
    required this.isDark,
    this.photoUrl,
  });
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _TC.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _TC.cardBorder(isDark)),
      ),
      child: Row(
        children: [
          _Avatar(
            photoUrl: photoUrl,
            displayName: displayName,
            isDark: isDark,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _TC.textPrimary(isDark),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _TC.textMuted,
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    this.photoUrl,
    required this.displayName,
    required this.isDark,
  });
  final String? photoUrl;
  final String displayName;
  final bool isDark;

  String get _initials {
    final parts = displayName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _TC.accent, width: 2),
        color: _TC.bgPage(isDark),
      ),
      child: photoUrl != null
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _InitialsWidget(initials: _initials),
              ),
            )
          : _InitialsWidget(initials: _initials),
    );
  }
}

class _InitialsWidget extends StatelessWidget {
  const _InitialsWidget({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _TC.accent,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Label de seção
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _TC.textMuted,
            letterSpacing: 2.2,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de configuração
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTileWidget extends StatelessWidget {
  const _SettingsTileWidget({required this.tile, required this.isDark});
  final _SettingsTile tile;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TC.cardBg(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _TC.accentSubtle,
        highlightColor: _TC.accentSubtle.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _TC.cardBorder(isDark)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _TileIcon(icon: tile.icon),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _TC.textPrimary(isDark),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _TC.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _TC.accent.withValues(alpha: 0.6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _TC.accentSubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _TC.accent, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de suporte — aviso de contato por e-mail (visível para qualquer usuário).
// ─────────────────────────────────────────────────────────────────────────────

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _TC.cardBg(isDark),
        border: Border.all(color: _TC.cardBorder(isDark)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Caso precise de suporte, envie um email para '
        'arcangel.admin@gmail.com. Responderemos o mais rápido possível.',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: _TC.textPrimary(isDark),
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão de logout fixo no rodapé
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _TC.divider(isDark))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(
            'Sair da conta',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _TC.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de confirmação de logout
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: _TC.cardBg(isDark),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Sair da conta?',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _TC.textPrimary(isDark),
        ),
      ),
      content: Text(
        'Você será desconectado e precisará entrar novamente para acessar o Arcangel.',
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _TC.textMuted,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _TC.textPrimary(isDark),
              side: BorderSide(color: _TC.cardBorder(isDark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancelar',
              style:
                  GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _TC.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Sair',
              style:
                  GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
