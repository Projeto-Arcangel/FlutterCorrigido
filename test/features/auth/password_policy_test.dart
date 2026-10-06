import 'package:arcangel_o_oficial/features/auth/domain/password_policy.dart';
import 'package:arcangel_o_oficial/features/auth/presentation/widgets/auth_validators.dart';
import 'package:arcangel_o_oficial/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('lista o que falta em uma senha fraca', () {
      expect(
        PasswordPolicy.missing('abc'),
        [
          PasswordRequirement.length,
          PasswordRequirement.uppercase,
          PasswordRequirement.digit,
          PasswordRequirement.symbol,
        ],
      );
    });

    test('força: vazia, fraca, boa e forte', () {
      expect(PasswordPolicy.strengthOf(''), PasswordStrength.empty);
      expect(PasswordPolicy.strengthOf('Senha123'), PasswordStrength.weak);
      expect(PasswordPolicy.strengthOf('Senha@12'), PasswordStrength.good);
      expect(
        PasswordPolicy.strengthOf('Senha@123456'),
        PasswordStrength.strong,
      );
    });

    test('só aceita os símbolos que o Supabase reconhece', () {
      // Espaço e letras acentuadas não contam como símbolo no servidor.
      expect(
        PasswordPolicy.isMet(PasswordRequirement.symbol, 'Senha 12'),
        isFalse,
      );
      expect(
        PasswordPolicy.isMet(PasswordRequirement.symbol, 'Senhaç12'),
        isFalse,
      );
      expect(
        PasswordPolicy.isMet(PasswordRequirement.symbol, r'Senha$12'),
        isTrue,
      );
    });
  });

  group('AuthValidators', () {
    test('newPassword recusa senha fraca dizendo o que falta', () {
      expect(AuthValidators.newPassword(''), 'Crie uma senha');
      expect(
        AuthValidators.newPassword('senhasenha'),
        'Senha fraca. Falta: letra maiúscula, número, símbolo.',
      );
      expect(AuthValidators.newPassword('Senha@12'), isNull);
    });

    test('password (login) não aplica a regra nova a contas antigas', () {
      expect(AuthValidators.password(''), 'Informe sua senha');
      expect(AuthValidators.password('abc123'), isNull);
    });
  });

  testWidgets('medidor marca os requisitos atendidos', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PasswordStrengthMeter(password: 'Senha12')),
      ),
    );

    expect(find.text('Fraca'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Uma letra maiúscula (A-Z): atendido'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Pelo menos ${PasswordPolicy.minLength} caracteres: pendente',
      ),
      findsOneWidget,
    );
  });
}
