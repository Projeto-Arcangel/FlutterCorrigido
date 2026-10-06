import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../providers/auth_providers.dart';
import 'auth_form_parts.dart';
import 'auth_inline_message.dart';
import 'auth_text_field.dart';
import 'auth_validators.dart';

class ForgotPasswordForm extends ConsumerStatefulWidget {
  const ForgotPasswordForm({
    super.key,
    required this.onBackToLogin,
    this.onBusyChanged,
    this.autofocus = false,
  });

  final VoidCallback onBackToLogin;

  /// Avisa quem hospeda o formulário que um envio começou/terminou.
  final ValueChanged<bool>? onBusyChanged;
  final bool autofocus;

  @override
  ConsumerState<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends ConsumerState<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) focusAfterFirstFrame(this, _emailFocus);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    setState(() => _loading = loading);
    widget.onBusyChanged?.call(loading);
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true);
    final result = await ref.read(sendPasswordResetProvider)(
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;

    _setLoading(false);
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (_) => setState(() => _sent = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      // Neutro: não confirma se o e-mail tem conta (o Supabase também não).
      return AuthSuccessView(
        icon: Icons.mark_email_read_outlined,
        title: 'Verifique seu e-mail',
        message: 'Se existir uma conta com ${_emailCtrl.text.trim()}, você '
            'receberá um link para redefinir a senha. Não chegou em alguns '
            'minutos? Verifique o spam.',
        actionLabel: 'Voltar para o login',
        onAction: widget.onBackToLogin,
      );
    }

    return Form(
      key: _formKey,
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFormHeader(
              title: 'Esqueceu sua senha?',
              subtitle: 'Informe o e-mail da sua conta e enviaremos um link '
                  'para você criar uma nova senha.',
            ),
            AuthInlineError(message: _error),
            AuthTextField(
              controller: _emailCtrl,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
              focusNode: _emailFocus,
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: _submit,
              label: 'Enviar link',
              loading: _loading,
            ),
            const SizedBox(height: 12),
            AuthSwitchPrompt(
              question: 'Lembrou a senha?',
              actionLabel: 'Voltar para o login',
              onPressed: _loading ? null : widget.onBackToLogin,
            ),
          ],
        ),
      ),
    );
  }
}
