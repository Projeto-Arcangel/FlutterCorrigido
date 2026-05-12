import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum
// ─────────────────────────────────────────────────────────────────────────────

enum AchievementRarity { bronze, silver, gold, platinum }

// ─────────────────────────────────────────────────────────────────────────────
// Entity
// ─────────────────────────────────────────────────────────────────────────────

class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.xpRequired,
    this.unlocked = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementRarity rarity;

  /// XP mínimo necessário para desbloquear esta conquista.
  final double xpRequired;
  final bool unlocked;

  Achievement copyWith({bool? unlocked}) => Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        rarity: rarity,
        xpRequired: xpRequired,
        unlocked: unlocked ?? this.unlocked,
      );

  @override
  List<Object?> get props => [id, unlocked];
}

// ─────────────────────────────────────────────────────────────────────────────
// Catálogo estático — fonte única de verdade para conquistas baseadas em XP.
// Quando houver persistência no Firestore, este catálogo servirá como fallback
// e template para a coleção remota.
// ─────────────────────────────────────────────────────────────────────────────

const List<Achievement> achievementCatalog = [
  Achievement(
    id: 'first_step',
    title: 'Primeiro Passo',
    description: 'Ganhe seus primeiros 50 XP',
    icon: Icons.bolt_rounded,
    rarity: AchievementRarity.bronze,
    xpRequired: 50,
  ),
  Achievement(
    id: 'scholar',
    title: 'Estudante',
    description: 'Alcance 200 XP',
    icon: Icons.menu_book_rounded,
    rarity: AchievementRarity.bronze,
    xpRequired: 200,
  ),
  Achievement(
    id: 'dedicated',
    title: 'Dedicado',
    description: 'Alcance 500 XP',
    icon: Icons.star_rounded,
    rarity: AchievementRarity.silver,
    xpRequired: 500,
  ),
  Achievement(
    id: 'historian',
    title: 'Historiador',
    description: 'Alcance 1 000 XP',
    icon: Icons.auto_stories_rounded,
    rarity: AchievementRarity.silver,
    xpRequired: 1000,
  ),
  Achievement(
    id: 'sage',
    title: 'Sábio',
    description: 'Alcance 2 500 XP',
    icon: FontAwesomeIcons.hatWizard,
    rarity: AchievementRarity.gold,
    xpRequired: 2500,
  ),
  Achievement(
    id: 'legend',
    title: 'Lenda',
    description: 'Alcance 5 000 XP',
    icon: FontAwesomeIcons.trophy,
    rarity: AchievementRarity.platinum,
    xpRequired: 5000,
  ),
];