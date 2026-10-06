import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../landing_section.dart';
import 'landing_layout.dart';

/// Cabeçalho fixo da landing. No desktop exibe a navegação por seções
/// inline; em telas menores a navegação vai para o menu lateral.
class LandingHeader extends StatelessWidget implements PreferredSizeWidget {
  const LandingHeader({
    super.key,
    required this.activeSection,
    required this.elevated,
    required this.onSectionTap,
    required this.onBrandTap,
    required this.onLoginTap,
    required this.onRegisterTap,
    required this.onMenuTap,
  });

  static const double height = 72;

  final LandingSection? activeSection;
  final bool elevated;
  final ValueChanged<LandingSection> onSectionTap;
  final VoidCallback onBrandTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final isDesktop = LandingBreakpoints.isDesktop(context);
    final isCompact = LandingBreakpoints.isCompact(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(
          bottom: BorderSide(
            color: elevated ? palette.border : Colors.transparent,
          ),
        ),
        boxShadow: [
          if (elevated)
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: palette.isDark ? 0.35 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: height,
            child: LandingContentWidth(
              child: Row(
                children: [
                  if (!isDesktop) ...[
                    IconButton(
                      onPressed: onMenuTap,
                      tooltip: 'Abrir menu de navegação',
                      icon: Icon(
                        Icons.menu_rounded,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (isDesktop) ...[
                    _Brand(onTap: onBrandTap),
                    Expanded(
                      // scaleDown só age se o texto ampliado não couber.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final section in LandingSection.values)
                              _NavItem(
                                section: section,
                                active: section == activeSection,
                                onTap: () => onSectionTap(section),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    // Ocupa o espaço livre; em telas estreitas (ou com fonte
                    // ampliada) a marca encolhe em vez de empurrar os botões.
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Brand(onTap: onBrandTap),
                        ),
                      ),
                    ),
                  if (isCompact)
                    _LoginButton(onPressed: onLoginTap, outlined: true)
                  else ...[
                    _LoginButton(onPressed: onLoginTap),
                    const SizedBox(width: 8),
                    _RegisterButton(onPressed: onRegisterTap),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Semantics(
      button: true,
      label: 'Arcangel, voltar ao início da página',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 36),
              const SizedBox(width: 8),
              Text(
                'Arcangel',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.active,
    required this.onTap,
  });

  final LandingSection section;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        selected: active,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: active ? palette.accentText : palette.textPrimary,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: active ? 20 : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onPressed, this.outlined = false});

  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    const label = Text(
      'Entrar',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: shape,
        ),
        child: label,
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: shape,
      ),
      child: label,
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Criar conta',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}
