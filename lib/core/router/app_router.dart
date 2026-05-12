import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/login_controller.dart';
import '../../features/lesson/presentation/pages/lesson_list_page.dart';
import '../../features/lesson/presentation/pages/lesson_page.dart';
import '../../features/subject/presentation/pages/subject_choice_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String subjects = '/subjects';
  static const String lessons = '/lessons';
  static const String lesson = '/lessons/:id';

  static String lessonPath(String id) => '/lessons/$id';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoginRoute) return AppRoutes.login;
      if (isLoggedIn && isLoginRoute) return AppRoutes.subjects;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.subjects,
        builder: (_, __) => const SubjectChoicePage(),
      ),
      GoRoute(
        path: AppRoutes.lessons,
        builder: (_, __) => const LessonListPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                LessonPage(lessonId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
});

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _subscription = ref.listen(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}