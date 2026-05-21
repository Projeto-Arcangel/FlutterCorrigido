import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/widgets/app_logo.dart';

class RoleSelectionHeader extends StatelessWidget {
  const RoleSelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 72),
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