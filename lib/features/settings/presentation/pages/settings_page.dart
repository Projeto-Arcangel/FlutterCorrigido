import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local de apoio — valores invariantes ao modo
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color danger        = Color(0xFFFF5963);
  static const Color primarySubtle = Color(0x1F72ACD0);
  static const Color textMuted     = Color(0xFF8FA3AE);

  // Dependem do modo
  static Color cardBg(bool dark)     => dark ? AppColors.surfaceDark  : Colors.white;
  static Color cardBorder(bool dark) => dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color divider(bool dark)    => dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color textPrimary(bool dark) => dark ? Colors.white : AppColors.textPrimary;
  static Color bgPage(bool dark)     => dark ? AppColors.backgroundDark : AppColors.background;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidade local
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
// Page
// ─────────────────────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  static const int _animCount = 4;
  static const Duration _totalDuration = Duration(milliseconds: 700);
  static const Duration _stagger = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);

    _fadeAnims = List.generate(_animCount, (i) {
      final start = (i * _stagger.inMilliseconds) / _totalDuration.inMilliseconds;
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

  void _onContaTap() => context.push(AppRoutes.account);
  void _onPreferencesTap() => context.push(AppRoutes.preferences);

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
      backgroundColor: _C.bgPage(isDark),
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
                          'Usuário',
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
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(
                                color: _C.divider(isDark),
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            _AnimatedSlot(
              fade: _fadeAnims[3],
              slide: _slideAnims[3],
              child: _SignOutButton(onTap: _onSignOutTap, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) => AppBar(
        backgroundColor: _C.bgPage(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Configurações',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary(isDark),
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(
            Icons.chevron_left,
            color: _C.textPrimary(isDark),
            size: 28,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot animado reutilizável
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
// Bloco de informações do usuário
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
        color: _C.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cardBorder(isDark)),
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: photoUrl, displayName: displayName, isDark: isDark),
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
                    color: _C.textPrimary(isDark),
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
                    color: _C.textMuted,
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
  const _Avatar({this.photoUrl, required this.displayName, required this.isDark});
  final String? photoUrl;
  final String displayName;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        color: _C.bgPage(isDark),
      ),
      child: photoUrl != null
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _InitialsAvatar(name: displayName),
              ),
            )
          : _InitialsAvatar(name: displayName),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});
  final String name;

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          _initials,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
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
            color: _C.textMuted,
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
      color: _C.cardBg(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _C.primarySubtle,
        highlightColor: _C.primarySubtle.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _C.cardBorder(isDark)),
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
                        color: _C.textPrimary(isDark),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary.withValues(alpha: 0.6),
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
        color: _C.primarySubtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.primary, size: 22),
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
        border: Border(
          top: BorderSide(color: _C.divider(isDark)),
        ),
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
            backgroundColor: _C.danger,
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
      backgroundColor: _C.cardBg(isDark),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Sair da conta?',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _C.textPrimary(isDark),
        ),
      ),
      content: Text(
        'Você será desconectado e precisará entrar novamente para acessar o Arcangel.',
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _C.textMuted,
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
              foregroundColor: _C.textPrimary(isDark),
              side: BorderSide(color: _C.cardBorder(isDark)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _C.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Sair',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
