import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Mensagem de erro exibida dentro dos formulários de autenticação.
///
/// Os formulários de auth vivem dentro do painel lateral (um `showGeneralDialog`
/// inserido na Overlay raiz), então não há um `Scaffold` ancestral para um
/// `SnackBar` funcionar. Heurística Nielsen #9 (ajudar o usuário a reconhecer e
/// corrigir erros): a mensagem fica fixada perto dos campos, não some sozinha,
/// e a área rola até ela quando aparece.
class AuthInlineError extends StatefulWidget {
  const AuthInlineError({super.key, required this.message});

  final String? message;

  @override
  State<AuthInlineError> createState() => _AuthInlineErrorState();
}

class _AuthInlineErrorState extends State<AuthInlineError> {
  @override
  void initState() {
    super.initState();
    _revealIfNeeded();
  }

  @override
  void didUpdateWidget(AuthInlineError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) _revealIfNeeded();
  }

  /// O envio pode ter sido feito lá embaixo (Enter no último campo); sem isso
  /// o erro aparece no topo, fora da tela.
  void _revealIfNeeded() {
    final message = widget.message;
    if (message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message == null || message.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Texto: #C62828 no claro (~5,6:1 sobre o fundo rosado) e #FF8A80 no
    // escuro (~7:1). O vermelho do tema (#E53935) não chega a 4,5:1 em nenhum.
    final textColor =
        isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: textColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
