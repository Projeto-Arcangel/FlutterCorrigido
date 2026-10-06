import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Foca [node] assim que o formulário aparece. Pedido explícito no lugar de
/// `autofocus`, que só age quando o escopo de foco não tem nenhum nó focado —
/// condição que não vale ao trocar de aba dentro do painel.
void focusAfterFirstFrame(State<StatefulWidget> state, FocusNode node) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) node.requestFocus();
  });
}

/// Campo padrão dos formulários de autenticação (login, cadastro e
/// recuperação de senha). Com [isPassword], controla sozinho o
/// mostrar/ocultar senha.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints,
    this.validator,
    this.helperText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  bool _obscured = true;

  /// Só valida ao sair do campo depois que o usuário digitou algo; um campo
  /// intocado não fica vermelho só porque o foco passou por ele. No envio o
  /// `Form.validate()` valida todos os campos de qualquer forma.
  bool _edited = false;

  void _handleChanged(String value) {
    _edited = true;
    widget.onChanged?.call(value);
  }

  // Validação ao sair do campo feita aqui, e não com
  // `AutovalidateMode.onUnfocus`: esse modo insere um `Focus` extra dentro do
  // TextFormField, e alterná-lo durante a digitação recria o campo — na web a
  // conexão de teclado volta para o campo anterior (o Enter ia para o e-mail).
  void _handleFocusChange(bool hasFocus) {
    if (!hasFocus && _edited) _fieldKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textOnDark : AppColors.textPrimary;
    final mutedColor = isDark
        ? AppColors.textOnDark.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      child: TextFormField(
        key: _fieldKey,
        controller: widget.controller,
        obscureText: widget.isPassword && _obscured,
        enableSuggestions: !widget.isPassword,
        autocorrect: false,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: _handleChanged,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        inputFormatters: widget.inputFormatters,
        textCapitalization: widget.textCapitalization,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(color: mutedColor),
          prefixIcon: Icon(widget.icon, color: mutedColor, size: 20),
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: mutedColor,
                  ),
                )
              : null,
          helperText: widget.helperText,
          helperMaxLines: 2,
          helperStyle: TextStyle(color: mutedColor, fontSize: 12),
          errorMaxLines: 2,
          filled: true,
          fillColor: isDark ? AppColors.surfaceDark : Colors.white,
          border: border(Colors.transparent),
          enabledBorder: border(
            isDark
                ? Colors.white12
                : AppColors.borderBlue.withValues(alpha: 0.3),
          ),
          focusedBorder: border(AppColors.primary, 2),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error, 2),
        ),
      ),
    );
  }
}
