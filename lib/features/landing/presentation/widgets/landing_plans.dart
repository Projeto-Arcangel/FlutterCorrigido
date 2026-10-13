import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../plans/domain/entities/plan.dart';
import '../../../plans/domain/plan_catalog.dart';
import '../landing_contact.dart';
import 'landing_layout.dart';
import 'landing_reveal.dart';

/// Conteúdo da seção "Planos". Ainda não há cobrança no app: o Free começa
/// pelo cadastro e os planos pagos são contratados pelo e-mail do suporte —
/// o botão diz exatamente isso, para não prometer um checkout que não existe.
/// Preços e limites vêm de [PlanCatalog] (os mesmos do banco).
class LandingPlans extends StatelessWidget {
  const LandingPlans({super.key, required this.onStartFree});

  final VoidCallback onStartFree;

  /// Plano recomendado (destacado).
  static const _recommendedId = 'pro';

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Column(
      children: [
        LandingGrid(
          minItemWidth: 300,
          spacing: 24,
          evenRows: true,
          singleColumnMaxWidth: 480,
          children: [
            for (var i = 0; i < PlanCatalog.all.length; i++)
              LandingReveal(
                delay: Duration(milliseconds: 120 * i),
                child: _PlanCard(
                  plan: PlanCatalog.all[i],
                  recommended: PlanCatalog.all[i].id == _recommendedId,
                  onPressed: PlanCatalog.all[i].isFree
                      ? onStartFree
                      : () => LandingContact.sendEmail(
                            context,
                            subject: 'Quero assinar o plano '
                                '${PlanCatalog.all[i].name}',
                          ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Toda conta começa no plano Free. Para assinar o Pro ou o '
            'Premium, envie uma mensagem para ${LandingContact.supportEmail} '
            'informando o e-mail da sua conta. Valores mensais em reais; os '
            'limites renovam a cada mês, contados do dia da assinatura (no '
            'Free, do dia do cadastro).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.recommended,
    required this.onPressed,
  });

  final Plan plan;
  final bool recommended;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 18);
    const buttonLabelStyle =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    final buttonLabel = plan.isFree ? 'Começar grátis' : 'Assinar por e-mail';
    final button = recommended
        ? FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: buttonPadding,
              shape: buttonShape,
            ),
            icon: const Icon(Icons.mail_outline_rounded, size: 20),
            label: Text(buttonLabel, style: buttonLabelStyle),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: buttonPadding,
              shape: buttonShape,
            ),
            icon: Icon(
              plan.isFree
                  ? Icons.arrow_forward_rounded
                  : Icons.mail_outline_rounded,
              size: 20,
            ),
            label: Text(buttonLabel, style: buttonLabelStyle),
          );

    return LandingCard(
      padding: const EdgeInsets.all(28),
      borderColor: recommended ? AppColors.primary : null,
      borderWidth: recommended ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap: lado a lado normalmente; com fonte ampliada o selo desce
          // para a linha de baixo em vez de estourar o card.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: Text(
                  plan.name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (recommended) const _RecommendedBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            PlanCatalog.description(plan),
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _Price(cents: plan.priceCents),
          const SizedBox(height: 24),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: 20),
          for (final feature in PlanCatalog.features(plan))
            _FeatureRow(label: feature.label, included: feature.included),
          const Spacer(),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: button),
        ],
      ),
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accentText,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        'Recomendado',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: palette.isDark ? AppColors.backgroundDark : Colors.white,
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.cents});

  /// Preço mensal em centavos; 0 = gratuito.
  final int cents;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: palette.textPrimary,
    );
    if (cents == 0) {
      return Semantics(
        label: 'Gratuito',
        excludeSemantics: true,
        child: Text('Grátis', style: valueStyle),
      );
    }

    final reais = cents ~/ 100;
    final centavos = cents % 100;
    return Semantics(
      label: centavos == 0
          ? '$reais reais por mês'
          : '$reais reais e $centavos centavos por mês',
      excludeSemantics: true,
      // Um único texto com trechos de estilos diferentes: alinha pela linha
      // de base e quebra a linha se a fonte estiver ampliada.
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'R\$ ',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            TextSpan(text: '$reais', style: valueStyle),
            if (centavos != 0)
              TextSpan(
                text: ',${centavos.toString().padLeft(2, '0')}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                ),
              ),
            TextSpan(
              text: '/mês',
              style: textTheme.titleMedium?.copyWith(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label, required this.included});

  final String label;
  final bool included;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final success =
        palette.isDark ? const Color(0xFF72D082) : const Color(0xFF1A7F4B);

    return Semantics(
      label: included ? label : '$label: não incluso',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              included
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline,
              size: 20,
              color: included ? success : palette.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  height: 1.4,
                  color: included ? palette.textPrimary : palette.textMuted,
                  decoration: included ? null : TextDecoration.lineThrough,
                  decorationColor: palette.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
