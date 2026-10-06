import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failure.dart';

/// Converte erros técnicos em mensagens para o usuário.
///
/// Nenhuma mensagem crua de biblioteca (em inglês, com nome de classe ou
/// "Exception:") deve chegar à tela: o detalhe técnico vai para o log, e o
/// usuário recebe o que aconteceu e o que fazer.
abstract final class ErrorMessages {
  static const generic = 'Algo deu errado. Tente novamente em instantes.';
  static const network =
      'Não foi possível conectar. Verifique sua internet e tente novamente.';
  static const unavailable =
      'O serviço está indisponível no momento. Tente novamente em instantes.';
  static const sessionExpired = 'Sua sessão expirou. Entre novamente.';
  static const rateLimited =
      'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente '
      'novamente.';

  /// Mensagem amigável para qualquer erro. [fallback] é usado quando o erro
  /// não é reconhecido — passe um texto com contexto ("Não foi possível
  /// exportar as notas.") sempre que houver.
  static String from(Object? error, {String fallback = generic}) {
    if (error is Failure) return error.message;
    if (error is FailureException) return error.failure.message;
    if (error is AuthException) return auth(error);
    if (isNetworkError(error)) return network;
    if (error is TimeoutException) {
      return 'A operação demorou demais. Tente novamente.';
    }
    if (error is PostgrestException) return _postgrest(error, fallback);
    if (error is FunctionException) {
      final status = error.status;
      if (status == 401) return sessionExpired;
      if (status >= 500) return unavailable;
    }
    // Mensagens já tratadas pelo app às vezes chegam como String.
    if (error is String && error.trim().isNotEmpty) return error;
    return fallback;
  }

  /// Falha de rede (sem internet, servidor fora do ar, CORS...). Os tipos
  /// vêm de pacotes diferentes conforme a plataforma, então reconhece pelo
  /// nome do tipo e pelas mensagens típicas, sem depender de `dart:io`.
  static bool isNetworkError(Object? error) {
    if (error == null) return false;
    if (error is AuthRetryableFetchException) return true;
    final type = error.runtimeType.toString();
    if (type.contains('SocketException') ||
        type.contains('ClientException') ||
        type.contains('HandshakeException')) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('failed to fetch') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('network is unreachable') ||
        text.contains('xmlhttprequest error');
  }

  /// Erros do Supabase Auth. Usa o `code` do GoTrue quando existe e cai para
  /// o texto (servidores antigos não mandam código). Nunca devolve o texto
  /// original em inglês.
  static String auth(AuthException e) {
    if (e is AuthRetryableFetchException) return network;
    if (e is AuthSessionMissingException) return sessionExpired;
    if (e is AuthWeakPasswordException) return weakPassword;

    final hookReason = _signupHookReason(e.message);
    if (hookReason != null) return hookReason;

    switch (e.code) {
      case 'invalid_credentials':
        return 'E-mail ou senha incorretos.';
      case 'email_not_confirmed':
        return 'Seu e-mail ainda não foi confirmado. Abra o link que '
            'enviamos (confira também o spam).';
      case 'user_already_exists':
      case 'email_exists':
        return 'Este e-mail já está cadastrado. Use "Entrar" ou "Esqueci '
            'minha senha".';
      case 'weak_password':
        return weakPassword;
      case 'same_password':
        return 'A nova senha precisa ser diferente da atual.';
      case 'over_email_send_rate_limit':
        return 'Muitos e-mails enviados em pouco tempo. Aguarde alguns '
            'minutos antes de pedir outro.';
      case 'over_request_rate_limit':
      case 'over_sms_send_rate_limit':
        return rateLimited;
      case 'email_address_invalid':
      case 'email_address_not_authorized':
        return 'Não é possível usar este e-mail. Confira o endereço digitado.';
      case 'signup_disabled':
      case 'email_provider_disabled':
        return 'Novos cadastros estão temporariamente desativados.';
      case 'provider_disabled':
        return 'Esta forma de login não está disponível no momento.';
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
      case 'refresh_token_already_used':
      case 'bad_jwt':
      case 'no_authorization':
        return sessionExpired;
      case 'reauthentication_needed':
        return 'Por segurança, entre novamente para continuar.';
      case 'otp_expired':
      case 'flow_state_expired':
      case 'flow_state_not_found':
      case 'bad_code_verifier':
        return 'Este link expirou ou já foi usado. Solicite um novo e abra no '
            'mesmo navegador em que fez o pedido.';
      case 'user_banned':
        return 'Esta conta está bloqueada. Fale com o suporte.';
    }

    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Seu e-mail ainda não foi confirmado. Abra o link que enviamos '
          '(confira também o spam).';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'Este e-mail já está cadastrado. Use "Entrar" ou "Esqueci minha '
          'senha".';
    }
    if (msg.contains('password should') || msg.contains('weak password')) {
      return weakPassword;
    }
    if (msg.contains('should be different')) {
      return 'A nova senha precisa ser diferente da atual.';
    }
    if (msg.contains('for security purposes') || msg.contains('rate limit')) {
      return rateLimited;
    }
    if (msg.contains('unable to validate email address') ||
        msg.contains('invalid format')) {
      return 'E-mail inválido.';
    }
    if (msg.contains('code verifier')) {
      return 'Este link precisa ser aberto no mesmo navegador em que você '
          'fez o pedido.';
    }

    final status = int.tryParse(e.statusCode ?? '');
    if (status != null && status >= 500) return unavailable;
    return generic;
  }

  /// Recusas do hook before-user-created (supabase/functions/
  /// before-user-created) chegam como "[codigo] texto", com error_code
  /// "unknown". Traduz pelo código; um código novo usa o texto do servidor.
  static String? _signupHookReason(String message) {
    final match = RegExp(r'^\[(email_[a-z_]+)\]\s*(.*)$', dotAll: true)
        .firstMatch(message.trim());
    if (match == null) return null;
    return switch (match.group(1)) {
      'email_disposable' => 'E-mails temporários não são aceitos. Use um '
          'e-mail pessoal ou institucional.',
      'email_domain_invalid' => 'Este domínio de e-mail não existe ou não '
          'recebe mensagens. Confira o endereço digitado.',
      'email_invalid_format' => 'E-mail inválido. Confira o endereço digitado.',
      _ => match.group(2)!.isEmpty ? generic : match.group(2),
    };
  }

  static const weakPassword =
      'Senha fraca. Use ao menos 8 caracteres, com letra maiúscula, letra '
      'minúscula, número e símbolo.';

  static String _postgrest(PostgrestException e, String fallback) {
    switch (e.code) {
      case 'PGRST301':
      case 'PGRST302':
        return sessionExpired;
      case '42501': // permissão negada (RLS)
        return 'Você não tem permissão para fazer isso.';
      case '23505': // valor duplicado
        return 'Esse registro já existe.';
    }
    return fallback;
  }
}
