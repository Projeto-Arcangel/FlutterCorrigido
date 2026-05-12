import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/login_controller.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool  _obscurePass    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(loginControllerProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(loginControllerProvider, (_, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString())),
        ),
      );
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // ── Logo ──────────────────────────────────────────────
                  Image.asset(
                    'assets/images/app_launcher_icon.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),

                  // ── Título ────────────────────────────────────────────
                  Text(
                    'Entrar no Arcangel',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // ── Campo e-mail ──────────────────────────────────────
                  _buildTextField(
                    controller: _emailCtrl,
                    label: 'e-mail',
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'E-mail inválido'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Campo senha ───────────────────────────────────────
                  _buildTextField(
                    controller: _passwordCtrl,
                    label: 'senha',
                    isDark: isDark,
                    obscureText: _obscurePass,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark
                            ? AppColors.textOnDark.withOpacity(0.6)
                            : AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                  ),

                  // ── Esqueci minha senha ───────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPassword),
                      child: Text(
                        'Esqueci minha senha',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textOnDark.withOpacity(0.8)
                              : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Botão principal ───────────────────────────────────
                  AppButton(
                    onPressed: _submit,
                    label: 'Confirmar Login',
                    loading: state.isLoading,
                  ),
                  const SizedBox(height: 20),

                  // ── Divisor "ou" ──────────────────────────────────────
                  Text(
                    'ou',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Botão Google ──────────────────────────────────────
                  _SocialButton(
                    label: 'Continuar com o Google',
                    icon: const FaIcon(
                      FontAwesomeIcons.google,
                      size: 20,
                    ),
                    onPressed: state.isLoading
                        ? () {}
                        : () => ref
                            .read(loginControllerProvider.notifier)
                            .signInWithGoogle(),
                  ),
                  const SizedBox(height: 12),

                  // ── Link cadastro ─────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.register),
                    child: RichText(
                      text: TextSpan(
                        text: 'Não possui uma conta? ',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textOnDark.withOpacity(0.7)
                              : AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Clique aqui',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              color: isDark
                                  ? AppColors.textOnDark
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
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

  // ── Helper: campo de texto padronizado ───────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark
              ? AppColors.textOnDark.withOpacity(0.7)
              : AppColors.textSecondary,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDark
            : Colors.white,
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
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ── Widget auxiliar: botão social ────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1F28),
          ),
        ),
        style: OutlinedButton.styleFrom(
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