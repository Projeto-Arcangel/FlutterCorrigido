import '../../domain/entities/user_progress.dart';

class UserProgressModel extends UserProgress {
  const UserProgressModel({
    required super.userId,
    required super.xp,
    required super.level,
    required super.gold,
    required super.currentPhase,
    super.streak,
    super.lastLoginDate,
  });

  /// Constrói a partir de uma linha da tabela `user_progress` do Supabase.
  factory UserProgressModel.fromMap(Map<String, dynamic> map) {
    return UserProgressModel(
      userId: map['user_id'] as String,
      xp: _toDouble(map['xp']),
      level: _toInt(map['level'], 1),
      gold: _toInt(map['gold'], 0),
      currentPhase: _toInt(map['current_phase'], 1),
      streak: _toInt(map['streak'], 0),
      lastLoginDate: map['last_login_date'] == null
          ? null
          : DateTime.tryParse(map['last_login_date'].toString()),
    );
  }

  // Postgres `numeric` pode chegar como num ou String — normalizamos aqui.
  static double _toDouble(dynamic v) => v == null
      ? 0.0
      : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  static int _toInt(dynamic v, int fallback) => v == null
      ? fallback
      : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? fallback);
}
