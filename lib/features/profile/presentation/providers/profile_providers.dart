import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/infrastructure/supabase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/domain/entities/level_utils.dart';
import '../../../progress/domain/entities/user_progress.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../data/repositories/achievements_repository_impl.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/classmate_profile.dart';
import '../../domain/repositories/achievements_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DTO: dados já prontos para a view consumir, sem lógica de negócio nos widgets
// ─────────────────────────────────────────────────────────────────────────────

class ProfileData {
  const ProfileData({
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.progress,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
  final UserProgress progress;

  // ── Lógica de nível ──────────────────────────────────────────────────────
  // Usa a curva polinomial definida em level_utils.dart:
  //   XP para avançar do nível N = floor(80 × N^1.5)

  /// XP necessário para avançar do nível atual para o próximo.
  int get xpForCurrentLevel => xpRequiredForLevel(progress.level);

  /// Quanto XP o usuário já acumulou DENTRO do nível atual.
  double get xpIntoLevel {
    final xpAtLevelStart = totalXpForLevel(progress.level);
    return (progress.xp - xpAtLevelStart).clamp(
      0,
      xpForCurrentLevel.toDouble(),
    );
  }

  /// Progresso percentual dentro do nível atual (0.0 a 1.0).
  double get levelProgress =>
      (xpIntoLevel / xpForCurrentLevel).clamp(0.0, 1.0);
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

  return ProfileData(
    displayName: user.displayName ?? user.email.split('@').first,
    email: user.email,
    photoUrl: user.photoUrl,
    progress: progress,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Conquistas
// ─────────────────────────────────────────────────────────────────────────────

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  return AchievementsRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(loggerProvider),
  );
});

/// Conquistas de XP calculadas no app (o XP já está no perfil).
List<Achievement> xpAchievementsFor(double xp) => [
      for (final a in achievementCatalog)
        if (a.byXp)
          a.copyWith(unlocked: xp >= a.xpRequired, progress: xp.floor()),
    ];

/// Conquistas do aluno com o progresso de cada uma — só no perfil aberto
/// pela turma (é ali que aparecem). Se o servidor falhar, mostra só as de
/// XP com [MyAchievements.partial] (a tela avisa): as por tipo nunca
/// aparecem como "bloqueadas" sem o servidor ter conferido.
final myAchievementsProvider =
    FutureProvider.autoDispose<MyAchievements>((ref) async {
  final result =
      await ref.watch(achievementsRepositoryProvider).getMyAchievements();
  final mine = result.fold(
    (failure) {
      ref.read(loggerProvider).w('my_achievements falhou: ${failure.message}');
      return null;
    },
    (m) => m,
  );
  if (mine == null) {
    final profile = await ref.watch(profileProvider.future);
    return MyAchievements(
      achievements: xpAchievementsFor(profile.progress.xp),
      partial: true,
    );
  }
  // A leitura liberou conquistas de tentativas antigas: relê o saldo.
  if (mine.goldAwarded > 0) ref.invalidate(profileProvider);
  return mine;
});

/// Perfil de um colega, aberto pelo ranking da turma.
final classmateProfileProvider = FutureProvider.autoDispose
    .family<ClassmateProfile?, ({String classroomId, String studentId})>(
        (ref, key) async {
  final result =
      await ref.watch(achievementsRepositoryProvider).getClassmateProfile(
            classroomId: key.classroomId,
            studentId: key.studentId,
          );
  return result.fold(
    (failure) => throw FailureException(failure),
    (profile) => profile,
  );
});