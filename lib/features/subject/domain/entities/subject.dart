import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Identificadores únicos de cada matéria do Ensino Médio.
/// Agrupa as 11 disciplinas da BNCC divididas por áreas do conhecimento.
enum SubjectId {
  // ── Linguagens e suas Tecnologias ──
  portuguese,
  arts,
  physEd,

  // ── Ciências Humanas e Sociais Aplicadas ──
  history,
  geography,
  philosophy,
  sociology,

  // ── Ciências da Natureza e suas Tecnologias ──
  biology,
  chemistry,
  physics,

  // ── Matemática e suas Tecnologias ──
  math,
}

class Subject extends Equatable {
  final SubjectId id;
  final String name;
  final String area; // Área do conhecimento (BNCC)
  final bool unlocked;
  final Color color;
  final Color lockColor;
  final bool lightText; // true → texto branco sobre o botão

  const Subject({
    required this.id,
    required this.name,
    required this.area,
    required this.unlocked,
    required this.color,
    required this.lockColor,
    this.lightText = false,
  });

  // ── Catálogo base ────────────────────────────────────────────────────────────
  // unlocked sempre false aqui; o desbloqueio real vem de subjectsProvider.
  static const List<Subject> catalog = [
    // ─ Linguagens ─
    Subject(
      id: SubjectId.portuguese,
      name: 'Português',
      area: 'Linguagens',
      unlocked: false,
      color: AppColors.subjectPortuguese,
      lockColor: AppColors.lockOnPortuguese,
      lightText: true,
    ),
    Subject(
      id: SubjectId.arts,
      name: 'Artes',
      area: 'Linguagens',
      unlocked: false,
      color: AppColors.subjectArts,
      lockColor: AppColors.lockOnArts,
      lightText: true,
    ),
    Subject(
      id: SubjectId.physEd,
      name: 'Ed. Física',
      area: 'Linguagens',
      unlocked: false,
      color: AppColors.subjectPhysEd,
      lockColor: AppColors.lockOnPhysEd,
      lightText: true,
    ),

    // ─ Humanas ─
    Subject(
      id: SubjectId.history,
      name: 'História',
      area: 'Humanas',
      unlocked: false,
      color: AppColors.subjectHistory,
      lockColor: AppColors.lockOnPhilosophy,
      lightText: true,
    ),
    Subject(
      id: SubjectId.geography,
      name: 'Geografia',
      area: 'Humanas',
      unlocked: false,
      color: AppColors.subjectGeography,
      lockColor: AppColors.lockOnGeography,
    ),
    Subject(
      id: SubjectId.philosophy,
      name: 'Filosofia',
      area: 'Humanas',
      unlocked: false,
      color: AppColors.subjectPhilosophy,
      lockColor: AppColors.lockOnPhilosophy,
    ),
    Subject(
      id: SubjectId.sociology,
      name: 'Sociologia',
      area: 'Humanas',
      unlocked: false,
      color: AppColors.subjectSociology,
      lockColor: AppColors.lockOnSociology,
    ),

    // ─ Ciências da Natureza ─
    Subject(
      id: SubjectId.biology,
      name: 'Biologia',
      area: 'Ciências',
      unlocked: false,
      color: AppColors.subjectBiology,
      lockColor: AppColors.lockOnBiology,
      lightText: true,
    ),
    Subject(
      id: SubjectId.chemistry,
      name: 'Química',
      area: 'Ciências',
      unlocked: false,
      color: AppColors.subjectChemistry,
      lockColor: AppColors.lockOnChemistry,
      lightText: true,
    ),
    Subject(
      id: SubjectId.physics,
      name: 'Física',
      area: 'Ciências',
      unlocked: false,
      color: AppColors.subjectPhysics,
      lockColor: AppColors.lockOnPhysics,
      lightText: true,
    ),

    // ─ Matemática ─
    Subject(
      id: SubjectId.math,
      name: 'Matemática',
      area: 'Matemática',
      unlocked: false,
      color: AppColors.subjectMath,
      lockColor: AppColors.lockOnMath,
    ),
  ];

  Subject copyWith({bool? unlocked}) {
    return Subject(
      id: id,
      name: name,
      area: area,
      unlocked: unlocked ?? this.unlocked,
      color: color,
      lockColor: lockColor,
      lightText: lightText,
    );
  }

  @override
  List<Object?> get props => [id, name, area, unlocked, color, lockColor, lightText];
}