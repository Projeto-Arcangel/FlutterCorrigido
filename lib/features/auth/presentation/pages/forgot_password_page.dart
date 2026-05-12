import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool  _loading   = false;
  bool  _sent      = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await ref.read(sendPasswordResetProvider)(
      email: _emailCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) => setState(() => _sent = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _sent
                ? _SuccessState(isDark: isDark)
                : _FormState(
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    isDark: isDark,
                    loading: _loading,
                    onSubmit: _submit,
                  ),
          ),
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  const _FormState({
    required this.formKey,
    required this.emailCtrl,
    required this.isDark,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isDark;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.lock_reset_rounded,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Esqueceu sua senha?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite seu e-mail e enviaremos um link\npara redefinir sua senha.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textOnDark.withOpacity(0.7)
                      : AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
            style: TextStyle(
              color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'E-mail',
              labelStyle: TextStyle(
                color: isDark
                    ? AppColors.textOnDark.withOpacity(0.7)
                    : AppColors.textSecondary,
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
                      : AppColors.borderBlue.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            onPressed: onSubmit,
            label: 'Enviar link',
            loading: loading,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.mark_email_read_rounded,
          size: 96,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'E-mail enviado!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verifique sua caixa de entrada e siga\nas instruções para redefinir a senha.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textOnDark.withOpacity(0.7)
                    : AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 40),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: const Text('Voltar para o login'),
        ),
      ],
    );
  }
}