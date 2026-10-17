import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/achievement.dart';

/// Cor da raridade de uma conquista liberada.
Color achievementRarityColor(AchievementRarity rarity) => switch (rarity) {
      AchievementRarity.bronze => const Color(0xFFCD7F32),
      AchievementRarity.silver => const Color(0xFFC0C0C0),
      AchievementRarity.gold => const Color(0xFFEAD47F),
      AchievementRarity.platinum => AppColors.primary,
    };

String achievementRarityLabel(AchievementRarity rarity) => switch (rarity) {
      AchievementRarity.bronze => 'Bronze',
      AchievementRarity.silver => 'Prata',
      AchievementRarity.gold => 'Ouro',
      AchievementRarity.platinum => 'Platina',
    };

/// Selo de uma conquista (perfil do aluno e perfil do colega). Bloqueada,
/// mostra o cadeado e quanto falta ("3/5").
/// Heurística #8 (design estético e minimalista).
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final lockedIcon = isDark ? Colors.white24 : Colors.black12;
    final lockedText = isDark ? Colors.white24 : AppColors.textSecondary;
    final unlocked = achievement.unlocked;
    final rarityColor =
        unlocked ? achievementRarityColor(achievement.rarity) : Colors.white12;
    final progress = achievement.progressLabel;
    final reward = achievement.goldReward > 0
        ? '\nVale ${achievement.goldReward} moedas'
        : '';
    return Tooltip(
      message: '${achievement.title}\n${achievement.description}$reward',
      preferBelow: false,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: TextStyle(
        color: isDark ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? rarityColor.withValues(alpha: 0.6)
                : (isDark ? Colors.white10 : Colors.black12),
            width: 1.5,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unlocked ? achievement.icon : Icons.lock_outlined,
              color: unlocked ? rarityColor : lockedIcon,
              size: 28,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked
                      ? (isDark ? Colors.white : AppColors.textPrimary)
                      : lockedText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (unlocked)
              Text(
                achievementRarityLabel(achievement.rarity),
                style: TextStyle(
                  color: rarityColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (progress != null)
              Text(
                progress,
                style: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
