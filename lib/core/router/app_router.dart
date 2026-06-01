import 'package:arcangel_o_oficial/features/settings/presentation/pages/account_page.dart';
import 'package:arcangel_o_oficial/features/settings/presentation/pages/preferences_page.dart';
import 'package:arcangel_o_oficial/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/google_complete_profile_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/role_selection_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/login_controller.dart';
import '../../features/classroom/domain/entities/classroom.dart';
import '../../features/classroom/domain/entities/classroom_phase.dart';
import '../../features/classroom/presentation/pages/classroom_lesson_page.dart';
import '../../features/classroom/presentation/pages/classroom_trail_page.dart';
import '../../features/ia_quiz/domain/entities/ia_generation_result.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/subject/presentation/pages/subject_choice_page.dart';
import '../../features/teacher/presentation/pages/classroom_list_page.dart';
import '../../features/teacher/presentation/pages/create_quiz_page.dart';
import '../../features/teacher/presentation/pages/customize_quiz_page.dart';
import '../../features/teacher/presentation/pages/ia_quiz_page.dart';
import '../../features/teacher/presentation/pages/ia_quiz_review_page.dart';
import '../../features/teacher/presentation/pages/student_dashboard_page.dart';
import '../../features/teacher/presentation/pages/teacher_account_page.dart';
import '../../features/teacher/presentation/pages/teacher_page.dart';
import '../../features/teacher/presentation/pages/teacher_preferences_page.dart';
import '../../features/teacher/presentation/pages/teacher_settings_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String subjects = '/subjects';
  static const String teacher = '/teacher';
  static const String teacherCreateQuiz = '/teacher/create-quiz';
  static const String teacherCustomizeQuiz = '/teacher/customize-quiz';
  static const String teacherIaQuiz = '/teacher/ia-quiz';
  static const String teacherIaQuizReview = '/teacher/ia-quiz/review';
  static const String teacherClassroom        = '/teacher/classroom';
  static const String teacherStudentDashboard = '/teacher/student-dashboard';
  static const String teacherSettings = '/teacher/settings';
  static const String teacherSettingsPreferences = '/teacher/settings/preferences';
  static const String teacherAccount = '/teacher/account';
  static const String profile = '/profile';
  static const String roleSelection = '/';
  static const String settings = '/settings';
  static const String classroomTrail = '/classroom/:classroomId';
  static const String classroomLesson = '/classroom/:classroomId/phase/:phaseId';
  static const String preferencesRelative = 'preferences';
  static const String preferences = '$settings/$preferencesRelative';
  static const String account = '/account';
  static const String googleCompleteProfile = '/google-complete-profile';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static String classroomTrailPath(String classroomId) => '/classroom/$classroomId';
  static String classroomLessonPath(String classroomId, String phaseId) =>
      '/classroom/$classroomId/phase/$phaseId';
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

      // 2. Logado → verifica se é novo usuário Google (precisa completar perfil).
      final isGoogleNewUser = ref.read(googleNewUserProvider);
      if (isGoogleNewUser) {
        return loc == AppRoutes.googleCompleteProfile
            ? null
            : AppRoutes.googleCompleteProfile;
      }

      // 3. Logado → verifica role.
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
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CreateQuizPage(
                classroomId: extra?['classroomId'] as String?,
                phaseId: extra?['phaseId'] as String?,
                phaseTitle: extra?['phaseTitle'] as String?,
                subject: extra?['subject'] as String?,
              );
            },
          ),
          GoRoute(
            path: 'customize-quiz',
            builder: (_, state) {
              final extra = state.extra! as Map<String, dynamic>;
              return CustomizeQuizPage(
                quantity: extra['quantity'] as int,
                topic: extra['topic'] as String,
                difficulty: extra['difficulty'] as String,
                classroomId: extra['classroomId'] as String?,
                phaseId: extra['phaseId'] as String?,
                phaseTitle: extra['phaseTitle'] as String?,
              );
            },
          ),
          GoRoute(
            path: 'ia-quiz',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return IaQuizPage(
                classroomId: extra?['classroomId'] as String?,
                phaseId: extra?['phaseId'] as String?,
                phaseTitle: extra?['phaseTitle'] as String?,
                subject: extra?['subject'] as String?,
              );
            },
            routes: [
              GoRoute(
                path: 'review',
                builder: (_, state) {
                  final extra = state.extra! as Map<String, dynamic>;
                  return IaQuizReviewPage(
                    result: extra['result'] as IaGenerationResult,
                    topic: extra['topic'] as String,
                    difficulty: extra['difficulty'] as String,
                    classroomId: extra['classroomId'] as String?,
                    phaseId: extra['phaseId'] as String?,
                    phaseTitle: extra['phaseTitle'] as String?,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: 'classroom',
            builder: (_, __) => const ClassroomListPage(),
          ),
          GoRoute(
            path: 'student-dashboard',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return StudentDashboardPage(
                initialClassroomId: extra?['classroomId'] as String?,
              );
            },
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const TeacherSettingsPage(),
            routes: [
              GoRoute(
                path: 'preferences',
                builder: (_, __) => const TeacherPreferencesPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'account',
            builder: (_, __) => const TeacherAccountPage(),
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
        routes: [
          GoRoute(
            path: AppRoutes.preferencesRelative,
            builder: (_, __) => const PreferencesPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (_, __) => const AccountPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.googleCompleteProfile,
        builder: (_, __) => const GoogleCompleteProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.classroomTrail,
        builder: (_, state) {
          final classroomId = state.pathParameters['classroomId']!;
          // `extra` pode ser null quando o GoRouter reconstrói a rota após
          // uma mudança de auth (ex.: troca de nome nas configurações).
          // Nesse caso, ClassroomTrailPage carrega o classroom via provider.
          final classroom = state.extra as Classroom?;
          return ClassroomTrailPage(
            classroomId: classroomId,
            classroom: classroom,
          );
        },
        routes: [
          GoRoute(
            path: 'phase/:phaseId',
            builder: (_, state) {
              final extra = state.extra! as Map<String, dynamic>;
              return ClassroomLessonPage(
                classroom: extra['classroom'] as Classroom,
                phase: extra['phase'] as ClassroomPhase,
              );
            },
          ),
        ],
      ),
    ],
  );
});

/// Bridge entre Riverpod e GoRouter.
///
/// Observa três providers e dispara `notifyListeners` em qualquer mudança:
/// 1. `authStateProvider` — login/logout/registro.
///    Quando muda, INVALIDA `currentUserRoleProvider` para forçar o
///    refetch do role do novo usuário (ou limpar o cache no logout).
/// 2. `currentUserRoleProvider` — após o refetch terminar, dispara o
///    redirect de novo (agora com o role conhecido, o gate decide).
/// 3. `googleNewUserProvider` — quando o usuário Google conclui o perfil
///    (flag vai de true → false), o router re-avalia e redireciona para
///    a `RoleSelectionPage`.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _authSub = ref.listen(authStateProvider, (_, __) {
      ref.invalidate(currentUserRoleProvider);
      notifyListeners();
    });
    _roleSub = ref.listen(currentUserRoleProvider, (_, __) {
      notifyListeners();
    });
    _googleNewUserSub = ref.listen(googleNewUserProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<dynamic> _authSub;
  late final ProviderSubscription<dynamic> _roleSub;
  late final ProviderSubscription<dynamic> _googleNewUserSub;

  @override
  void dispose() {
    _authSub.close();
    _roleSub.close();
    _googleNewUserSub.close();
    super.dispose();
  }
}
