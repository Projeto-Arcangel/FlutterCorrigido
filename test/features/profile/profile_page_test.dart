import 'package:arcangel_o_oficial/features/profile/domain/entities/achievement.dart';
import 'package:arcangel_o_oficial/features/profile/domain/entities/classmate_profile.dart';
import 'package:arcangel_o_oficial/features/profile/presentation/pages/profile_page.dart';
import 'package:arcangel_o_oficial/features/profile/presentation/providers/profile_providers.dart';
import 'package:arcangel_o_oficial/features/progress/domain/entities/user_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fora da turma (rota `/profile`) o aluno vê só os dados da conta; nível,
/// XP, moedas e conquistas aparecem no perfil aberto de dentro de uma turma.
void main() {
  const profile = ProfileData(
    displayName: 'Ana Souza',
    email: 'ana@escola.com',
    photoUrl: null,
    progress: UserProgress(
      userId: 'u1',
      xp: 150,
      level: 3,
      gold: 42,
      currentPhase: 2,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool showProgress,
    MyAchievements? mine,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => profile),
          myAchievementsProvider.overrideWith(
            (ref) async => mine ?? MyAchievements(achievements: xpAchievementsFor(150)),
          ),
        ],
        child: MaterialApp(home: ProfilePage(showProgress: showProgress)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fora da turma: só os dados da conta', (tester) async {
    await pump(tester, showProgress: false);

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana@escola.com'), findsOneWidget);
    expect(find.byTooltip('Configurações'), findsOneWidget);
    expect(find.text('Nv. 3'), findsNothing);
    expect(find.text('XP Total'), findsNothing);
    expect(find.text('Moedas'), findsNothing);
    expect(find.text('Conquistas'), findsNothing);
    expect(
      find.textContaining('aparecem quando você abre o perfil dentro'),
      findsOneWidget,
    );
  });

  testWidgets('dentro da turma: nível, XP, moedas e conquistas',
      (tester) async {
    await pump(tester, showProgress: true);

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Nv. 3'), findsOneWidget);
    expect(find.text('XP Total'), findsOneWidget);
    expect(find.text('Moedas'), findsOneWidget);
    expect(find.text('Conquistas'), findsOneWidget);
    expect(
      find.textContaining('aparecem quando você abre o perfil dentro'),
      findsNothing,
    );
  });

  testWidgets('conquistas do servidor: liberadas e quanto falta',
      (tester) async {
    final electrician = achievementCatalog.firstWhere((a) => a.id == 'electrician');
    final organized = achievementCatalog.firstWhere((a) => a.id == 'organized');
    await pump(
      tester,
      showProgress: true,
      mine: MyAchievements(
        achievements: [
          ...xpAchievementsFor(150),
          electrician.copyWith(unlocked: true, progress: 5),
          organized.copyWith(progress: 3),
        ],
      ),
    );

    expect(find.text('2 / 8'), findsOneWidget); // Primeiro Passo + Eletricista
    expect(find.text('Eletricista'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget); // Organizado
    expect(find.text('150/200'), findsOneWidget); // Estudante, pelo XP
    expect(find.textContaining('não carregaram'), findsNothing);
  });

  testWidgets('servidor fora: só as de XP, com aviso', (tester) async {
    await pump(
      tester,
      showProgress: true,
      mine: MyAchievements(achievements: xpAchievementsFor(150), partial: true),
    );

    expect(find.textContaining('não carregaram agora'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('Eletricista'), findsNothing);
    // Sem o servidor, não mostra contagem que pareça completa.
    expect(find.text('1 / 6'), findsNothing);
  });
}
