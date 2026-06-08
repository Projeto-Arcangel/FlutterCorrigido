import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_providers.dart';
import '../providers/login_controller.dart';

/// Tela de "definir nova senha".
///
/// Chega-se aqui quando o usuário abre o link do e-mail de recuperação: o app
/// detecta a sessão de `passwordRecovery` e o router força esta tela. Aqui ele
/// digita a nova senha (gravada via `updateUser`) e segue para o app.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result =
        await ref.read(updatePasswordProvider)(newPassword: _passCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) {
        // Sai do modo recovery → o router leva ao app (ou seleção de papel).
        ref.read(passwordRecoveryProvider.notifier).state = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha redefinida com sucesso!')),
        );
      },
    );
  }

  Future<void> _cancel() async {
    // Aborta a recuperação: encerra a sessão temporária e volta ao login.
    await ref.read(loginControllerProvider.notifier).signOut();
    if (!mounted) return;
    ref.read(passwordRecoveryProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;
    final mutedColor =
        isDark ? AppColors.textOnDark.withValues(alpha: 0.7) : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  const Icon(Icons.lock_reset_rounded,
                      size: 80, color: AppColors.primary,),
                  const SizedBox(height: 24),
                  Text(
                    'Definir nova senha',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha uma nova senha para sua conta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                        ),
                  ),
                  const SizedBox(height: 32),

                  _passwordField(
                    controller: _passCtrl,
                    label: 'Nova senha',
                    isDark: isDark,
                    mutedColor: mutedColor,
                    textColor: textColor,
                    obscure: _obscure1,
                    onToggle: () => setState(() => _obscure1 = !_obscure1),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  _passwordField(
                    controller: _confirmCtrl,
                    label: 'Confirmar nova senha',
                    isDark: isDark,
                    mutedColor: mutedColor,
                    textColor: textColor,
                    obscure: _obscure2,
                    onToggle: () => setState(() => _obscure2 = !_obscure2),
                    validator: (v) =>
                        v != _passCtrl.text ? 'As senhas não coincidem' : null,
                  ),
                  const SizedBox(height: 28),

                  AppButton(
                    onPressed: _submit,
                    label: 'Salvar nova senha',
                    loading: _loading,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : _cancel,
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: mutedColor),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required Color mutedColor,
    required Color textColor,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: mutedColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: mutedColor,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white12
                : AppColors.borderBlue.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}