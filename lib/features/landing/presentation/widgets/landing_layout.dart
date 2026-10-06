import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

abstract final class LandingBreakpoints {
  static const double desktop = 960;
  static const double compact = 600;
  static const double contentMaxWidth = 1120;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
}

class LandingPalette {
  const LandingPalette._(this.isDark);

  factory LandingPalette.of(BuildContext context) =>
      LandingPalette._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  Color get background =>
      isDark ? AppColors.backgroundDark : AppColors.background;
  Color get backgroundAlt =>
      isDark ? const Color(0xFF222B30) : const Color(0xFFF1F4F8);
  Color get card => isDark ? AppColors.surfaceDark : Colors.white;
  Color get border => isDark ? const Color(0x1AFFFFFF) : Colors.black12;
  Color get textPrimary =>
      isDark ? AppColors.textOnDark : AppColors.textPrimary;
  // No claro, #5B6472 (e não o textSecondary #6B7280, que fica em ~4,3:1 sobre
  // o fundo alternado #F1F4F8): ≥ 5,4:1 nos dois fundos da landing.
  Color get textMuted =>
      isDark ? const Color(0xFF8FA3AE) : const Color(0xFF5B6472);
  Color get primarySubtle => AppColors.primary.withValues(alpha: 0.12);

  Color get accentText =>
      isDark ? AppColors.primary : AppColors.primaryTextOnLight;
}

/// Grade responsiva: quantas colunas couberem (até [maxColumns]) com cada
/// item tendo ao menos [minItemWidth]. Os itens de uma mesma linha ficam com a
/// mesma altura, para os cards alinharem.
class LandingGrid extends StatelessWidget {
  const LandingGrid({
    super.key,
    required this.children,
    this.minItemWidth = 300,
    this.maxColumns = 3,
    this.spacing = 20,
    this.evenRows = false,
    this.singleColumnMaxWidth,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  /// Só usa uma quantidade de colunas que divida os itens por igual; senão
  /// cai para uma coluna (evita, p.ex., 2 + 1 card sobrando sozinho).
  final bool evenRows;

  /// Largura máxima dos itens quando a grade vira uma coluna só.
  final double? singleColumnMaxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        if (evenRows && children.length % columns != 0) columns = 1;

        final maxWidth = singleColumnMaxWidth;
        if (columns == 1 && maxWidth != null) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: IntrinsicHeight(child: children[i]),
                ),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final rowItems = children.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i < rowItems.length
                          ? rowItems[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: spacing),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// Moldura de card usada nas seções da landing.
class LandingCard extends StatelessWidget {
  const LandingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderColor,
    this.borderWidth = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? palette.border,
          width: borderWidth,
        ),
      ),
      child: child,
    );
  }
}

/// Ícone em "pílula" colorida, usado nos cards das seções.
class LandingIconBadge extends StatelessWidget {
  const LandingIconBadge({super.key, required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = LandingPalette.of(context);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.primarySubtle,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: palette.accentText, size: size * 0.5),
      ),
    );
  }
}

/// Centraliza o conteúdo na largura máxima da landing, com margens laterais
/// proporcionais ao tamanho da tela.
class LandingContentWidth extends StatelessWidget {
  const LandingContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final horizontal = LandingBreakpoints.isDesktop(context)
        ? 32.0
        : LandingBreakpoints.isCompact(context)
            ? 16.0
            : 24.0;

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: LandingBreakpoints.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: child,
        ),
      ),
    );
  }
}
