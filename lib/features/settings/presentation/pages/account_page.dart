import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/login_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local
// ─────────────────────────────────────────────────────────────────────────────

abstract class _Colors {
  static const Color danger        = Color(0xFFFF5963);
  static const Color dangerSubtle  = Color(0x26FF5963);
  static const Color primarySubtle = Color(0x1F72ACD0);
  static const Color divider       = Color(0x1AFFFFFF);
  static const Color textMuted     = Color(0xFF8FA3AE);
  static const Color cardBorder    = Color(0x1AFFFFFF);
  static const Color googleBlue    = Color(0xFF4285F4);
}

// ─────────────────────────────────────────────────────────────────────────────
// Página
//
// Heurísticas de Nielsen aplicadas:
//   #1  Visibilidade: AppBar "Conta" + back deixam clara a localização.
//   #3  Controle e liberdade: todos os sheets têm dismiss via swipe/Cancelar.
//   #4  Consistência: tipografia Nunito, AppColors e padrão de tile idênticos
//       ao settings_page.dart.
//   #5  Prevenção de erros: senha exigida antes de excluir conta; sem ação
//       destrutiva sem confirmação explícita.
//   #6  Reconhecimento: ícones + rótulos descritivos; badge "somente leitura".
//   #8  Design estético e minimalista: seções claras, hierarquia limpa.
//   #9  Recuperação de erros: mensagens inline nos formulários, não modais.
// ─────────────────────────────────────────────────────────────────────────────

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;
  bool _deletingAccount = false;

  static const int _n = 4;
  static const Duration _dur = Duration(milliseconds: 700);
  static const Duration _stagger = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _dur);
    _fades = List.generate(_n, (i) {
      final s = (i * _stagger.inMilliseconds) / _dur.inMilliseconds;
      final e = (s + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(s, e, curve: Curves.easeOut),
      );
    });
    _slides = _fades
        .map(
          (a) => Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(a),
        )
        .toList();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get _isEmailUser {
    final fbUser = ref.read(firebaseAuthProvider).currentUser;
    return fbUser?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: GoogleFonts.nunito(fontSize: 13, color: Colors.white),
      ),
      backgroundColor: error ? _Colors.danger : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ),);
  }

  // ── Editar nome ──────────────────────────────────────────────────────────

  Future<void> _openEditName(String current) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditNameSheet(
        currentName: current,
        onSave: (name) async {
          final either =
              await ref.read(updateDisplayNameProvider)(name: name);
          return either.fold((f) => f.message, (_) => null);
        },
        onSuccess: () => _snack('Nome atualizado com sucesso!'),
      ),
    );
  }

  // ── Alterar senha ────────────────────────────────────────────────────────

  Future<void> _openChangePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSubmit: (current, next) async {
          final either = await ref.read(changePasswordProvider)(
            currentPassword: current,
            newPassword: next,
          );
          return either.fold((f) => f.message, (_) => null);
        },
        onSuccess: () => _snack('Senha alterada com sucesso!'),
      ),
    );
  }

  // ── Excluir conta ────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final isEmail = _isEmailUser;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteAccountDialog(isEmailUser: isEmail),
    );
    if (password == null || !mounted) return;

    setState(() => _deletingAccount = true);
    final either = await ref.read(deleteAccountProvider)(
      password: password.isEmpty ? null : password,
    );
    if (!mounted) return;
    setState(() => _deletingAccount = false);

    either.fold(
      (f) => _snack(f.message, error: true),
      (_) {},
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final email = user?.email ?? '';
    final displayName = user?.displayName ??
        (email.isNotEmpty ? email.split('@').first : 'Usuário');
    final photoUrl = user?.photoUrl;

    if (_deletingAccount) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              // ── 0: card do usuário ───────────────────────────────────────
              _Animated(
                fade: _fades[0],
                slide: _slides[0],
                child: _UserCard(
                  displayName: displayName,
                  email: email,
                  photoUrl: photoUrl,
                ),
              ),
              const SizedBox(height: 32),

              // ── 1: informações pessoais ──────────────────────────────────
              _Animated(
                fade: _fades[1],
                slide: _slides[1],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'INFORMAÇÕES PESSOAIS'),
                    const SizedBox(height: 10),
                    _TileCard(children: [
                      _InfoTile(
                        icon: Icons.badge_outlined,
                        label: 'Nome',
                        value: displayName,
                        onTap: () => _openEditName(displayName),
                      ),
                      const _TileDivider(),
                      _InfoTile(
                        icon: Icons.alternate_email_rounded,
                        label: 'E-mail',
                        value: email,
                        readOnly: true,
                      ),
                    ],),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── 2: segurança ─────────────────────────────────────────────
              _Animated(
                fade: _fades[2],
                slide: _slides[2],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'SEGURANÇA'),
                    const SizedBox(height: 10),
                    _TileCard(children: [
                      if (_isEmailUser)
                        _InfoTile(
                          icon: Icons.lock_outline_rounded,
                          label: 'Senha',
                          value: '••••••••',
                          onTap: _openChangePassword,
                        )
                      else
                        const _InfoTile(
                          icon: Icons.g_mobiledata_rounded,
                          label: 'Provedor de acesso',
                          value: 'Conta Google',
                          readOnly: true,
                          badgeText: 'Vinculado',
                          badgeColor: _Colors.googleBlue,
                        ),
                    ],),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── 3: zona de perigo ────────────────────────────────────────
              _Animated(
                fade: _fades[3],
                slide: _slides[3],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'ZONA DE PERIGO', danger: true),
                    const SizedBox(height: 10),
                    _DangerTile(
                      icon: Icons.delete_forever_outlined,
                      label: 'Excluir conta',
                      subtitle: 'Remove permanentemente todos os seus dados',
                      onTap: _confirmDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          'Conta',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot animado reutilizável (fade + slide)
// ─────────────────────────────────────────────────────────────────────────────

class _Animated extends StatelessWidget {
  const _Animated({
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
// Card do usuário (avatar + nome + e-mail)
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
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
        border: Border.all(color: _Colors.cardBorder),
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: photoUrl, displayName: displayName),
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
                    color: _Colors.textMuted,
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
        border: Border.all(color: AppColors.primary, width: 2),
        color: AppColors.backgroundDark,
      ),
      child: photoUrl != null
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(initials: _initials),
              ),
            )
          : _Initials(initials: _initials),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          initials,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Rótulo de seção
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: danger
                ? _Colors.danger.withValues(alpha:0.85)
                : _Colors.textMuted,
            letterSpacing: 2.2,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Container de tiles (cartão rounded com borda sutil)
// ─────────────────────────────────────────────────────────────────────────────

class _TileCard extends StatelessWidget {
  const _TileCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Colors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Divider(color: _Colors.divider, height: 1),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de informação
// Heurística #6: label pequeno acima do valor torna o tipo de dado imediatamente
// reconhecível sem exigir memorização de posição.
// ─────────────────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.readOnly = false,
    this.badgeText,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool readOnly;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      child: InkWell(
        onTap: readOnly ? null : onTap,
        splashColor:
            readOnly ? Colors.transparent : _Colors.primarySubtle,
        highlightColor: readOnly
            ? Colors.transparent
            : _Colors.primarySubtle.withValues(alpha:0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Ícone
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Colors.primarySubtle,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),

              // Label + valor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _Colors.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Trailing: badge | chevron | cadeado
              if (badgeText != null)
                _Badge(
                  text: badgeText!,
                  color: badgeColor ?? AppColors.primary,
                )
              else if (!readOnly)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withValues(alpha:0.6),
                  size: 22,
                )
              else
                Icon(
                  Icons.lock_rounded,
                  color: _Colors.textMuted.withValues(alpha:0.4),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha:0.3)),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile de ação destrutiva
// Heurística #4: cor vermelha + borda sinalizam claramente ação perigosa.
// ─────────────────────────────────────────────────────────────────────────────

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _Colors.dangerSubtle,
        highlightColor: _Colors.dangerSubtle.withValues(alpha:0.4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _Colors.danger.withValues(alpha:0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Colors.dangerSubtle,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _Colors.danger, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _Colors.danger,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _Colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: _Colors.danger.withValues(alpha:0.6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Componentes compartilhados pelos bottom sheets
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      validator: validator,
      autofocus: autofocus,
      style: GoogleFonts.nunito(fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 14, color: _Colors.textMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.backgroundDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Colors.danger, width: 2),
        ),
        errorStyle:
            GoogleFonts.nunito(fontSize: 12, color: _Colors.danger),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscure, required this.onToggle});

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(
          obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: _Colors.textMuted,
          size: 20,
        ),
        onPressed: onToggle,
      );
}

Widget _primaryButton({
  required String label,
  required VoidCallback? onPressed,
  required bool loading,
  Color? backgroundColor,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            (backgroundColor ?? AppColors.primary).withValues(alpha:0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: editar nome
// ─────────────────────────────────────────────────────────────────────────────

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({
    required this.currentName,
    required this.onSave,
    required this.onSuccess,
  });

  final String currentName;
  final Future<String?> Function(String name) onSave;
  final VoidCallback onSuccess;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await widget.onSave(_ctrl.text.trim());
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 24),
              Text(
                'Editar nome',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _DarkTextField(
                controller: _ctrl,
                label: 'Nome completo',
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Mínimo 2 caracteres'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: _Colors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _primaryButton(
                label: 'Salvar',
                onPressed: _loading ? null : _submit,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet: alterar senha
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({
    required this.onSubmit,
    required this.onSuccess,
  });

  final Future<String?> Function(String current, String next) onSubmit;
  final VoidCallback onSuccess;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await widget.onSubmit(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop();
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 24),
                Text(
                  'Alterar senha',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _DarkTextField(
                  controller: _currentCtrl,
                  label: 'Senha atual',
                  obscureText: _obscureCurrent,
                  autofocus: true,
                  suffixIcon: _EyeButton(
                    obscure: _obscureCurrent,
                    onToggle: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
                ),
                const SizedBox(height: 12),
                _DarkTextField(
                  controller: _newCtrl,
                  label: 'Nova senha',
                  obscureText: _obscureNew,
                  suffixIcon: _EyeButton(
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),
                _DarkTextField(
                  controller: _confirmCtrl,
                  label: 'Confirmar nova senha',
                  obscureText: _obscureConfirm,
                  suffixIcon: _EyeButton(
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) => v != _newCtrl.text
                      ? 'As senhas não coincidem'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: _Colors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _primaryButton(
                  label: 'Alterar senha',
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog: excluir conta
// Heurística #5 – Prevenção de erros: senha obrigatória para e-mail, aviso
// claro sobre irreversibilidade, CTA nomeado como "Excluir definitivamente".
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.isEmailUser});
  final bool isEmailUser;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _Colors.dangerSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: _Colors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Excluir conta',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta ação é permanente e irreversível. Todo o seu progresso, conquistas e dados serão removidos.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _Colors.textMuted,
              height: 1.5,
            ),
          ),
          if (widget.isEmailUser) ...[
            const SizedBox(height: 16),
            Text(
              'Digite sua senha para confirmar:',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (_, setLocal) => TextField(
                controller: _ctrl,
                obscureText: _obscure,
                style:
                    GoogleFonts.nunito(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Senha atual',
                  hintStyle: GoogleFonts.nunito(color: _Colors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _Colors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _Colors.danger, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: _Colors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setLocal(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(null),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _Colors.divider),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(widget.isEmailUser ? _ctrl.text : ''),
            style: FilledButton.styleFrom(
              backgroundColor: _Colors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Excluir definitivamente',
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
