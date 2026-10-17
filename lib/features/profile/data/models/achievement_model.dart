import '../../domain/entities/achievement.dart';
import '../../domain/entities/classmate_profile.dart';

/// Converte o JSON das RPCs `my_achievements` e `get_classmate_profile`.
abstract final class AchievementModel {
  /// [unlockedByDefault]: a lista do colega só traz as liberadas (sem a
  /// chave `unlocked`); a do aluno sempre traz a chave.
  static Achievement fromMap(
    Map<String, dynamic> map, {
    bool unlockedByDefault = false,
  }) {
    final id = map['id'].toString();
    final criterion = (map['criterion'] as String?) ?? Achievement.xpCriterion;
    final goal = map['goal'] == null ? null : _int(map['goal']);
    final catalog = _catalog(id);
    return Achievement(
      id: id,
      title: (map['title'] as String?) ?? catalog?.title ?? id,
      description:
          (map['description'] as String?) ?? catalog?.description ?? '',
      icon: achievementIcon(id, map['icon'] as String?),
      rarity: _rarity(map['rarity']),
      // No critério de XP a meta do servidor é o próprio XP exigido.
      xpRequired: criterion == Achievement.xpCriterion
          ? (goal ?? catalog?.xpRequired.toInt() ?? 0).toDouble()
          : 0,
      criterion: criterion,
      goal: criterion == Achievement.xpCriterion ? null : goal,
      goldReward: _int(map['gold_reward']),
      progress: map['progress'] == null ? null : _int(map['progress']),
      unlocked: (map['unlocked'] as bool?) ?? unlockedByDefault,
    );
  }

  static MyAchievements mine(Map<String, dynamic> map) => MyAchievements(
        achievements: _maps(map['achievements']).map(fromMap).toList(),
        goldAwarded: _int(map['gold_awarded']),
      );

  static ClassmateProfile classmate(Map<String, dynamic> map) =>
      ClassmateProfile(
        userId: map['user_id'].toString(),
        name: (map['name'] as String?) ?? '',
        photoUrl: map['photo_url'] as String?,
        level: _int(map['level'], 1),
        xp: _int(map['xp']),
        stars: _int(map['stars']),
        phasesDone: _int(map['phases_done']),
        achievements: [
          for (final a in _maps(map['achievements']))
            fromMap(a, unlockedByDefault: true),
        ],
        achievementsTotal: _int(map['achievements_total']),
      );

  static Achievement? _catalog(String id) {
    for (final a in achievementCatalog) {
      if (a.id == id) return a;
    }
    return null;
  }

  static AchievementRarity _rarity(Object? raw) {
    for (final r in AchievementRarity.values) {
      if (r.name == raw) return r;
    }
    return AchievementRarity.bronze;
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => [
        for (final e in (raw as List?) ?? const [])
          if (e is Map) Map<String, dynamic>.from(e),
      ];

  static int _int(Object? raw, [int fallback = 0]) => switch (raw) {
        final num n => n.toInt(),
        final String s => num.tryParse(s)?.toInt() ?? fallback,
        _ => fallback,
      };
}
