import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum SubjectId { history, philosophy, sociology, geography }

class Subject extends Equatable {
  final SubjectId id;
  final String name;
  final bool unlocked;
  final Color color;
  final Color lockColor;

  const Subject({
    required this.id,
    required this.name,
    required this.unlocked,
    required this.color,
    required this.lockColor,
  });

  // Catálogo base — unlocked sempre false aqui.
  // Quem decide o desbloqueio real é o subjectsProvider via XP do usuário.
  static const List<Subject> catalog = [
    Subject(
      id: SubjectId.history,
      name: 'História',
      unlocked: false, // será sobrescrito pelo provider
      color: AppColors.subjectHistory,
      lockColor: AppColors.lockOnPhilosophy,
    ),
    Subject(
      id: SubjectId.philosophy,
      name: 'Filosofia',
      unlocked: false,
      color: AppColors.subjectPhilosophy,
      lockColor: AppColors.lockOnPhilosophy,
    ),
    Subject(
      id: SubjectId.sociology,
      name: 'Sociologia',
      unlocked: false,
      color: AppColors.subjectSociology,
      lockColor: AppColors.lockOnSociology,
    ),
    Subject(
      id: SubjectId.geography,
      name: 'Geografia',
      unlocked: false,
      color: AppColors.subjectGeography,
      lockColor: AppColors.lockOnGeography,
    ),
  ];

  Subject copyWith({bool? unlocked}) {
    return Subject(
      id: id,
      name: name,
      unlocked: unlocked ?? this.unlocked,
      color: color,
      lockColor: lockColor,
    );
  }

  @override
  List<Object?> get props => [id, name, unlocked, color, lockColor];
}