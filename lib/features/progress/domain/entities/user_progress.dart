import 'package:equatable/equatable.dart';

class UserProgress extends Equatable {
  final String userId;
  final double xp;
  final int level;
  final int gold;
  final int currentPhase;

  /// Sequência consecutiva de dias em que o usuário acessou o app
  /// (requisito funcional RF02.4). Reinicia para 1 quando há um gap
  /// de mais de um dia em [lastLoginDate]; incrementa quando o último
  /// acesso foi exatamente no dia anterior.
  final int streak;

  /// Último dia de acesso registrado. Persistido como Timestamp no
  /// Firestore. Usado em conjunto com [streak] para decidir se o
  /// streak deve incrementar, manter ou zerar.
  final DateTime? lastLoginDate;

  const UserProgress({
    required this.userId,
    required this.xp,
    required this.level,
    required this.gold,
    required this.currentPhase,
    this.streak = 0,
    this.lastLoginDate,
  });

  @override
  List<Object?> get props => [
        userId,
        xp,
        level,
        gold,
        currentPhase,
        streak,
        lastLoginDate,
      ];
}
