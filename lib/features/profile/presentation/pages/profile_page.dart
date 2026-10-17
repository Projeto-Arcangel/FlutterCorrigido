import 'package:arcangel_o_oficial/core/router/app_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../progress/domain/entities/user_progress.dart';
import '../../domain/entities/classmate_profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/achievement_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page – ponto de entrada da feature
// ─────────────────────────────────────────────────────────────────────────────

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key, this.showProgress = false});

  /// Nível, XP, moedas e conquistas aparecem só quando o aluno abre o
  /// perfil de dentro de uma turma. Pela tela inicial, o perfil mostra só os
  /// dados da conta (e o caminho para as configurações).
  final bool showProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileProvider);

    return Scaffold(
      body: asyncProfile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorView(
          message: ErrorMessages.from(
            err,
            fallback: 'Não foi possível carregar seu perfil.',
          ),
        ),
        data: (profile) => _ProfileContent(
          profile: profile,
          showProgress: showProgress,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout principal
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required this.showProgress});

  final ProfileData profile;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _ProfileAppBar(),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _HeroSection(profile: profile, showProgress: showProgress),
              if (showProgress) ...[
                const SizedBox(height: 28),
                _StatsRow(progress: profile.progress),
                const SizedBox(height: 32),
                const _AchievementsSection(),
              ] else ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Seu nível e suas conquistas aparecem quando você abre o '
                    'perfil dentro de uma turma.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
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
  const _HeroSection({required this.profile, required this.showProgress});

  final ProfileData profile;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Largura total: sem a barra de XP (perfil pela tela inicial), a
      // coluna encolheria e o conteúdo sairia do centro.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: double.infinity),
          _Avatar(
            photoUrl: profile.photoUrl,
            level: profile.progress.level,
            levelProgress: profile.levelProgress,
            showLevel: showProgress,
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
          if (showProgress) ...[
            const SizedBox(height: 20),
            _XpProgressBar(
              current: profile.xpIntoLevel,
              total: profile.xpForCurrentLevel.toDouble(),
              progress: profile.levelProgress,
              nextLevel: profile.progress.level + 1,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar com badge de nível sobreposto
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.level,
    required this.levelProgress,
    required this.showLevel,
  });

  final String? photoUrl;
  final int level;
  final double levelProgress;

  /// Anel de XP e selo de nível (só no perfil aberto pela turma).
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: showLevel ? levelProgress : 0,
                  strokeWidth: 3,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarBg,
                ),
                child: photoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl!,
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _DefaultAvatarIcon(),
                        ),
                      )
                    : const _DefaultAvatarIcon(),
              ),
            ],
          ),
        ),
        if (showLevel)
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

  final UserProgress progress;

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

class _AchievementsSection extends ConsumerWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : AppColors.textSecondary;
    final asyncMine = ref.watch(myAchievementsProvider);
    final mine = asyncMine.valueOrNull;
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
              if (mine != null && !mine.partial)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mine.unlockedCount} / ${mine.achievements.length}',
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
          if (mine == null)
            asyncMine.hasError
                ? Text(
                    'Não foi possível carregar as conquistas.',
                    style: TextStyle(color: muted, fontSize: 13),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
          else ...[
            if (mine.partial) _PartialAchievementsNotice(color: muted),
            _AchievementsGrid(mine: mine),
          ],
        ],
      ),
    );
  }
}

/// O servidor não respondeu: só as de XP aparecem, e a tela diz isso.
class _PartialAchievementsNotice extends ConsumerWidget {
  const _PartialAchievementsNotice({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'As conquistas por tipo de questão não carregaram agora. '
              'Aqui estão só as de XP.',
              style: TextStyle(color: color, fontSize: 12, height: 1.3),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(myAchievementsProvider),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class _AchievementsGrid extends StatelessWidget {
  const _AchievementsGrid({required this.mine});

  final MyAchievements mine;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: mine.achievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) =>
          AchievementBadge(achievement: mine.achievements[i]),
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