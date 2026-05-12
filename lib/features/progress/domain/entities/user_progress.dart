import 'package:equatable/equatable.dart';

class UserProgress extends Equatable {
  final String userId;
  final double xp;
  final int level;
  final int gold;
  final int currentPhase;

  const UserProgress({
    required this.userId,
    required this.xp,
    required this.level,
    required this.gold,
    required this.currentPhase,
  });

  @override
  List<Object?> get props => [userId, xp, level, gold, currentPhase];
}