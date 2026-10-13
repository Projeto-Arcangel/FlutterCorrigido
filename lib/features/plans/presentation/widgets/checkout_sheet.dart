import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/billing_datasource.dart';
import '../../domain/cpf_cnpj.dart';
import '../../domain/entities/plan.dart';
import '../providers/plan_providers.dart';

/// Pede um plano pago pelo app (só com [BillingConfig.enabled]). Coleta o
/// nome e o CPF/CNPJ (exigidos pelo Asaas para emitir a cobrança) e a forma
/// de pagamento; o cartão é digitado na página segura do Asaas.
Future<void> showCheckoutSheet(
  BuildContext context, {
  required Plan plan,
  required Plan current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CheckoutSheet(plan: plan, current: current),
  );
}

class _CheckoutSheet extends ConsumerStatefulWidget {
  const _CheckoutSheet({required this.plan, required this.current});

  final Plan plan;
  final Plan current;

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  BillingType _type = BillingType.pix;
  bool _sending = false;
  String? _error;

  bool get _isUpgrade =>
      !widget.current.isFree &&
      widget.plan.priceCents > widget.current.priceCents;
  bool get _isDowngrade =>
      !widget.current.isFree &&
      widget.plan.priceCents < widget.current.priceCents;

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(billingDatasourceProvider).checkout(
            planId: widget.plan.id,
            billingType: _type,
            name: _name.text,
            cpfCnpj: CpfCnpj.digits(_document.text),
          );
      navigator.pop();
      final invoice = result.invoiceUrl;
      if (invoice != null) {
        await launchUrl(
          Uri.parse(invoice),
          mode: LaunchMode.externalApplication,
        );
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                'Pagamento aberto em outra aba. O plano vale assim que o '
                    'pagamento for confirmado.',
          ),
        ),
      );
    } on BillingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = PlanFormat.price(widget.plan.priceCents);
    final summary = _isUpgrade
        ? 'Você paga agora só a diferença proporcional aos dias que faltam '
            'do período atual, e o ${widget.plan.name} vale assim que o '
            'pagamento for confirmado. Nas renovações: $price por mês.'
        : _isDowngrade
            ? 'O ${widget.current.name} segue valendo até o fim do período '
                'pago; na renovação, a assinatura muda para o '
                '${widget.plan.name} ($price por mês). Nada é apagado.'
            : '$price por mês, renovado automaticamente. Cancele quando '
                'quiser: o plano vale até o fim do período pago.';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.current.isFree
                    ? 'Assinar o plano ${widget.plan.name}'
                    : 'Mudar para o plano ${widget.plan.name}',
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(summary, style: textTheme.bodyMedium),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                enabled: !_sending,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nome completo ou razão social',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'Informe o nome que vai na cobrança.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _document,
                enabled: !_sending,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]')),
                  LengthLimitingTextInputFormatter(18),
                ],
                decoration: const InputDecoration(
                  labelText: 'CPF ou CNPJ',
                  helperText: 'Exigido para emitir a cobrança e a nota.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => CpfCnpj.isValid(v ?? '')
                    ? null
                    : 'CPF ou CNPJ inválido. Confira os números.',
                onEditingComplete: () {
                  _document.text = CpfCnpj.format(_document.text);
                  FocusScope.of(context).nextFocus();
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<BillingType>(
                segments: [
                  for (final t in BillingType.values)
                    ButtonSegment(value: t, label: Text(t.label)),
                ],
                selected: {_type},
                onSelectionChanged:
                    _sending ? null : (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _type == BillingType.card
                    ? 'Os dados do cartão são digitados na página segura do '
                        'Asaas, nosso parceiro de pagamentos. As renovações '
                        'são cobradas no mesmo cartão.'
                    : 'O código Pix aparece na página do Asaas. A cada mês, '
                        'você recebe a nova cobrança por e-mail.',
                style: textTheme.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isDowngrade
                            ? 'Agendar a mudança'
                            : 'Ir para o pagamento',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
