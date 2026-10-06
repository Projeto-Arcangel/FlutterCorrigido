import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canal de contato divulgado na landing (Planos, Suporte e rodapé).
abstract final class LandingContact {
  static const String supportEmail = 'arcangel.admin@gmail.com';

  /// Abre o app de e-mail já endereçado ao suporte. Se não houver app de
  /// e-mail para abrir, copia o endereço e avisa — o usuário nunca fica sem
  /// saída.
  static Future<void> sendEmail(BuildContext context, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      // encodeComponent: com queryParameters os espaços virariam "+", que
      // vários apps de e-mail mostram literalmente no assunto.
      query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
    );

    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await copyEmail(
        context,
        message: 'Não foi possível abrir seu app de e-mail. Copiamos o '
            'endereço $supportEmail para você.',
      );
    }
  }

  static Future<void> copyEmail(BuildContext context, {String? message}) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    final compact = MediaQuery.sizeOf(context).width < 600;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message ?? 'E-mail $supportEmail copiado.'),
          behavior: SnackBarBehavior.floating,
          // No desktop, um aviso compacto em vez de uma faixa que cobre a
          // largura toda da página.
          width: compact ? null : 440,
        ),
      );
  }
}
