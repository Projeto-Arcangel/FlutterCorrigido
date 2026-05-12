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

  static const List<Subject> all = [
    Subject(
      id: SubjectId.history,
      name: 'História',
      unlocked: true,
      color: AppColors.subjectHistory,
      lockColor: AppColors.lockOnPhilosophy, // não usado quando unlocked
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

  @override
  List<Object?> get props => [id, name, unlocked, color, lockColor];
}