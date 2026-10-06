import 'package:flutter/material.dart';

import '../../../../core/widgets/app_logo.dart';
import '../landing_contact.dart';
import '../landing_section.dart';
import 'landing_layout.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({
    super.key,
    required this.onSectionTap,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  final ValueChanged<LandingSection> onSectionTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = LandingBreakpoints.isDesktop(context);

    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 8),
            Text(
              'Arcangel',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Atividades em formato de jogo para o professor criar, aplicar e '
            'acompanhar.',
            style: textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );

    final columns = [
      _FooterColumn(
        title: 'Navegação',
        links: [
          for (final section in LandingSection.values)
            (section.label, () => onSectionTap(section)),
        ],
      ),
      _FooterColumn(
        title: 'Conta',
        links: [
          ('Entrar', onLoginTap),
          ('Criar conta', onRegisterTap),
        ],
      ),
      _FooterColumn(
        title: 'Contato',
        links: [
          (
            LandingContact.supportEmail,
            () =>
                LandingContact.sendEmail(context, subject: 'Suporte Arcangel'),
          ),
        ],
      ),
    ];

    return Semantics(
      container: true,
      label: 'Rodapé',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.background,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: EdgeInsets.only(top: isDesktop ? 56 : 40, bottom: 24),
        child: LandingContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: brand),
                    for (final column in columns) Expanded(child: column),
                  ],
                )
              else ...[
                brand,
                const SizedBox(height: 32),
                Wrap(
                  spacing: 48,
                  runSpacing: 24,
                  children: columns,
                ),
              ],
              const SizedBox(height: 40),
              Divider(color: palette.border, height: 1),
              const SizedBox(height: 20),
              Text(
                '© ${DateTime.now().year} Arcangel. Todos os direitos '
                'reservados.',
                style: textTheme.bodySmall?.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuo interno dos links do rodapé. O link é deslocado para a esquerda na
/// mesma medida, para o TEXTO continuar alinhado ao título da coluna.
const double _linkInset = 12;

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<(String, VoidCallback)> links;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final (label, onTap) in links)
          Transform.translate(
            offset: const Offset(-_linkInset, 0),
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: palette.textMuted,
                // Respiro ao redor do texto: o realce de foco/hover/clique não
                // encosta nas letras.
                padding: const EdgeInsets.symmetric(
                  horizontal: _linkInset,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 44),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(label),
            ),
          ),
      ],
    );
  }
}
