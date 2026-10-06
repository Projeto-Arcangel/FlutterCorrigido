/// Regra de senha para criar ou trocar senha (cadastro, redefinição e
/// "Alterar senha").
///
/// Espelha a configuração do Supabase Auth (`minimum_password_length = 8` e
/// `password_requirements = "lower_upper_letters_digits_symbols"`): o app
/// orienta e bloqueia antes de enviar, e o servidor garante a regra mesmo se
/// alguém contornar o app. Por isso as classes de caracteres usam os mesmos
/// conjuntos do Supabase (letras sem acento e os símbolos abaixo).
abstract final class PasswordPolicy {
  static const int minLength = 8;

  /// A partir deste tamanho, uma senha que cumpre tudo é considerada forte.
  static const int strongLength = 12;

  static final _upper = RegExp('[A-Z]');
  static final _lower = RegExp('[a-z]');
  static final _digit = RegExp('[0-9]');
  static final _symbol = RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|<>?,./`~]''');

  static const requirements = [
    PasswordRequirement.length,
    PasswordRequirement.uppercase,
    PasswordRequirement.lowercase,
    PasswordRequirement.digit,
    PasswordRequirement.symbol,
  ];

  static bool isMet(PasswordRequirement requirement, String password) =>
      switch (requirement) {
        PasswordRequirement.length => password.length >= minLength,
        PasswordRequirement.uppercase => _upper.hasMatch(password),
        PasswordRequirement.lowercase => _lower.hasMatch(password),
        PasswordRequirement.digit => _digit.hasMatch(password),
        PasswordRequirement.symbol => _symbol.hasMatch(password),
      };

  static List<PasswordRequirement> missing(String password) => [
        for (final requirement in requirements)
          if (!isMet(requirement, password)) requirement,
      ];

  static PasswordStrength strengthOf(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (missing(password).isNotEmpty) return PasswordStrength.weak;
    return password.length >= strongLength
        ? PasswordStrength.strong
        : PasswordStrength.good;
  }
}

enum PasswordRequirement {
  length(
      'Pelo menos ${PasswordPolicy.minLength} caracteres',
      'mínimo de '
          '${PasswordPolicy.minLength} caracteres'),
  uppercase('Uma letra maiúscula (A-Z)', 'letra maiúscula'),
  lowercase('Uma letra minúscula (a-z)', 'letra minúscula'),
  digit('Um número (0-9)', 'número'),
  symbol(r'Um símbolo (ex.: ! @ # $ % & *)', 'símbolo');

  const PasswordRequirement(this.label, this.shortLabel);

  /// Texto da lista de requisitos.
  final String label;

  /// Forma curta, usada na mensagem de erro ("Falta: número, símbolo").
  final String shortLabel;
}

/// [weak] = falta algum requisito (não é aceita); [good] = cumpre todos;
/// [strong] = cumpre todos e tem ao menos [PasswordPolicy.strongLength]
/// caracteres.
enum PasswordStrength { empty, weak, good, strong }
