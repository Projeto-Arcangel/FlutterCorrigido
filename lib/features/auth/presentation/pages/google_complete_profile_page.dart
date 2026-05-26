import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../domain/entities/user.dart';
import '../providers/auth_providers.dart';

class GoogleCompleteProfilePage extends ConsumerStatefulWidget {
  const GoogleCompleteProfilePage({super.key});

  @override
  ConsumerState<GoogleCompleteProfilePage> createState() =>
      _GoogleCompleteProfilePageState();
}

class _GoogleCompleteProfilePageState
    extends ConsumerState<GoogleCompleteProfilePage> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  bool  _loading       = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final fbUser = ref.read(firebaseAuthProvider).currentUser;
    if (fbUser == null) {
      setState(() => _loading = false);
      return;
    }

    final name      = _nameCtrl.text.trim();
    final studentId = _studentIdCtrl.text.trim().toUpperCase();

    // 1. Cria o perfil no Firestore com nome e prontuário.
    final user = User(
      id:          fbUser.uid,
      email:       fbUser.email ?? '',
      displayName: name,
      photoUrl:    fbUser.photoURL,
      studentId:   studentId,
    );

    final createResult =
        await ref.read(userRepositoryProvider).createProfileIfAbsent(user);

    if (!mounted) return;

    if (createResult.isLeft()) {
      // Erro ao criar perfil — exibe snackbar e libera o botão.
      final failure = createResult.fold((f) => f, (_) => null)!;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }

    // 2. Atualiza displayName no Firebase Auth para consistência.
    await fbUser.updateDisplayName(name);

    if (!mounted) return;

    // 3. Limpa a flag — o router vai redirecionar para RoleSelectionPage.
    ref.read(googleNewUserProvider.notifier).state = false;
    ref.invalidate(currentUserRoleProvider);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // ── Logo ──────────────────────────────────────────────
                  const AppLogo(size: 80),
                  const SizedBox(height: 28),

                  // ── Título ────────────────────────────────────────────
                  Text(
                    'Quase lá! 🎉',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete seu perfil para começar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textOnDark.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 40),

                  // ── Nome completo ─────────────────────────────────────
                  _field(
                    controller: _nameCtrl,
                    label: 'Nome completo',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Mínimo 2 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Prontuário ────────────────────────────────────────
                  _field(
                    controller: _studentIdCtrl,
                    label: 'Prontuário',
                    isDark: isDark,
                    prefixIcon: const Icon(Icons.badge_outlined),
                    helperText: 'Formato: PT + 7 dígitos (ex.: PT1234567)',
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      _UpperCaseTextFormatter(),
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) {
                      final value = (v ?? '').trim().toUpperCase();
                      if (value.isEmpty) return 'Prontuário obrigatório';
                      if (!value.startsWith('PT')) {
                        return 'Deve começar com "PT"';
                      }
                      if (value.length != 9) {
                        return 'Deve ter exatamente 9 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // ── Botão ─────────────────────────────────────────────
                  AppButton(
                    onPressed: _submit,
                    label: 'Salvar e continuar',
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
    Widget? prefixIcon,
    String? helperText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final mutedColor = isDark
        ? AppColors.textOnDark.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    return TextFormField(
      controller: controller,
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

// ── Formatter: converte para maiúsculas a cada keystroke ────────────────────
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
