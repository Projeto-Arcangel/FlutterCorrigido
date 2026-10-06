import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import 'landing_header.dart';
import 'landing_layout.dart';
import 'landing_reveal.dart';

class LandingHero extends StatelessWidget {
  const LandingHero({
    super.key,
    required this.onRegisterTap,
    required this.onLoginTap,
    required this.onLearnMoreTap,
  });

  final VoidCallback onRegisterTap;
  final VoidCallback onLoginTap;
  final VoidCallback onLearnMoreTap;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final isDesktop = LandingBreakpoints.isDesktop(context);
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return Container(
      width: double.infinity,
      color: palette.background,
      alignment: Alignment.center,
      constraints: BoxConstraints(
        minHeight: isDesktop
            ? (viewportHeight - LandingHeader.height).clamp(0.0, 880.0)
            : 0.0,
      ),
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
      child: LandingContentWidth(
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: LandingReveal(
                      child: _HeroCopy(
                        alignStart: true,
                        onRegisterTap: onRegisterTap,
                        onLoginTap: onLoginTap,
                        onLearnMoreTap: onLearnMoreTap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  const Expanded(
                    flex: 5,
                    child: LandingReveal(
                      delay: Duration(milliseconds: 200),
                      child: _HeroVisual(size: 400),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const LandingReveal(child: _HeroVisual(size: 200)),
                  const SizedBox(height: 16),
                  LandingReveal(
                    delay: const Duration(milliseconds: 150),
                    child: _HeroCopy(
                      alignStart: false,
                      onRegisterTap: onRegisterTap,
                      onLoginTap: onLoginTap,
                      onLearnMoreTap: onLearnMoreTap,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.alignStart,
    required this.onRegisterTap,
    required this.onLoginTap,
    required this.onLearnMoreTap,
  });

  final bool alignStart;
  final VoidCallback onRegisterTap;
  final VoidCallback onLoginTap;
  final VoidCallback onLearnMoreTap;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDesktop = LandingBreakpoints.isDesktop(context);
    final textAlign = alignStart ? TextAlign.start : TextAlign.center;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    const buttonLabelStyle =
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Conhecimento também é uma aventura!',
            textAlign: textAlign,
            style:
                (isDesktop ? textTheme.displayMedium : textTheme.displaySmall)
                    ?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Aqui, estudar é subir de nível. Transforme conteúdos em '
            'desafios, teste seus conhecimentos, desbloqueie conquistas e '
            'acompanhe sua evolução.',
            textAlign: textAlign,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.55,
              color: palette.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: alignStart ? WrapAlignment.start : WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: onRegisterTap,
              style: FilledButton.styleFrom(
                padding: buttonPadding,
                shape: buttonShape,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible: com fonte ampliada o rótulo quebra a linha em
                  // vez de empurrar a seta para fora do botão.
                  Flexible(child: Text('Criar conta', style: buttonLabelStyle)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onLoginTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: buttonPadding,
                shape: buttonShape,
              ),
              child: const Text('Já tenho conta', style: buttonLabelStyle),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onLearnMoreTap,
          style: TextButton.styleFrom(foregroundColor: palette.accentText),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          label: const Text(
            'Conheça a plataforma',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.30),
                AppColors.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Center(child: AppLogo(size: size * 0.6)),
        ),
      ),
    );
  }
}
