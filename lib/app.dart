import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
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
    );
  }
}
