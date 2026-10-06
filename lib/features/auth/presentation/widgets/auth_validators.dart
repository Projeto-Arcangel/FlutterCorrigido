import 'package:flutter/services.dart';

import '../../domain/email_typo.dart';
import '../../domain/password_policy.dart';

abstract final class AuthValidators {
  // Parte local com os caracteres permitidos em e-mail; domínio com rótulos
  // válidos (sem começar/terminar com hífen) e terminação de 2+ letras.
  static final _emailPattern = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
    r'@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*'
    r'\.[A-Za-z]{2,}$',
  );

  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!_emailPattern.hasMatch(email) ||
        email.contains('..') ||
        email.startsWith('.') ||
        email.contains('.@')) {
      return 'E-mail inválido';
    }
    return null;
  }

  /// E-mail no CADASTRO: além do formato, aponta domínio digitado errado
  /// ("gmial.com") com a sugestão de correção. Se o domínio não existir ou
  /// for de e-mail temporário, quem recusa é o servidor (hook
  /// before-user-created), e a mensagem aparece no formulário.
  static String? signupEmail(String? value) {
    final formatError = email(value);
    if (formatError != null) return formatError;
    final suggestion = EmailTypo.suggestion((value ?? '').trim());
    if (suggestion != null) {
      return 'Confira o e-mail. Você quis dizer $suggestion?';
    }
    return null;
  }

  /// Senha no LOGIN: só exige que seja informada. A regra de senha forte vale
  /// para criar/trocar senha ([newPassword]); contas antigas com senha fora
  /// da regra continuam conseguindo entrar.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha';
    return null;
  }

  /// Senha nova (cadastro, redefinição e troca): recusa enquanto estiver
  /// fraca e diz o que falta. Ver [PasswordPolicy].
  static String? newPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Crie uma senha';
    final missing = PasswordPolicy.missing(password);
    if (missing.isEmpty) return null;
    return 'Senha fraca. Falta: '
        '${missing.map((r) => r.shortLabel).join(', ')}.';
  }

  static String? name(String? value) =>
      (value == null || value.trim().length < 2) ? 'Mínimo 2 caracteres' : null;

  /// Prontuário IFSP: "PT" + 7 dígitos (ex.: PT1234567).
  static String? studentId(String? value) {
    final id = (value ?? '').trim().toUpperCase();
    if (id.isEmpty) return 'Prontuário obrigatório';
    if (!id.startsWith('PT')) return 'Deve começar com "PT"';
    if (id.length != 9) return 'Deve ter exatamente 9 caracteres';
    return null;
  }

  static final studentIdFormatters = <TextInputFormatter>[
    _UpperCaseTextFormatter(),
    FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
    LengthLimitingTextInputFormatter(9),
  ];
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
