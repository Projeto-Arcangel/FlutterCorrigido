import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../landing_contact.dart';
import 'landing_layout.dart';
import 'landing_reveal.dart';

/// Conteúdo da seção "Planos". Ainda não há cobrança no app: o Free começa
/// pelo cadastro e os planos pagos são contratados pelo e-mail do suporte —
/// o botão diz exatamente isso, para não prometer um checkout que não existe.
class LandingPlans extends StatelessWidget {
  const LandingPlans({super.key, required this.onStartFree});

  final VoidCallback onStartFree;

  // Mesmos itens, na mesma ordem, em todos os planos: dá para comparar
  // linha a linha. `null` = não incluso no plano.
  static const _plans = [
    _Plan(
      name: 'Free',
      price: null,
      description: 'Para conhecer a plataforma e começar com suas turmas.',
      features: [
        '200 questões por mês com IA a partir de um tema',
        '50 questões por mês com IA a partir dos seus materiais',
        'Armazenamento de até 500 questões',
        'Banco de questões do ENEM',
        'Exportar notas em planilha (.xlsx)',
        null,
        null,
      ],
    ),
    _Plan(
      name: 'Pro',
      price: 15,
      description: 'Para o professor que usa o Arcangel toda semana.',
      recommended: true,
      features: [
        '500 questões por mês com IA a partir de um tema',
        '100 questões por mês com IA a partir dos seus materiais',
        'Armazenamento de até 750 questões',
        'Banco de questões do ENEM',
        'Exportar notas em planilha (.xlsx)',
        'Exportar atividades em PDF',
        null,
      ],
    ),
    _Plan(
      name: 'Premium',
      price: 40,
      description: 'Para quem produz muito conteúdo e quer atendimento '
          'prioritário.',
      features: [
        '1.000 questões por mês com IA a partir de um tema',
        '150 questões por mês com IA a partir dos seus materiais',
        'Armazenamento de até 1.000 questões',
        'Banco de questões do ENEM',
        'Exportar notas em planilha (.xlsx)',
        'Exportar atividades em PDF',
        'Suporte prioritário',
      ],
    ),
  ];

  /// Rótulos dos itens que algum plano não inclui (mostrados riscados).
  static const _featureNames = [
    'Questões com IA a partir de um tema',
    'Questões com IA a partir dos seus materiais',
    'Armazenamento de questões',
    'Banco de questões do ENEM',
    'Exportar notas em planilha (.xlsx)',
    'Exportar atividades em PDF',
    'Suporte prioritário',
  ];

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
            for (var i = 0; i < _plans.length; i++)
              LandingReveal(
                delay: Duration(milliseconds: 120 * i),
                child: _PlanCard(
                  plan: _plans[i],
                  featureNames: _featureNames,
                  onPressed: _plans[i].isFree
                      ? onStartFree
                      : () => LandingContact.sendEmail(
                            context,
                            subject: 'Quero assinar o plano ${_plans[i].name}',
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
            'informando o e-mail da sua conta. Valores mensais em reais.',
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

class _Plan {
  const _Plan({
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.recommended = false,
  });

  final String name;

  /// Preço mensal em reais; `null` = gratuito.
  final int? price;
  final String description;
  final List<String?> features;
  final bool recommended;

  bool get isFree => price == null;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.featureNames,
    required this.onPressed,
  });

  final _Plan plan;
  final List<String> featureNames;
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
    final button = plan.recommended
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
      borderColor: plan.recommended ? AppColors.primary : null,
      borderWidth: plan.recommended ? 2 : 1,
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
              if (plan.recommended) const _RecommendedBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _Price(price: plan.price),
          const SizedBox(height: 24),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: 20),
          for (var i = 0; i < plan.features.length; i++)
            _FeatureRow(
              label: plan.features[i] ?? featureNames[i],
              included: plan.features[i] != null,
            ),
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
  const _Price({required this.price});

  final int? price;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final valueStyle = textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: palette.textPrimary,
    );
    final price = this.price;

    if (price == null) {
      return Semantics(
        label: 'Gratuito',
        excludeSemantics: true,
        child: Text('Grátis', style: valueStyle),
      );
    }

    return Semantics(
      label: '$price reais por mês',
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
            TextSpan(text: '$price', style: valueStyle),
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
