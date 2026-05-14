import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

abstract class _TeacherColors {
  static const Color accent = Color(0xFF72D082);
  static const Color accentSubtle = Color(0x1A72D082);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color cardBorder = Color(0x14FFFFFF);
}

class TeacherStatItem {
  const TeacherStatItem({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;
}

class TeacherHeader extends StatelessWidget {
  const TeacherHeader({
    super.key,
    required this.displayName,
    required this.onLogout,
    required this.stats,
  });

  final String displayName;
  final VoidCallback onLogout;
  final List<TeacherStatItem> stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderBar(displayName: displayName, onLogout: onLogout),
        _StatsRow(stats: stats),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.displayName, required this.onLogout});

  final String displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Área do Professor',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _TeacherColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prof. $displayName',
                  style: GoogleFonts.nunito(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onLongPress: onLogout,
            child: Tooltip(
              message: 'Segure para sair',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _TeacherColors.accentSubtle,
                  border: Border.all(
                    color: _TeacherColors.accent.withValues(alpha: 0.55),
                    width: 1.6,
                  ),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.chalkboardUser,
                    color: _TeacherColors.accent,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<TeacherStatItem> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final isLast = entry.key == stats.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 10),
              child: _StatCard(item: entry.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final TeacherStatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _TeacherColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            item.icon,
            size: 16,
            color: _TeacherColors.accent.withValues(alpha: 0.75),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _TeacherColors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
