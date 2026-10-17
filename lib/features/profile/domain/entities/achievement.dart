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
    this.xpRequired = 0,
    this.criterion = xpCriterion,
    this.goal,
    this.goldReward = 0,
    this.progress,
    this.unlocked = false,
  });

  /// Critério das conquistas pelo XP total (as demais contam no servidor:
  /// questões de um tipo sem erro, sequência, 3 estrelas).
  static const xpCriterion = 'xp';

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementRarity rarity;

  /// XP mínimo necessário para desbloquear (só no critério [xpCriterion]).
  final double xpRequired;

  /// O que conta (coluna `achievements.criterion`).
  final String criterion;

  /// Meta das conquistas por tipo (ex.: 5 questões de ligar sem erro).
  final int? goal;

  /// Moedas que a conquista dá ao ser liberada.
  final int goldReward;

  /// Quanto o aluno já fez (`null` = não carregou do servidor).
  final int? progress;
  final bool unlocked;

  bool get byXp => criterion == xpCriterion;

  /// Meta no mesmo número do [progress].
  int get target => byXp ? xpRequired.toInt() : (goal ?? 1);

  /// "3/5" para quem ainda não liberou (`null` sem progresso ou meta 1).
  String? get progressLabel {
    final p = progress;
    if (unlocked || p == null || target <= 1) return null;
    return '${p.clamp(0, target)}/$target';
  }

  Achievement copyWith({bool? unlocked, int? progress}) => Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        rarity: rarity,
        xpRequired: xpRequired,
        criterion: criterion,
        goal: goal,
        goldReward: goldReward,
        progress: progress ?? this.progress,
        unlocked: unlocked ?? this.unlocked,
      );

  @override
  List<Object?> get props => [id, unlocked, progress];
}

/// Ícone pelo id da conquista (catálogo) ou pelo nome gravado no banco.
IconData achievementIcon(String id, [String? iconName]) {
  for (final a in achievementCatalog) {
    if (a.id == id) return a.icon;
  }
  return switch (iconName) {
    'cable' => Icons.cable_rounded,
    'format_list' => Icons.format_list_numbered_rounded,
    'edit_note' => Icons.edit_note_rounded,
    'grid' => Icons.grid_on_rounded,
    'search' => Icons.manage_search_rounded,
    'fire' => Icons.local_fire_department_rounded,
    'stars' => Icons.stars_rounded,
    _ => Icons.emoji_events_rounded,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Catálogo estático — espelha a tabela `achievements` (migrations de seed e
// 20261018120100_type_achievements). A lista que vale vem do servidor
// (`my_achievements`); este catálogo dá os ícones e, se o servidor falhar,
// as conquistas de XP (calculadas pelo XP, que o app já tem).
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
  // Por tipo de questão e mecânica — 10 moedas cada, conferidas no servidor.
  Achievement(
    id: 'electrician',
    title: 'Eletricista',
    description: 'Ligue todos os fios certos em 5 questões',
    icon: Icons.cable_rounded,
    rarity: AchievementRarity.silver,
    criterion: 'match_perfect',
    goal: 5,
    goldReward: 10,
  ),
  Achievement(
    id: 'organized',
    title: 'Organizado',
    description: 'Ordene sem erro 5 questões',
    icon: Icons.format_list_numbered_rounded,
    rarity: AchievementRarity.silver,
    criterion: 'ordering_perfect',
    goal: 5,
    goldReward: 10,
  ),
  Achievement(
    id: 'blank_filler',
    title: 'Completa-tudo',
    description: 'Acerte todas as lacunas em 5 questões',
    icon: Icons.edit_note_rounded,
    rarity: AchievementRarity.silver,
    criterion: 'blanks_perfect',
    goal: 5,
    goldReward: 10,
  ),
  Achievement(
    id: 'cruciverbalist',
    title: 'Cruciverbalista',
    description: 'Complete 3 cruzadinhas sem erro',
    icon: Icons.grid_on_rounded,
    rarity: AchievementRarity.gold,
    criterion: 'crossword_perfect',
    goal: 3,
    goldReward: 10,
  ),
  Achievement(
    id: 'detective',
    title: 'Detetive',
    description: 'Ache todas as palavras em 3 caça-palavras',
    icon: Icons.manage_search_rounded,
    rarity: AchievementRarity.gold,
    criterion: 'word_search_perfect',
    goal: 3,
    goldReward: 10,
  ),
  Achievement(
    id: 'on_fire',
    title: 'Em chamas',
    description: 'Acerte 5 questões seguidas',
    icon: Icons.local_fire_department_rounded,
    rarity: AchievementRarity.bronze,
    criterion: 'streak',
    goal: 5,
    goldReward: 10,
  ),
  Achievement(
    id: 'three_stars',
    title: 'Três estrelas',
    description: 'Tire 3 estrelas numa fase',
    icon: Icons.stars_rounded,
    rarity: AchievementRarity.gold,
    criterion: 'three_stars',
    goal: 1,
    goldReward: 10,
  ),
];
