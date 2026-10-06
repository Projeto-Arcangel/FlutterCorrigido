import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../providers/auth_providers.dart';
import 'auth_form_parts.dart';
import 'auth_inline_message.dart';
import 'auth_text_field.dart';
import 'auth_validators.dart';
import 'password_strength_meter.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({
    super.key,
    required this.onSwitchToLogin,
    this.onBusyChanged,
    this.autofocus = false,
  });

  final VoidCallback onSwitchToLogin;

  /// Avisa quem hospeda o formulário que um envio começou/terminou.
  final ValueChanged<bool>? onBusyChanged;
  final bool autofocus;

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  bool _loading = false;
  String? _error;
  String? _registeredEmail;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) focusAfterFirstFrame(this, _nameFocus);
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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
    final email = _emailCtrl.text.trim();
    final result = await ref.read(registerUserProvider).call(
          email: email,
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text.trim(),
          studentId: _studentIdCtrl.text.trim().toUpperCase(),
        );
    if (!mounted) return;

    _setLoading(false);
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (_) {
        // Só agora o navegador pode oferecer salvar a nova senha.
        TextInput.finishAutofillContext();
        // Não mantém as senhas em memória depois do cadastro.
        _passwordCtrl.clear();
        _confirmCtrl.clear();
        setState(() => _registeredEmail = email);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final registeredEmail = _registeredEmail;
    if (registeredEmail != null) {
      // Texto neutro de propósito: se o e-mail já tiver conta, o Supabase
      // responde "sucesso" sem enviar nada (evita revelar quem tem conta).
      return AuthSuccessView(
        icon: Icons.mark_email_unread_outlined,
        title: 'Confirme seu e-mail',
        message: 'Enviamos um link de confirmação para $registeredEmail. '
            'Abra o e-mail e confirme para poder entrar.\n\n'
            'Não chegou em alguns minutos? Verifique o spam. Se esse e-mail '
            'já tiver uma conta, use "Entrar" ou "Esqueci minha senha".',
        actionLabel: 'Ir para o login',
        onAction: widget.onSwitchToLogin,
      );
    }

    return Form(
      key: _formKey,
      // cancel: abandonar o cadastro não oferece salvar uma senha não enviada.
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthFormHeader(
              title: 'Crie sua conta',
              subtitle: 'Leva menos de um minuto. Depois é só confirmar o '
                  'e-mail e começar.',
            ),
            AuthInlineError(message: _error),
            AuthTextField(
              controller: _nameCtrl,
              label: 'Nome completo',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: AuthValidators.name,
              focusNode: _nameFocus,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _studentIdCtrl,
              label: 'Prontuário',
              icon: Icons.badge_outlined,
              helperText: 'Formato: PT + 7 dígitos (ex.: PT1234567)',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: AuthValidators.studentIdFormatters,
              validator: AuthValidators.studentId,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _emailCtrl,
              label: 'E-mail',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.signupEmail,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _passwordCtrl,
              label: 'Senha',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.newPassword,
            ),
            // Reconstrói só o medidor a cada tecla, não o formulário inteiro.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordCtrl,
              builder: (_, value, __) =>
                  PasswordStrengthMeter(password: value.text),
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: _confirmCtrl,
              label: 'Confirmar senha',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value != _passwordCtrl.text
                  ? 'As senhas não coincidem'
                  : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              onPressed: _submit,
              label: 'Criar conta',
              loading: _loading,
            ),
            const SizedBox(height: 24),
            AuthSwitchPrompt(
              question: 'Já tem uma conta?',
              actionLabel: 'Entrar',
              onPressed: _loading ? null : widget.onSwitchToLogin,
            ),
          ],
        ),
      ),
    );
  }
}
