import 'package:arcangel_o_oficial/core/errors/error_messages.dart';
import 'package:arcangel_o_oficial/features/auth/domain/email_typo.dart';
import 'package:arcangel_o_oficial/features/auth/presentation/widgets/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmailTypo', () {
    test('sugere a correção de domínios digitados errado', () {
      expect(EmailTypo.suggestion('ana@gmial.com'), 'ana@gmail.com');
      expect(EmailTypo.suggestion('ana@gamil.com'), 'ana@gmail.com');
      expect(EmailTypo.suggestion('ana@gmail.con'), 'ana@gmail.com');
      expect(EmailTypo.suggestion('ana@hotmial.com'), 'ana@hotmail.com');
      expect(EmailTypo.suggestion('ana@outlok.com'), 'ana@outlook.com');
      expect(EmailTypo.suggestion('ana@hotmail.com.bt'), 'ana@hotmail.com.br');
      expect(EmailTypo.suggestion('ana@yaho.com.br'), 'ana@yahoo.com.br');
    });

    test('não mexe em domínios corretos ou reais parecidos', () {
      for (final email in [
        'ana@gmail.com',
        'ana@hotmail.com.br',
        'ana@aluno.ifsp.edu.br',
        'ana@ifsp.edu.br',
        'ana@usp.br',
        'ana@ymail.com',
        'ana@mail.com',
        'ana@email.com',
        'ana@yahoo.ca',
        'ana@hotmail.fr',
        'ana@empresa.com.br',
      ]) {
        expect(EmailTypo.suggestion(email), isNull, reason: email);
      }
    });
  });

  group('AuthValidators', () {
    test('email recusa formatos inválidos', () {
      for (final email in [
        'ana',
        'ana@',
        'ana@gmail',
        'ana@gmail.c',
        'ana@@gmail.com',
        'ana..silva@gmail.com',
        '.ana@gmail.com',
        'ana.@gmail.com',
        'ana@-gmail.com',
        'ana silva@gmail.com',
      ]) {
        expect(AuthValidators.email(email), 'E-mail inválido', reason: email);
      }
      expect(
        AuthValidators.email('ana.silva+escola@aluno.ifsp.edu.br'),
        isNull,
      );
    });

    test('signupEmail aponta erro de digitação com sugestão', () {
      expect(
        AuthValidators.signupEmail('ana@gmial.com'),
        'Confira o e-mail. Você quis dizer ana@gmail.com?',
      );
      expect(AuthValidators.signupEmail('ana@gmail.com'), isNull);
    });
  });

  group('ErrorMessages (hook before-user-created)', () {
    AuthException hookError(String message) =>
        AuthApiException(message, statusCode: '400', code: 'unknown');

    test('traduz o motivo da recusa pelo código', () {
      expect(
        ErrorMessages.auth(hookError('[email_disposable] qualquer texto')),
        startsWith('E-mails temporários não são aceitos'),
      );
      expect(
        ErrorMessages.auth(hookError('[email_domain_invalid] x')),
        startsWith('Este domínio de e-mail não existe'),
      );
    });

    test('código novo usa o texto enviado pelo servidor', () {
      expect(
        ErrorMessages.auth(
          hookError('[email_blocked] Este e-mail foi bloqueado.'),
        ),
        'Este e-mail foi bloqueado.',
      );
    });
  });
}
