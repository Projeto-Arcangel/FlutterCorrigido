import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Seção superior da tela de seleção de papel:
/// ícone do app + título "Arcangel" + tagline.
///
/// Isolado para que a [RoleSelectionPage] não misture
/// lógica de animação com montagem de widgets de marca.
class RoleSelectionHeader extends StatelessWidget {
  const RoleSelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppIcon(),
        const SizedBox(height: 20),
        Text(
          'Arcangel',
          style: GoogleFonts.nunito(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFEAD47F),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CIÊNCIAS HUMANAS · ENSINO MÉDIO',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8FA3AE),
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

/// Tenta carregar o asset do app; exibe ícone genérico como fallback
/// para não quebrar em ambientes sem assets configurados.
class _AppIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/app_launcher_icon.png',
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackIcon(),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF72ACD0).withOpacity(0.15),
        border: Border.all(
          color: const Color(0xFF72ACD0).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: const Icon(
        Icons.school_outlined,
        color: Color(0xFF72ACD0),
        size: 36,
      ),
    );
  }
}