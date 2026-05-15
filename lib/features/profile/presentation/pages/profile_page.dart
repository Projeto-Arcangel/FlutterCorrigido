import 'package:arcangel_o_oficial/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/achievement.dart';
import '../providers/profile_providers.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Page – ponto de entrada da feature
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileProvider);

    return Scaffold(
      body: asyncProfile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (profile) => _ProfileContent(profile: profile),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout principal
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _ProfileAppBar(),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _HeroSection(profile: profile),
              const SizedBox(height: 28),
              _StatsRow(progress: profile.progress),
              const SizedBox(height: 32),
              _AchievementsSection(
                achievements: profile.achievements,
                unlockedCount: profile.unlockedAchievementsCount,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar
// Heurística #1 (visibilidade) · #3 (controle e liberdade)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final mutedColor = isDark ? Colors.white54 : AppColors.textSecondary;
    return SliverAppBar(
      pinned: true,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(
        'Perfil',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      leading: IconButton(
        tooltip: 'Voltar',
        icon: Icon(Icons.chevron_left, color: textColor, size: 28),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        IconButton(
          tooltip: 'Configurações',
          icon: Icon(
            Icons.settings_outlined,
            color: mutedColor,
            size: 22,
          ),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero: avatar + nome + e-mail + barra de XP
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.profile});

  final ProfileData profile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _Avatar(
            photoUrl: profile.photoUrl,
            level: profile.progress.level,
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: TextStyle(
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          _XpProgressBar(
            current: profile.xpIntoLevel,
            total: profile.xpForCurrentLevel.toDouble(),
            progress: profile.levelProgress,
            nextLevel: profile.progress.level + 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar com badge de nível sobreposto
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.level});

  final String? photoUrl;
  final int level;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            color: isDark ? AppColors.surfaceDark : Colors.white,
          ),
          child: photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _DefaultAvatarIcon(),
                  ),
                )
              : const _DefaultAvatarIcon(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Nv. $level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultAvatarIcon extends StatelessWidget {
  const _DefaultAvatarIcon();

  @override
  Widget build(BuildContext context) => Icon(
        Icons.person_rounded,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white38
            : AppColors.textSecondary,
        size: 48,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de progresso de XP com rótulos explícitos
// Heurística #1 (visibilidade do status do sistema)
// ─────────────────────────────────────────────────────────────────────────────

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({
    required this.current,
    required this.total,
    required this.progress,
    required this.nextLevel,
  });

  final double current;
  final double total;
  final double progress;
  final int nextLevel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.white54 : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP: ${current.toInt()} / ${total.toInt()}',
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
            Text(
              'Próximo nível: $nextLevel',
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linha de estatísticas rápidas
// Heurística #6 (reconhecimento) — ícone + valor + rótulo em cada métrica
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.progress});

  final dynamic progress; // UserProgress

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.bolt_rounded,
              color: AppColors.primary,
              value: progress.xp.toInt().toString(),
              label: 'XP Total',
            ),
            _VerticalDivider(),
            _StatItem(
              icon: FontAwesomeIcons.coins,
              color: const Color(0xFFEAD47F),
              value: progress.gold.toString(),
              label: 'Moedas',
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.map_rounded,
              color: const Color(0xFF72D082),
              value: (progress.currentPhase + 1).toString(),
              label: 'Fase Atual',
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white12
            : Colors.black12,
      );
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seção de conquistas com grid 3×N
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({
    required this.achievements,
    required this.unlockedCount,
  });

  final List<Achievement> achievements;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Conquistas',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unlockedCount / ${achievements.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: achievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) =>
                _AchievementBadge(achievement: achievements[i]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge individual de conquista
// Heurística #8 (design estético e minimalista)
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.achievement});

  final Achievement achievement;

  Color get _rarityColor {
    if (!achievement.unlocked) return Colors.white12;
    return switch (achievement.rarity) {
      AchievementRarity.bronze   => const Color(0xFFCD7F32),
      AchievementRarity.silver   => const Color(0xFFC0C0C0),
      AchievementRarity.gold     => const Color(0xFFEAD47F),
      AchievementRarity.platinum => AppColors.primary,
    };
  }

  String get _rarityLabel => switch (achievement.rarity) {
        AchievementRarity.bronze   => 'Bronze',
        AchievementRarity.silver   => 'Prata',
        AchievementRarity.gold     => 'Ouro',
        AchievementRarity.platinum => 'Platina',
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final lockedIcon = isDark ? Colors.white24 : Colors.black12;
    final lockedText = isDark ? Colors.white24 : AppColors.textSecondary;
    return Tooltip(
      message: '${achievement.title}\n${achievement.description}',
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
            color: achievement.unlocked
                ? _rarityColor.withValues(alpha: 0.6)
                : (isDark ? Colors.white10 : Colors.black12),
            width: 1.5,
          ),
          boxShadow: achievement.unlocked
              ? [
                  BoxShadow(
                    color: _rarityColor.withValues(alpha: 0.25),
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
              achievement.unlocked ? achievement.icon : Icons.lock_outlined,
              color: achievement.unlocked ? _rarityColor : lockedIcon,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: achievement.unlocked
                    ? (isDark ? Colors.white : AppColors.textPrimary)
                    : lockedText,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            if (achievement.unlocked)
              Text(
                _rarityLabel,
                style: TextStyle(
                  color: _rarityColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// Estado de erro
// Heurística #9 (ajuda a reconhecer, diagnosticar e recuperar erros)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: isDark ? Colors.white38 : AppColors.textSecondary,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'Não foi possível carregar o perfil',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(profileProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}