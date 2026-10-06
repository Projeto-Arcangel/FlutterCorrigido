import 'package:flutter/material.dart';

import 'landing_layout.dart';
import 'landing_reveal.dart';

/// Moldura padrão das seções navegáveis: título, subtítulo e conteúdo. O nome
/// da seção (Sobre, Planos, Suporte) aparece só no cabeçalho.
/// A `key` recebida é usada pela página para rolar até a seção.
class LandingSectionContainer extends StatelessWidget {
  const LandingSectionContainer({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.alternate = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool alternate;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final isDesktop = LandingBreakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: alternate ? palette.backgroundAlt : palette.background,
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 96 : 64),
      child: LandingContentWidth(
        child: Column(
          children: [
            LandingReveal(
              child: Column(
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: (isDesktop
                              ? textTheme.displaySmall
                              : textTheme.headlineMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isDesktop ? 48 : 32),
            child,
          ],
        ),
      ),
    );
  }
}
