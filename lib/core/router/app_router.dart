import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/login_controller.dart';
import '../../features/lesson/presentation/pages/lesson_list_page.dart';
import '../../features/lesson/presentation/pages/lesson_page.dart';
import '../../features/subject/presentation/pages/subject_choice_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String subjects = '/subjects';
  static const String lessons = '/lessons';
  static const String lesson = '/lessons/:id';
  static const String profile = '/profile';
  

  static String lessonPath(String id) => '/lessons/$id';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
      final location = state.matchedLocation;

      final isPublic = location == AppRoutes.login || location == AppRoutes.register ||
      location == AppRoutes.forgotPassword;

      if (!isLoggedIn && !isPublic) return AppRoutes.login;
      if (isLoggedIn && location == AppRoutes.login) return AppRoutes.subjects;
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
    path: AppRoutes.profile,
    builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
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