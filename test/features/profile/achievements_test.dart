import 'package:arcangel_o_oficial/features/classroom/data/models/phase_attempt_model.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_attempt.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/widgets/classmate_profile_sheet.dart';
import 'package:arcangel_o_oficial/features/profile/data/models/achievement_model.dart';
import 'package:arcangel_o_oficial/features/profile/domain/entities/achievement.dart';
import 'package:arcangel_o_oficial/features/profile/domain/entities/classmate_profile.dart';
import 'package:arcangel_o_oficial/features/profile/presentation/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JSON das conquistas', () {
    test('my_achievements: progresso, meta, moedas e ícone', () {
      final mine = AchievementModel.mine({
        'gold_awarded': 10,
        'achievements': [
          {
            'id': 'first_step',
            'title': 'Primeiro Passo',
            'description': 'Ganhe 50 XP',
            'rarity': 'bronze',
            'icon': 'bolt',
            'criterion': 'xp',
            'gold_reward': 0,
            'progress': 19,
            'goal': 50,
            'unlocked': false,
          },
          {
            'id': 'organized',
            'title': 'Organizado',
            'description': 'Ordene sem erro 5 questões',
            'rarity': 'silver',
            'icon': 'format_list',
            'criterion': 'ordering_perfect',
            'gold_reward': 10,
            'progress': 2,
            'goal': 5,
            'unlocked': false,
          },
          {
            'id': 'three_stars',
            'title': 'Três estrelas',
            'description': 'Tire 3 estrelas numa fase',
            'rarity': 'gold',
            'icon': 'stars',
            'criterion': 'three_stars',
            'gold_reward': 10,
            'progress': 1,
            'goal': 1,
            'unlocked': true,
          },
          {
            // Conquista nova no banco que o app ainda não conhece.
            'id': 'nova', 'title': 'Nova', 'description': '',
            'rarity': 'diamante',
            'icon': 'desconhecido', 'criterion': 'outra', 'progress': '4',
            'goal': 9,
          },
        ],
      });
      expect(mine.goldAwarded, 10);
      expect(mine.partial, isFalse);
      expect(mine.unlockedCount, 1);

      final [xp, organized, stars, nova] = mine.achievements;
      expect(xp.byXp, isTrue);
      expect(xp.xpRequired, 50);
      expect(xp.progressLabel, '19/50');
      expect(organized.goal, 5);
      expect(organized.goldReward, 10);
      expect(organized.icon, Icons.format_list_numbered_rounded);
      expect(organized.progressLabel, '2/5');
      expect(stars.unlocked, isTrue);
      expect(stars.progressLabel, isNull);
      expect(nova.icon, Icons.emoji_events_rounded);
      expect(nova.rarity, AchievementRarity.bronze);
      expect(nova.progressLabel, '4/9');
    });

    test('perfil do colega: só liberadas, sem e-mail', () {
      final p = AchievementModel.classmate({
        'user_id': 'u2',
        'name': 'Bia',
        'photo_url': null,
        'level': 3,
        'xp': 120,
        'stars': 7,
        'phases_done': 3,
        'achievements_total': 13,
        'achievements': [
          {
            'id': 'electrician',
            'title': 'Eletricista',
            'description': 'x',
            'rarity': 'silver',
            'icon': 'cable',
          },
        ],
      });
      expect(p.name, 'Bia');
      expect(p.stars, 7);
      expect(p.achievements.single.unlocked, isTrue);
      expect(p.achievements.single.icon, Icons.cable_rounded);
    });

    test('resultado da tentativa traz as conquistas da entrega', () {
      final r = AttemptJson.result({
        'attempt_id': 'a1',
        'attempt_no': 1,
        'first_attempt': true,
        'total': 1,
        'score': 1,
        'pct': 100,
        'stars': 3,
        'points': 10,
        'best_streak': 1,
        'xp': 7,
        'gold': 15,
        'best_pct': 100,
        'best_stars': 3,
        'achievements': [
          {'id': 'three_stars', 'title': 'Três estrelas', 'gold': 10},
        ],
      });
      expect(r.achievements, const [
        UnlockedAchievement(
          id: 'three_stars',
          title: 'Três estrelas',
          gold: 10,
        ),
      ]);
      expect(AttemptJson.result({'attempt_id': 'a2'}).achievements, isEmpty);
    });

    test('sem servidor: conquistas de XP pelo XP', () {
      final list = xpAchievementsFor(250);
      expect(list.length, 6);
      expect(
        list.where((a) => a.unlocked).map((a) => a.id),
        ['first_step', 'scholar'],
      );
      expect(list[2].progressLabel, '250/500');
    });
  });

  group('perfil do colega pelo ranking', () {
    const key = (classroomId: 'c1', studentId: 'u2');

    Future<void> pump(
      WidgetTester tester,
      Future<ClassmateProfile?> Function() load,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classmateProfileProvider(key).overrideWith((ref) => load()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ClassmateProfileSheet(
                classroomId: 'c1',
                studentId: 'u2',
                name: 'Bia',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra nível, estrelas, fases e conquistas', (tester) async {
      final electrician =
          achievementCatalog.firstWhere((a) => a.id == 'electrician');
      await pump(
        tester,
        () async => ClassmateProfile(
          userId: 'u2',
          name: 'Bia',
          level: 3,
          xp: 120,
          stars: 7,
          phasesDone: 3,
          achievements: [electrician.copyWith(unlocked: true)],
          achievementsTotal: 13,
        ),
      );
      expect(find.text('Bia'), findsOneWidget);
      expect(find.text('Nv. 3'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Estrelas na turma'), findsOneWidget);
      expect(find.text('Fases feitas'), findsOneWidget);
      expect(find.text('1 / 13'), findsOneWidget);
      expect(find.text('Eletricista'), findsOneWidget);
      expect(find.byIcon(Icons.cable_rounded), findsOneWidget);
    });

    testWidgets('sem conquistas ainda', (tester) async {
      await pump(
        tester,
        () async => const ClassmateProfile(
          userId: 'u2',
          name: 'Bia',
          level: 1,
          xp: 0,
          stars: 0,
          phasesDone: 1,
          achievements: [],
          achievementsTotal: 13,
        ),
      );
      expect(find.text('Ainda não liberou nenhuma conquista.'), findsOneWidget);
      expect(find.text('Fase feita'), findsOneWidget);
    });

    testWidgets('sem acesso: avisa e mostra o nome do ranking', (tester) async {
      await pump(tester, () async => null);
      expect(find.text('Este perfil não está disponível.'), findsOneWidget);
      expect(find.text('Bia'), findsOneWidget);
    });

    testWidgets('tocar fora da folha fecha o perfil', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classmateProfileProvider(key).overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showClassmateProfile(
                      context,
                      classroomId: 'c1',
                      studentId: 'u2',
                      name: 'Bia',
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Este perfil não está disponível.'), findsOneWidget);

      await tester.tapAt(const Offset(400, 20)); // fundo escurecido, acima
      await tester.pumpAndSettle();
      expect(find.text('Este perfil não está disponível.'), findsNothing);
    });
  });
}
