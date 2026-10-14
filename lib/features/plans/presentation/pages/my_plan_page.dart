import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../landing/presentation/landing_contact.dart';
import '../../data/billing_datasource.dart';
import '../../domain/entities/plan.dart';
import '../../domain/plan_catalog.dart';
import '../providers/plan_providers.dart';
import '../widgets/checkout_sheet.dart';

abstract class _C {
  static const accent = AppColors.primary;
  static const warn = Color(0xFFE0795B);
  static const success = Color(0xFF3FA86B);
  static const textMuted = Color(0xFF8FA3AE);

  static Color page(bool dark) =>
      dark ? AppColors.backgroundDark : AppColors.background;
  static Color card(bool dark) => dark ? AppColors.surfaceDark : Colors.white;
  static Color border(bool dark) =>
      dark ? const Color(0x1AFFFFFF) : Colors.black12;
  static Color text(bool dark) => dark ? Colors.white : AppColors.textPrimary;
  static Color muted(bool dark) => dark ? textMuted : const Color(0xFF5A6B78);
  static Color track(bool dark) =>
      dark ? const Color(0xFF3A3B46) : const Color(0xFFE3E8EC);
}

/// "Meu plano": plano em vigor, uso do período (um mês contado do início
/// do plano; no Free, do cadastro), limites
/// atingidos com dicas e a comparação dos planos. Enquanto a cobrança pelo
/// app está desligada ([BillingConfig.enabled]), os planos pagos são
/// pedidos por e-mail.
class MyPlanPage extends ConsumerWidget {
  const MyPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planAsync = ref.watch(myPlanProvider);

    return Scaffold(
      backgroundColor: _C.page(isDark),
      appBar: AppBar(
        backgroundColor: _C.page(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Meu plano',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _C.text(isDark),
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(Icons.chevron_left, color: _C.text(isDark), size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: planAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _LoadError(
            message: ErrorMessages.from(
              e,
              fallback: 'Não foi possível carregar seu plano.',
            ),
            onRetry: () => ref.invalidate(myPlanProvider),
          ),
          data: (plan) => RefreshIndicator(
            onRefresh: () => ref.refresh(myPlanProvider.future),
            child: _PlanBody(plan: plan),
          ),
        ),
      ),
    );
  }
}

class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.plan});

  final MyPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notices = plan.notices;
    final p = plan.plan;
    final u = plan.usage;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _CurrentPlanCard(plan: plan),
            if (plan.pending != null) ...[
              const SizedBox(height: 12),
              _PendingPaymentCard(pending: plan.pending!),
            ],
            for (final notice in notices) ...[
              const SizedBox(height: 12),
              _NoticeCard(notice: notice),
            ],
            const SizedBox(height: 28),
            _SectionLabel(
              'USO DO PERÍODO',
              trailing: PlanFormat.period(plan.periodStart, plan.periodEnd),
            ),
            const SizedBox(height: 4),
            Text(
              'Os limites renovam em ${plan.resetLabel} e depois a cada mês, '
              'no mesmo dia e horário.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.muted(isDark),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _UsageRow(
                    label: 'Questões com IA por tema',
                    used: u.topic,
                    limit: p.topicQuestions,
                  ),
                  _UsageRow(
                    label: 'Questões com IA a partir dos materiais',
                    used: u.materials,
                    limit: p.materialQuestions,
                  ),
                  _UsageRow(
                    label: 'Vídeos do YouTube',
                    used: u.videoMinutes,
                    limit: p.videoMinutes,
                    unit: 'min',
                  ),
                  _UsageRow(
                    label: 'Questões guardadas (todas as turmas)',
                    used: u.stored,
                    limit: p.storedQuestions,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('PLANOS'),
            const SizedBox(height: 10),
            for (final option in PlanCatalog.all) ...[
              _PlanOptionCard(option: option, current: plan),
              const SizedBox(height: 12),
            ],
            if (!BillingConfig.enabled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'O pagamento pelo app chega em breve. Por enquanto, para '
                  'assinar ou mudar de plano, envie um e-mail para '
                  '${LandingContact.supportEmail} com o e-mail da sua conta. '
                  'O plano vale assim que for liberado. Valores mensais, em '
                  'reais.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.muted(isDark),
                    height: 1.4,
                  ),
                ),
              ),
            if (BillingConfig.enabled && _canCancel(plan)) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => _confirmCancel(context, ref, plan),
                  style: TextButton.styleFrom(foregroundColor: _C.warn),
                  child: Text(
                    'Cancelar a renovação',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static bool _canCancel(MyPlan plan) {
    final sub = plan.subscription;
    return sub != null &&
        !sub.isManual &&
        (sub.status == SubscriptionStatus.active ||
            sub.status == SubscriptionStatus.pastDue);
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    MyPlan plan,
  ) async {
    final end = plan.subscription?.currentPeriodEnd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar a renovação?'),
        content: Text(
          'Não haverá novas cobranças. O plano ${plan.plan.name} vale até '
          '${end == null ? 'o fim do período pago' : PlanFormat.date(end)}; '
          'depois, sua conta volta ao Free. Nada é apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Manter plano'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar renovação'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref.read(billingDatasourceProvider).cancel();
      messenger.showSnackBar(
        SnackBar(content: Text(message ?? 'Renovação cancelada.')),
      );
    } on BillingException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      ref.invalidate(myPlanProvider);
    }
  }
}

// ─── Plano atual ─────────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.plan});

  final MyPlan plan;

  String _status() {
    final sub = plan.subscription;
    if (sub == null) return 'Plano gratuito, sem prazo para acabar.';
    final end = sub.currentPeriodEnd;
    final endText = end == null ? null : PlanFormat.date(end);
    if (sub.isManual) {
      return endText == null
          ? 'Liberado pela equipe, sem data para acabar.'
          : 'Liberado pela equipe até $endText.';
    }
    final next = sub.nextPlanId == null
        ? ''
        : ' Na renovação, muda para o plano '
            '${PlanCatalog.byId(sub.nextPlanId!)?.name ?? sub.nextPlanId}.';
    final how = switch (sub.billingType) {
      'PIX' => ' (Pix)',
      'CREDIT_CARD' => ' (cartão)',
      _ => '',
    };
    return switch (sub.status) {
      SubscriptionStatus.pastDue =>
        'Pagamento atrasado. Pague para não perder o plano'
            '${end == null ? '' : ' — ele vale até '
                '${PlanFormat.date(end.add(const Duration(days: 3)))}'}.',
      SubscriptionStatus.canceled =>
        'Renovação cancelada: o plano vale até ${endText ?? 'o fim do '
            'período'}. Depois, volta ao Free. Nada é apagado.',
      _ => 'Renova em ${endText ?? '—'}$how.$next',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final invoice = plan.subscription?.invoiceUrl;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLANO ATUAL',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: _C.muted(isDark),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  plan.plan.name,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _C.text(isDark),
                  ),
                ),
              ),
              Text(
                plan.plan.isFree
                    ? 'Grátis'
                    : '${PlanFormat.price(plan.plan.priceCents)}/mês',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _status(),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _C.muted(isDark),
              height: 1.4,
            ),
          ),
          if (invoice != null) ...[
            const SizedBox(height: 10),
            _OpenInvoiceButton(url: invoice),
          ],
        ],
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.pending});

  final PlanSubscription pending;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = PlanCatalog.byId(pending.planId)?.name ?? pending.planId;
    final how = pending.billingType == 'PIX' ? 'Pix' : 'cartão';
    return _Card(
      borderColor: _C.accent.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aguardando o pagamento do plano $name ($how). O plano vale '
            'assim que o pagamento for confirmado.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _C.text(isDark),
              height: 1.4,
            ),
          ),
          if (pending.invoiceUrl != null) ...[
            const SizedBox(height: 10),
            _OpenInvoiceButton(url: pending.invoiceUrl!),
          ],
        ],
      ),
    );
  }
}

class _OpenInvoiceButton extends StatelessWidget {
  const _OpenInvoiceButton({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: const Text('Abrir pagamento'),
    );
  }
}

// ─── Avisos ──────────────────────────────────────────────────────────────────

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final PlanLimitNotice notice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = notice.reached ? _C.warn : _C.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            notice.reached
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.text(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.tip,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _C.muted(isDark),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Uso do período ──────────────────────────────────────────────────────────────

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.used,
    required this.limit,
    this.unit,
    this.last = false,
  });

  final String label;
  final int used;
  final int limit;
  final String? unit;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = limit <= 0 ? 1.0 : (used / limit).clamp(0.0, 1.0);
    final full = used >= limit;
    final color = full
        ? _C.warn
        : progress >= 0.9
            ? const Color(0xFFE0A85B)
            : _C.accent;
    final suffix = unit == null ? '' : ' $unit';
    return Semantics(
      label: '$label: $used de $limit$suffix',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.text(isDark),
                    ),
                  ),
                ),
                Text(
                  '$used / $limit$suffix',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: _C.track(isDark),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Planos ──────────────────────────────────────────────────────────────────

class _PlanOptionCard extends ConsumerWidget {
  const _PlanOptionCard({required this.option, required this.current});

  final Plan option;
  final MyPlan current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrent = option.id == current.plan.id;
    final features = PlanCatalog.features(option);

    return _Card(
      borderColor: isCurrent ? _C.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                option.name,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _C.text(isDark),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    'Seu plano',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _C.accent,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                option.isFree
                    ? 'Grátis'
                    : '${PlanFormat.price(option.priceCents)}/mês',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.text(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            PlanCatalog.description(option),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _C.muted(isDark),
            ),
          ),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    f.included
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: f.included ? _C.success : _C.muted(isDark),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.label,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: f.included ? _C.text(isDark) : _C.muted(isDark),
                        decoration:
                            f.included ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isCurrent && !option.isFree) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _choose(context, ref),
                // Texto escuro: branco sobre o azul claro não tem contraste.
                style: FilledButton.styleFrom(
                  backgroundColor: _C.accent,
                  foregroundColor: AppColors.backgroundDark,
                  textStyle: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(
                  BillingConfig.enabled
                      ? (current.plan.isFree
                          ? 'Assinar o ${option.name}'
                          : 'Mudar para o ${option.name}')
                      : 'Pedir o ${option.name} por e-mail',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    if (!BillingConfig.enabled) {
      final email = ref.read(authStateProvider).valueOrNull?.email ?? '';
      await LandingContact.sendEmail(
        context,
        subject: 'Quero o plano ${option.name}',
        body: 'Olá! Quero o plano ${option.name} do Arcangel '
            '(${PlanFormat.price(option.priceCents)}/mês).\n\n'
            'E-mail da minha conta: $email',
      );
      return;
    }
    await showCheckoutSheet(context, plan: option, current: current.plan);
    ref.invalidate(myPlanProvider);
  }
}

// ─── Peças ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? _C.border(isDark),
          width: borderColor == null ? 1 : 1.5,
        ),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = GoogleFonts.nunito(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.6,
      color: _C.muted(isDark),
    );
    return Row(
      children: [
        Expanded(child: Text(text, style: style)),
        if (trailing != null)
          Text(
            trailing!,
            style: style.copyWith(letterSpacing: 0, fontSize: 12),
          ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
