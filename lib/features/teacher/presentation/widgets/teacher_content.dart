import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

abstract class _TeacherColors {
  static const Color divider = Color(0x1AFFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color cardBorder = Color(0x14FFFFFF);
}

class TeacherQuickAction {
  const TeacherQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;
}

class TeacherActivityItem {
  const TeacherActivityItem({
    required this.description,
    required this.timeAgo,
    required this.icon,
    required this.dotColor,
  });
  final String description;
  final String timeAgo;
  final IconData icon;
  final Color dotColor;
}

class TeacherContent extends StatelessWidget {
  const TeacherContent({
    super.key,
    required this.actions,
    required this.activities,
  });

  final List<TeacherQuickAction> actions;
  final List<TeacherActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          label: 'ATALHOS RÁPIDOS',
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
        ),
        _QuickActionsList(actions: actions),
        _RecentActivitySection(activities: activities),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 12),
  });

  final String label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _TeacherColors.textMuted,
          letterSpacing: 2.2,
        ),
      ),
    );
  }
}

class _QuickActionsList extends StatelessWidget {
  const _QuickActionsList({required this.actions});

  final List<TeacherQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _TeacherColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions.asMap().entries.map((entry) {
            final isLast = entry.key == actions.length - 1;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickActionTile(action: entry.value),
                if (!isLast)
                  const Divider(
                    height: 1,
                    color: _TeacherColors.divider,
                    indent: 20,
                    endIndent: 20,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final TeacherQuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        splashColor: action.iconColor.withValues(alpha: 0.08),
        highlightColor: action.iconColor.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _ActionIcon(
                icon: action.icon,
                color: action.iconColor,
                bg: action.iconBg,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _TeacherColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: action.iconColor.withValues(alpha: 0.55),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: FaIcon(icon, color: color, size: 18),
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.activities});

  final List<TeacherActivityItem> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'ATIVIDADE RECENTE'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _TeacherColors.cardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: activities.asMap().entries.map((entry) {
                final isLast = entry.key == activities.length - 1;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActivityTile(item: entry.value),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        color: _TeacherColors.divider,
                        indent: 20,
                        endIndent: 20,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final TeacherActivityItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.dotColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: FaIcon(item.icon, size: 14, color: item.dotColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.timeAgo,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _TeacherColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
