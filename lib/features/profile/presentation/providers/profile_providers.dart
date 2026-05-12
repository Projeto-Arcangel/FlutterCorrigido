import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger_provider.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/domain/entities/user_progress.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/achievement.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DTO: dados já prontos para a view consumir, sem lógica de negócio nos widgets
// ─────────────────────────────────────────────────────────────────────────────

class ProfileData {
  const ProfileData({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.progress,
    required this.achievements,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final UserProgress progress;
  final List<Achievement> achievements;

  // ── Lógica de nível ──────────────────────────────────────────────────────
  // Cada nível exige (nível × 100) XP, escala linear e simples de entender.
  // Exemplo: nível 1 → 100 XP | nível 5 → 500 XP | nível 10 → 1 000 XP.

  int get xpForCurrentLevel => progress.level * 100;

  double get xpIntoLevel {
    final xpAtLevelStart = List.generate(
      progress.level - 1,
      (i) => (i + 1) * 100,
    ).fold<double>(0, (acc, v) => acc + v);

    return (progress.xp - xpAtLevelStart).clamp(
      0,
      xpForCurrentLevel.toDouble(),
    );
  }

  double get levelProgress =>
      (xpIntoLevel / xpForCurrentLevel).clamp(0.0, 1.0);

  int get unlockedAchievementsCount =>
      achievements.where((a) => a.unlocked).length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final profileProvider = FutureProvider.autoDispose<ProfileData>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) throw Exception('Usuário não autenticado.');

  final logger = ref.watch(loggerProvider);

  final result = await ref
      .watch(progressRepositoryProvider)
      .getProgress(user.id);

  final progress = result.fold(
    (failure) {
      logger.w('getProgress falhou no profileProvider: ${failure.message}');
      // Fail-safe: retorna progresso zerado para não bloquear a tela
      return UserProgress(
        userId: user.id,
        xp: 0,
        level: 1,
        gold: 0,
        currentPhase: 0,
      );
    },
    (p) => p,
  );

  final achievements = achievementCatalog
      .map((a) => a.copyWith(unlocked: progress.xp >= a.xpRequired))
      .toList();

  return ProfileData(
    displayName: user.displayName ?? user.email.split('@').first,
    email: user.email,
    photoUrl: user.photoUrl,
    progress: progress,
    achievements: achievements,
  );
});