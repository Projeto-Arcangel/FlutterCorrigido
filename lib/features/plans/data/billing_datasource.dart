import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_messages.dart';

/// Forma de pagamento no Asaas.
enum BillingType {
  pix('PIX', 'Pix'),
  card('CREDIT_CARD', 'Cartão de crédito');

  const BillingType(this.key, this.label);

  final String key;
  final String label;
}

/// Resultado de pedir um plano pelo app.
class CheckoutResult {
  const CheckoutResult({this.invoiceUrl, this.message});

  /// Página de pagamento do Asaas (Pix ou cartão). Nula quando não há o que
  /// pagar agora (ex.: redução de plano agendada para a renovação).
  final String? invoiceUrl;

  /// O que aconteceu, para mostrar ao professor.
  final String? message;
}

class BillingException implements Exception {
  const BillingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Assinatura pelo app (Edge Functions billing-checkout e billing-cancel).
/// O cartão e o Pix são pagos na página do Asaas: os dados do cartão nunca
/// passam pelo app nem pelo nosso servidor.
class BillingDatasource {
  BillingDatasource(this._client);

  final SupabaseClient _client;

  /// Lança [BillingException] com a mensagem para o professor.
  Future<CheckoutResult> checkout({
    required String planId,
    required BillingType billingType,
    required String name,
    required String cpfCnpj,
  }) async {
    final data = await _invoke('billing-checkout', {
      'planId': planId,
      'billingType': billingType.key,
      'name': name.trim(),
      'cpfCnpj': cpfCnpj,
    });
    return CheckoutResult(
      invoiceUrl: data['invoiceUrl'] as String?,
      message: data['message'] as String?,
    );
  }

  /// Cancela a renovação: o plano vale até o fim do período pago.
  Future<String?> cancel() async {
    final data = await _invoke('billing-cancel', const {});
    return data['message'] as String?;
  }

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, Object?> body,
  ) async {
    try {
      final res = await _client.functions.invoke(function, body: body);
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw BillingException(
        message ??
            ErrorMessages.from(
              e,
              fallback: 'Não foi possível concluir agora. Tente de novo em '
                  'instantes.',
            ),
      );
    } catch (e) {
      throw BillingException(
        ErrorMessages.from(
          e,
          fallback: 'Não foi possível concluir agora. Tente de novo em '
              'instantes.',
        ),
      );
    }
  }
}
