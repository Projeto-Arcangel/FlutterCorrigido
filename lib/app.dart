import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/reduced_motion.dart';
import 'features/ia_quiz/presentation/widgets/ia_generation_watcher.dart';
import 'features/settings/presentation/pages/preferences_page.dart';

class ArcangelApp extends ConsumerWidget {
  const ArcangelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(preferencesProvider);

    return MaterialApp.router(
      title: 'Arcangel',
      debugShowCheckedModeBanner: false,
      themeMode: prefs.lightMode ? ThemeMode.light : ThemeMode.dark,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      // "Reduzir movimento" do navegador vale para o app todo: as telas já
      // consultam MediaQuery.disableAnimations, que o Flutter web não liga
      // sozinho a partir do prefers-reduced-motion.
      builder: (context, child) {
        // Avisa quando questões geradas com IA ficam prontas com o professor
        // já em outra tela.
        final page = IaGenerationWatcher(
          child: child ?? const SizedBox.shrink(),
        );
        if (!browserPrefersReducedMotion()) return page;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: page,
        );
      },
    );
  }
}
