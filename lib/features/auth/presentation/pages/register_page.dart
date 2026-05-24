import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _studentIdCtrl  = TextEditingController(); // Prontuário
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool  _obscurePass    = true;
  bool  _obscureConf    = true;
  bool  _loading        = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await ref.read(registerUserProvider).call(
      email:       _emailCtrl.text.trim(),
      password:    _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
      studentId:   _studentIdCtrl.text.trim().isEmpty
          ? null
          : _studentIdCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Conta criada! Verifique seu e-mail antes de entrar.',
            ),
          ),
        );
        context.pop();
      },
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
            onPressed: () => context.go(AppRoutes.login),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Criar conta',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preencha os dados para começar',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // ── Nome ──────────────────────────────────────────────
                  _field(
                    controller: _nameCtrl,
                    label: 'Nome completo',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    validator: (v) =>
                        (v == null || v.trim().length < 2)
                            ? 'Mínimo 2 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Prontuário ────────────────────────────────────────
                  _field(
                    controller: _studentIdCtrl,
                    label: 'Prontuário (opcional)',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.badge_outlined),
                    helperText: 'Ex.: SP123456 — fornecido pela instituição',
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      // Permite letras e números; máx. 20 chars
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    // Campo opcional — sem validação obrigatória
                    validator: (_) => null,
                  ),
                  const SizedBox(height: 12),

                  // ── E-mail ────────────────────────────────────────────
                  _field(
                    controller: _emailCtrl,
                    label: 'E-mail',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@'))
                            ? 'E-mail inválido'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Senha ─────────────────────────────────────────────
                  _field(
                    controller: _passwordCtrl,
                    label: 'Senha',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Confirmar senha ───────────────────────────────────
                  _field(
                    controller: _confirmCtrl,
                    label: 'Confirmar senha',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    obscureText: _obscureConf,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConf
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.textOnDark.withValues(alpha: 0.6)
                            : AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConf = !_obscureConf),
                    ),
                    validator: (v) =>
                        v != _passwordCtrl.text
                            ? 'As senhas não coincidem'
                            : null,
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    onPressed: _submit,
                    label: 'Criar conta',
                    loading: _loading,
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final mutedColor = isDark
        ? AppColors.textOnDark.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: mutedColor),
        prefixIcon: prefixIcon != null
            ? IconTheme(
                data: IconThemeData(color: mutedColor, size: 20),
                child: prefixIcon,
              )
            : null,
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: TextStyle(
          color: isDark
              ? AppColors.textOnDark.withValues(alpha: 0.45)
              : AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 11,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
    );
  }
}