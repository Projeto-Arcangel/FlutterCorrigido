import 'package:equatable/equatable.dart';

import 'achievement.dart';

/// Perfil de um colega, aberto pelo ranking da turma (RPC
/// `get_classmate_profile`). Só o que é da turma e do jogo — nunca e-mail,
/// prontuário ou moedas.
class ClassmateProfile extends Equatable {
  const ClassmateProfile({
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.level,
    required this.xp,
    required this.stars,
    required this.phasesDone,
    required this.achievements,
    required this.achievementsTotal,
  });

  final String userId;
  final String name;
  final String? photoUrl;
  final int level;
  final int xp;

  /// Estrelas somadas nas fases desta turma.
  final int stars;

  /// Fases desta turma já entregues.
  final int phasesDone;

  /// Só as conquistas liberadas.
  final List<Achievement> achievements;
  final int achievementsTotal;

  @override
  List<Object?> get props => [
        userId,
        name,
        photoUrl,
        level,
        xp,
        stars,
        phasesDone,
        achievements,
        achievementsTotal,
      ];
}

/// Conquistas do aluno logado ([achievements]) e as moedas que a leitura
/// acabou de creditar ([goldAwarded], conquistas de tentativas antigas).
/// [partial]: o servidor não respondeu e só as de XP foram calculadas no app.
class MyAchievements extends Equatable {
  const MyAchievements({
    required this.achievements,
    this.goldAwarded = 0,
    this.partial = false,
  });

  final List<Achievement> achievements;
  final int goldAwarded;
  final bool partial;

  int get unlockedCount => achievements.where((a) => a.unlocked).length;

  @override
  List<Object?> get props => [achievements, goldAwarded, partial];
}
