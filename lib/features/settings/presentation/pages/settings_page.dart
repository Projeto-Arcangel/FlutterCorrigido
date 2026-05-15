import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local (complementa AppColors para a tela de settings)
// ─────────────────────────────────────────────────────────────────────────────

abstract class _SettingsColors {
  static const Color danger = Color(0xFFFF5963);
  static const Color dangerSubtle = Color(0x26FF5963);
  static const Color primarySubtle = Color(0x1F72ACD0);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color cardBorder = Color(0x1AFFFFFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Entidade local: metadado de cada tile de configuração
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

/// Heurística #1 – Visibilidade: o título "Configurações" e o back-button
/// deixam claro onde o usuário está e como sair.
///
/// Heurística #3 – Controle e liberdade: botão de voltar sempre visível;
/// logout exige confirmação para evitar saídas acidentais.
///
/// Heurística #4 – Consistência: tipografia Nunito, cores AppColors e
/// estrutura de AppBar idêntica ao resto do app.
///
/// Heurística #5 – Prevenção de erros: dialog de confirmação antes de
/// ações destrutivas (Sair da conta).
///
/// Heurística #6 – Reconhecimento: ícones descritivos ao lado de cada
/// item, sem exigir memorização de posição.
///
/// Heurística #8 – Design estético e minimalista: layout limpo, sem
/// informação irrelevante, hierarquia visual clara.
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

  // 4 elementos animados: header-info, seção Conta, seção Preferências,
  // botão Sair — cada um com delay incremental de 80 ms.
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

  // ── Helpers de navegação / ação ──────────────────────────────────────────

  void _onContaTap() {
    context.push(AppRoutes.account);
  }

  void _onPreferencesTap() {
    context.push(AppRoutes.preferences);
  }

  /// Heurística #5 – Prevenção de erros: confirma antes de uma ação
  /// irreversível (logout) com linguagem clara e ação cancelável.
  Future<void> _onSignOutTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _SignOutDialog(),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(loginControllerProvider.notifier).signOut();
  }

  SnackBar _snack(String msg) => SnackBar(
        content: Text(msg, style: _bodyStyle()),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      );

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                children: [
                  // ── Bloco: avatar + nome + e-mail ───────────────────
                  _AnimatedSlot(
                    fade: _fadeAnims[0],
                    slide: _slideAnims[0],
                    child: _UserInfoCard(
                      displayName: user?.displayName ?? user?.email?.split('@').first ?? 'Usuário',
                      email: user?.email ?? '',
                      photoUrl: user?.photoUrl,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Label de seção ──────────────────────────────────
                  _SectionLabel(label: 'GERAL'),
                  const SizedBox(height: 10),

                  // ── Tiles: Conta e Preferências ─────────────────────
                  ...List.generate(tiles.length, (i) {
                    return _AnimatedSlot(
                      fade: _fadeAnims[i + 1],
                      slide: _slideAnims[i + 1],
                      child: Column(
                        children: [
                          _SettingsTileWidget(tile: tiles[i]),
                          if (i < tiles.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(
                                color: _SettingsColors.divider,
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

            // ── Botão fixo no rodapé: Sair da conta ────────────────
            _AnimatedSlot(
              fade: _fadeAnims[3],
              slide: _slideAnims[3],
              child: _SignOutButton(onTap: _onSignOutTap),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Configurações',
          style: _titleStyle(),
        ),
        leading: IconButton(
          tooltip: 'Voltar',            // Heurística #1
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
// Bloco de informações do usuário
// Heurística #1 – Visibilidade: o usuário vê quem está logado de imediato.
// ─────────────────────────────────────────────────────────────────────────────

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String displayName;
  final String email;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SettingsColors.cardBorder),
      ),
      child: Row(
        children: [
          // Avatar
          _Avatar(photoUrl: photoUrl, displayName: displayName),
          const SizedBox(width: 16),

          // Nome + e-mail
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
                    color: Colors.white,
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
                    color: _SettingsColors.textMuted,
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
  const _Avatar({this.photoUrl, required this.displayName});
  final String? photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
        color: AppColors.backgroundDark,
      ),
      child: photoUrl != null
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _InitialsAvatar(name: displayName),
              ),
            )
          : _InitialsAvatar(name: displayName),
    );
  }
}

/// Exibe as iniciais do nome como fallback — mais elegante do que um ícone
/// genérico e garante personalização mesmo sem foto.
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
// Label de seção (rótulo agrupador)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _SettingsColors.textMuted,
            letterSpacing: 2.2,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de configuração
// Heurística #6 – Reconhecimento: ícone + label + subtítulo tornam a função
// imediatamente reconhecível sem que o usuário precise decorar posições.
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTileWidget extends StatelessWidget {
  const _SettingsTileWidget({required this.tile});
  final _SettingsTile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _SettingsColors.primarySubtle,
        highlightColor: _SettingsColors.primarySubtle.withOpacity(0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _SettingsColors.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Ícone com fundo sutil
              _TileIcon(icon: tile.icon, danger: tile.danger),
              const SizedBox(width: 16),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.label,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tile.danger
                            ? _SettingsColors.danger
                            : Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tile.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _SettingsColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron direito — Heurística #4 (padrão reconhecível de navegação)
              Icon(
                Icons.chevron_right_rounded,
                color: tile.danger
                    ? _SettingsColors.danger.withOpacity(0.6)
                    : AppColors.primary.withOpacity(0.6),
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
  const _TileIcon({required this.icon, required this.danger});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? _SettingsColors.dangerSubtle : _SettingsColors.primarySubtle;
    final fg = danger ? _SettingsColors.danger : AppColors.primary;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão de logout fixo no rodapé
// Heurística #4 – Consistência: posição fixa e cor vermelha sinalizam
// que esta é uma ação destrutiva — diferente dos tiles de navegação.
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _SettingsColors.divider)),
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
            backgroundColor: _SettingsColors.danger,
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
// Heurística #5 – Prevenção de erros: nunca executa uma ação irreversível
// sem confirmação explícita do usuário; linguagem clara e cancelável.
// Heurística #9 – Ajuda a recuperar de erros: o botão "Cancelar" devolve
// o controle sem consequências.
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Sair da conta?',
        style: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      content: Text(
        'Você será desconectado e precisará entrar novamente para acessar o Arcangel.',
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _SettingsColors.textMuted,
          height: 1.5,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        // Cancelar — Heurística #3
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _SettingsColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Cancelar',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Confirmar
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _SettingsColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Sair',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de tipografia — centraliza estilos para facilitar manutenção
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _titleStyle() => GoogleFonts.nunito(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    );

TextStyle _bodyStyle() => GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    );