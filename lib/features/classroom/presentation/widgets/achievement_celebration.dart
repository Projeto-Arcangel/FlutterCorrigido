import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../profile/domain/entities/achievement.dart';
import '../../../profile/presentation/widgets/achievement_badge.dart';
import '../../domain/entities/phase_attempt.dart';

/// Parabeniza o aluno pelas conquistas alcançadas ao terminar a fase.
/// [onOpenProfile] abre o perfil (onde ficam todas as conquistas).
Future<void> showAchievementCelebration(
  BuildContext context,
  List<UnlockedAchievement> unlocked, {
  VoidCallback? onOpenProfile,
}) {
  if (unlocked.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AchievementCelebration(
      unlocked: unlocked,
      onClose: () => Navigator.of(dialogContext).pop(),
      onOpenProfile: onOpenProfile == null
          ? null
          : () {
              Navigator.of(dialogContext).pop();
              onOpenProfile();
            },
    ),
  );
}

/// Aviso "Conquista alcançada!": cada conquista com o ícone na cor da
/// raridade, a descrição e as moedas que deu.
class AchievementCelebration extends StatelessWidget {
  const AchievementCelebration({
    super.key,
    required this.unlocked,
    required this.onClose,
    this.onOpenProfile,
  });

  final List<UnlockedAchievement> unlocked;
  final VoidCallback onClose;
  final VoidCallback? onOpenProfile;

  static const _trophy = Color(0xFFEAD47F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final many = unlocked.length > 1;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Pop(
                still: still,
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _trophy.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 44,
                      color: _trophy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Parabéns!',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                many
                    ? 'Você alcançou ${unlocked.length} conquistas nesta fase.'
                    : 'Você alcançou uma conquista nesta fase.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < unlocked.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _Pop(
                  still: still,
                  delayMs: 180 + 140 * i,
                  child: _UnlockedRow(achievement: unlocked[i]),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onClose,
                child: const Text('Continuar'),
              ),
              if (onOpenProfile != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onOpenProfile,
                  child: const Text('Ver minhas conquistas'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockedRow extends StatelessWidget {
  const _UnlockedRow({required this.achievement});

  final UnlockedAchievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final catalog = _catalog(achievement.id);
    final color = achievementRarityColor(catalog?.rarity ?? AchievementRarity.gold);
    final description = catalog?.description ?? '';
    return Semantics(
      container: true,
      label: 'Conquista alcançada: ${achievement.title}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(achievementIcon(achievement.id), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (achievement.gold > 0) ...[
              const SizedBox(width: 8),
              const Icon(FontAwesomeIcons.coins, size: 14, color: Color(0xFFB98500)),
              const SizedBox(width: 4),
              Text(
                '+${achievement.gold}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB98500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Achievement? _catalog(String id) {
    for (final a in achievementCatalog) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Entrada com um pulinho (parada, com "reduzir movimento").
class _Pop extends StatelessWidget {
  const _Pop({required this.child, required this.still, this.delayMs = 0});

  final Widget child;
  final bool still;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    if (still) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Interval(delayMs / (520 + delayMs), 1, curve: Curves.easeOutBack),
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: child,
    );
  }
}
