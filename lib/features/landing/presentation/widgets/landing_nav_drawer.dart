import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../landing_section.dart';
import 'landing_layout.dart';

/// Menu de navegação para telas abaixo do breakpoint desktop.
class LandingNavDrawer extends StatelessWidget {
  const LandingNavDrawer({
    super.key,
    required this.activeSection,
    required this.onSectionTap,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  final LandingSection? activeSection;
  final ValueChanged<LandingSection> onSectionTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  void _closeThen(BuildContext context, VoidCallback action) {
    Scaffold.of(context).closeDrawer();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonLabelStyle =
        TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

    return Drawer(
      backgroundColor: palette.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Arcangel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar menu',
                    onPressed: () => Scaffold.of(context).closeDrawer(),
                    icon: Icon(Icons.close_rounded, color: palette.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (final section in LandingSection.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: section == activeSection,
                    selectedColor: palette.accentText,
                    selectedTileColor: palette.primarySubtle,
                    iconColor: palette.textMuted,
                    textColor: palette.textPrimary,
                    shape: buttonShape,
                    leading: Icon(section.icon),
                    title: Text(
                      section.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () =>
                        _closeThen(context, () => onSectionTap(section)),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _closeThen(context, onLoginTap),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  minimumSize: const Size.fromHeight(52),
                  shape: buttonShape,
                ),
                child: const Text('Entrar', style: buttonLabelStyle),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _closeThen(context, onRegisterTap),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: buttonShape,
                ),
                child: const Text('Criar conta', style: buttonLabelStyle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
