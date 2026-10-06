import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/login_controller.dart';
import 'auth_form_parts.dart';
import 'auth_inline_message.dart';
import 'auth_text_field.dart';
import 'auth_validators.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({
    super.key,
    required this.onForgotPassword,
    required this.onSwitchToRegister,
    required this.onAuthenticated,
    this.autofocus = false,
  });

  final VoidCallback onForgotPassword;
  final VoidCallback onSwitchToRegister;

  /// Chamado quando o login por e-mail/senha dá certo. O destino (app,
  /// escolha de perfil...) quem decide é o redirect do router.
  final VoidCallback onAuthenticated;
  final bool autofocus;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) focusAfterFirstFrame(this, _emailFocus);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(loginControllerProvider).isLoading) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(loginControllerProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  void _signInWithGoogle() {
    setState(() => _error = null);
    // Na web o OAuth redireciona a página inteira; a sessão volta pelo
    // authState e o router decide o destino.
    ref.read(loginControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(loginControllerProvider).isLoading;

    ref.listen(loginControllerProvider, (_, next) {
      if (next.isLoading) return;
      next.whenOrNull(
        data: (user) {
          if (user == null) return;
          // Só com login aceito o navegador pode oferecer salvar a senha.
          TextInput.finishAutofillContext();
          widget.onAuthenticated();
        },
        error: (error, _) => setState(() => _error = ErrorMessages.from(error)),
      );
    });

    return Form(
      key: _formKey,
      // cancel: senha recusada ou abandonada não vira oferta de "salvar".
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFormHeader(
              title: 'Bem-vindo de volta!',
              subtitle: 'Entre para continuar sua jornada de estudos.',
            ),
            AuthInlineError(message: _error),
            AuthTextField(
              controller: _emailCtrl,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              validator: AuthValidators.email,
              focusNode: _emailFocus,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordCtrl,
              label: 'Senha',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              validator: AuthValidators.password,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _LinkButton(
                label: 'Esqueci minha senha',
                onPressed: loading ? null : widget.onForgotPassword,
              ),
            ),
            const SizedBox(height: 8),
            AppButton(onPressed: _submit, label: 'Entrar', loading: loading),
            const SizedBox(height: 20),
            const _OrDivider(),
            const SizedBox(height: 20),
            _GoogleButton(onPressed: loading ? null : _signInWithGoogle),
            const SizedBox(height: 24),
            AuthSwitchPrompt(
              question: 'Ainda não tem conta?',
              actionLabel: 'Criar conta',
              onPressed: loading ? null : widget.onSwitchToRegister,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor:
            isDark ? AppColors.primary : AppColors.primaryTextOnLight,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? Colors.white12 : Colors.black12;
    final textColor = isDark
        ? AppColors.textOnDark.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    return Row(
      children: [
        Expanded(child: Divider(color: lineColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
        Expanded(child: Divider(color: lineColor)),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const FaIcon(FontAwesomeIcons.google, size: 18),
        label: const Text(
          'Continuar com o Google',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.socialButton,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
