import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory UserProgressModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data()! as Map<String, dynamic>;
    return UserProgressModel(
      userId: snap.id,
      xp: (data['xp'] as num?)?.toDouble() ?? 0.0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      gold: (data['gold'] as num?)?.toInt() ?? 0,
      currentPhase: (data['faseAtual'] as num?)?.toInt() ?? 0,
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      lastLoginDate: (data['lastLoginDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'xp': xp,
        'level': level,
        'gold': gold,
        'faseAtual': currentPhase,
        'streak': streak,
        if (lastLoginDate != null)
          'lastLoginDate': Timestamp.fromDate(lastLoginDate!),
      };
}