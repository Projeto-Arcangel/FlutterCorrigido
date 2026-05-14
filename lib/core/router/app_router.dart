import 'package:arcangel_o_oficial/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/role_selection_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/login_controller.dart';
import '../../features/lesson/presentation/pages/lesson_list_page.dart';
import '../../features/lesson/presentation/pages/lesson_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/subject/presentation/pages/subject_choice_page.dart';
import '../../features/teacher/presentation/pages/create_quiz_page.dart';
import '../../features/teacher/presentation/pages/ia_quiz_page.dart';
import '../../features/teacher/presentation/pages/teacher_page.dart';


class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String subjects = '/subjects';
  static const String teacher = '/teacher';
  static const String teacherCreateQuiz = '/teacher/create-quiz';
  static const String teacherIaQuiz = '/teacher/ia-quiz';
  static const String lessons = '/lessons';
  static const String lesson = '/lessons/:id';
  static const String profile = '/profile';
  static const String roleSelection = '/';
  static const String settings = '/settings';

  static String lessonPath(String id) => '/lessons/$id';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  // Rotas que NÃO exigem autenticação (telas de pré-login).
  // A roleSelection é tratada à parte porque exige usuário logado.
  const unauthRoutes = <String>{
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
  };

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = ref.read(authStateProvider).valueOrNull;
      final isLoggedIn = user != null;
      final loc = state.matchedLocation;
      final isUnauthRoute = unauthRoutes.contains(loc);

      // 1. Não logado → manda para login (a menos que já esteja numa
      //    rota pública como register/forgot-password).
      if (!isLoggedIn) {
        return isUnauthRoute ? null : AppRoutes.login;
      }

      // 2. Logado → verifica role.
      final roleAsync = ref.read(currentUserRoleProvider);

      // 2a. Role ainda carregando: NÃO redireciona — evita flicker.
      //     O _AuthRefreshNotifier vai re-disparar quando o fetch terminar.
      if (roleAsync.isLoading) return null;

      final role = roleAsync.valueOrNull;

      // 2b. Logado sem role → força roleSelection.
      if (role == null) {
        return loc == AppRoutes.roleSelection ? null : AppRoutes.roleSelection;
      }

      // 2c. Logado com role e ainda em tela de pré-login / roleSelection
      //     → entra no app, separando professores de alunos.
      if (isUnauthRoute || loc == AppRoutes.roleSelection) {
        return role == UserRole.teacher
            ? AppRoutes.teacher
            : AppRoutes.subjects;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (_, __) => const RoleSelectionPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.subjects,
        builder: (_, __) => const SubjectChoicePage(),
      ),
      GoRoute(
        path: AppRoutes.teacher,
        builder: (_, __) => const TeacherPage(),
        routes: [
          GoRoute(
            path: 'create-quiz',
            builder: (_, __) => const CreateQuizPage(),
          ),
          GoRoute(
            path: 'ia-quiz',
            builder: (_, __) => const IaQuizPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
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

/// Bridge entre Riverpod e GoRouter.
///
/// Observa dois providers e dispara `notifyListeners` em qualquer mudança:
/// 1. `authStateProvider` — login/logout/registro.
///    Quando muda, INVALIDA `currentUserRoleProvider` para forçar o
///    refetch do role do novo usuário (ou limpar o cache no logout).
/// 2. `currentUserRoleProvider` — após o refetch terminar, dispara o
///    redirect de novo (agora com o role conhecido, o gate decide).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, __) {
      ref.invalidate(currentUserRoleProvider);
      notifyListeners();
    });
    _roleSub = ref.listen(currentUserRoleProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<dynamic> _authSub;
  late final ProviderSubscription<dynamic> _roleSub;

  @override
  void dispose() {
    _authSub.close();
    _roleSub.close();
    super.dispose();
  }
}