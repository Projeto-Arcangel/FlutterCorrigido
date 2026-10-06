import 'package:arcangel_o_oficial/core/errors/error_messages.dart';
import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorMessages.auth', () {
    test('traduz pelo código do GoTrue', () {
      expect(
        ErrorMessages.auth(
          const AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        'E-mail ou senha incorretos.',
      );
      expect(
        ErrorMessages.auth(
          const AuthApiException(
            'email rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        startsWith('Muitos e-mails enviados'),
      );
    });

    test('traduz pelo texto quando não há código', () {
      expect(
        ErrorMessages.auth(
          const AuthException(
            'For security purposes, you can only request this after 52 '
            'seconds.',
          ),
        ),
        ErrorMessages.rateLimited,
      );
    });

    test('nunca repassa texto desconhecido em inglês', () {
      expect(
        ErrorMessages.auth(const AuthException('Something odd happened')),
        ErrorMessages.generic,
      );
      expect(
        ErrorMessages.auth(
          const AuthException('Database error', statusCode: '500'),
        ),
        ErrorMessages.unavailable,
      );
    });

    test('falha de rede vira mensagem de conexão', () {
      expect(
        ErrorMessages.auth(AuthRetryableFetchException()),
        ErrorMessages.network,
      );
    });
  });

  group('ErrorMessages.from', () {
    test('mantém mensagens já amigáveis', () {
      expect(
        ErrorMessages.from(const NetworkFailure('Falha ao carregar salas')),
        'Falha ao carregar salas',
      );
      expect(
        ErrorMessages.from(
          const FailureException(NetworkFailure('Falha ao carregar salas')),
        ),
        'Falha ao carregar salas',
      );
    });

    test('FailureException não exibe o prefixo "Exception:"', () {
      const error = FailureException(ValidationFailure('Código inválido'));
      expect(error.toString(), 'Código inválido');
    });

    test('erro desconhecido usa o fallback com contexto', () {
      expect(
        ErrorMessages.from(
          StateError('boom'),
          fallback: 'Não foi possível exportar as notas.',
        ),
        'Não foi possível exportar as notas.',
      );
    });

    test('reconhece erro de rede pelo texto (web)', () {
      expect(
        ErrorMessages.from(Exception('ClientException: Failed to fetch')),
        ErrorMessages.network,
      );
    });
  });
}
