import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Card de seleção de papel (Aluno / Professor).
///
/// Recebe [accentColor] para diferenciar visualmente cada perfil
/// sem duplicar o widget. O feedback de press é tratado internamente
/// via [AnimatedScale] + [AnimatedContainer].
class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData     icon;
  final Color        accentColor;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kSurface = isDark ? const Color(0xFF242B30) : Colors.white;
    final kSurfaceBorder = isDark ? const Color(0xFF2E373E) : Colors.black12;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale:    _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: _pressed ? kSurface.withOpacity(0.85) : kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.accentColor.withOpacity(0.55)
                  : kSurfaceBorder,
              width: 1.4,
            ),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              _IconContainer(
                icon: widget.icon,
                accentColor: widget.accentColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CardTexts(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  accentColor: widget.accentColor,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: widget.accentColor.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets internos ─────────────────────────────────────────────────────

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    required this.accentColor,
  });

  final IconData icon;
  final Color    accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 24, color: accentColor),
    );
  }
}

class _CardTexts extends StatelessWidget {
  const _CardTexts({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final Color  accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: accentColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF8FA3AE) : const Color(0xFF5A6B78),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}