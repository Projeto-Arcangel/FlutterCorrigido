import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/login_controller.dart';
import 'forgot_password_form.dart';
import 'login_form.dart';
import 'register_form.dart';

enum AuthPanelView { login, register, forgotPassword }

const double _panelWidth = 440;
const double _compactBreakpoint = 600;

/// Abre o painel lateral de autenticação por cima da página atual.
///
/// Fecha com o X, com Esc ou clicando fora. Como é uma rota modal, todo o
/// estado (inclusive as senhas digitadas) é descartado ao fechar.
Future<void> showAuthPanel(
  BuildContext context, {
  AuthPanelView initialView = AuthPanelView.login,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar painel de acesso',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
    pageBuilder: (context, _, __) {
      final width = MediaQuery.sizeOf(context).width;
      return SizedBox(
        width: width < _compactBreakpoint ? width : _panelWidth,
        height: double.infinity,
        child: AuthPanel(initialView: initialView),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AuthPanel extends ConsumerStatefulWidget {
  const AuthPanel({super.key, required this.initialView});

  final AuthPanelView initialView;

  @override
  ConsumerState<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends ConsumerState<AuthPanel> {
  late AuthPanelView _view = widget.initialView;

  /// Cadastro ou recuperação enviando: bloqueia abas e "voltar" para o
  /// resultado (sucesso ou erro) não ser descartado junto com o formulário.
  bool _formBusy = false;

  void _show(AuthPanelView view) {
    // Tira o foco (e o teclado virtual) do formulário que está saindo; o que
    // entra foca o próprio primeiro campo (ver focusAfterFirstFrame).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _view = view;
      _formBusy = false;
    });
  }

  void _setFormBusy(bool busy) {
    if (mounted && busy != _formBusy) setState(() => _formBusy = busy);
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  String get _routeLabel => switch (_view) {
        AuthPanelView.login => 'Entrar no Arcangel',
        AuthPanelView.register => 'Criar conta no Arcangel',
        AuthPanelView.forgotPassword => 'Recuperar senha',
      };

  Widget _buildForm({required bool autofocus}) => switch (_view) {
        AuthPanelView.login => LoginForm(
            onForgotPassword: () => _show(AuthPanelView.forgotPassword),
            onSwitchToRegister: () => _show(AuthPanelView.register),
            onAuthenticated: _close,
            autofocus: autofocus,
          ),
        AuthPanelView.register => RegisterForm(
            onSwitchToLogin: () => _show(AuthPanelView.login),
            onBusyChanged: _setFormBusy,
            autofocus: autofocus,
          ),
        AuthPanelView.forgotPassword => ForgotPasswordForm(
            onBackToLogin: () => _show(AuthPanelView.login),
            onBusyChanged: _setFormBusy,
            autofocus: autofocus,
          ),
      };

  @override
  Widget build(BuildContext context) {
    // Observar o controller de login o mantém vivo enquanto o painel estiver
    // aberto; durante qualquer envio as abas e o "voltar" ficam bloqueados.
    final locked = ref.watch(loginControllerProvider).isLoading || _formBusy;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < _compactBreakpoint;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Semantics(
        namesRoute: true,
        label: _routeLabel,
        child: Material(
          color: isDark ? AppColors.backgroundDark : AppColors.background,
          elevation: 24,
          clipBehavior: Clip.antiAlias,
          shape: compact
              ? const RoundedRectangleBorder()
              : const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(24)),
                ),
          child: SafeArea(
            child: Column(
              children: [
                _PanelTopBar(
                  showBack: _view == AuthPanelView.forgotPassword,
                  onBack: locked ? null : () => _show(AuthPanelView.login),
                  onClose: _close,
                ),
                if (_view != AuthPanelView.forgotPassword)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _AuthTabs(
                      selected: _view,
                      onSelected: locked ? null : _show,
                    ),
                  ),
                Expanded(
                  // Sem Scaffold, o teclado virtual não encolhe a área
                  // rolável sozinho: desconta a altura dele para os últimos
                  // campos e o botão de enviar continuarem alcançáveis.
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      // Sem crossfade de propósito: o formulário que sai tem
                      // de ser descartado no MESMO frame. Ao ser descartado,
                      // o AutofillGroup dele encerra a conexão de digitação
                      // ativa na web; se ele sobrevivesse à animação,
                      // derrubaria o foco do campo do formulário que entra.
                      child: _FadeIn(
                        key: ValueKey(_view),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: _buildForm(autofocus: !compact),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: child,
    );
  }
}

class _PanelTopBar extends StatelessWidget {
  const _PanelTopBar({
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              tooltip: 'Voltar para o login',
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: iconColor),
            )
          else
            const SizedBox(width: 12),
          const AppLogo(size: 32),
          const SizedBox(width: 8),
          Text(
            'Arcangel',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Fechar',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.selected, required this.onSelected});

  final AuthPanelView selected;
  final ValueChanged<AuthPanelView>? onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (view, label) in const [
            (AuthPanelView.login, 'Entrar'),
            (AuthPanelView.register, 'Criar conta'),
          ])
            Expanded(
              child: _TabButton(
                label: label,
                selected: view == selected,
                onTap: onSelected == null ? null : () => onSelected!(view),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? AppColors.backgroundDark : Colors.white;
    // Inativa no claro: #4B5563 sobre #F1F4F8 ≈ 6,8:1 (textSecondary dava 4,3:1).
    final textColor = selected
        ? (isDark ? AppColors.textOnDark : AppColors.textPrimary)
        : (isDark ? const Color(0xFF8FA3AE) : const Color(0xFF4B5563));

    return Semantics(
      button: true,
      selected: selected,
      enabled: selected || onTap != null,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
