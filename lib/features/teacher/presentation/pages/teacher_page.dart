import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../domain/entities/teacher_dashboard_data.dart';
import '../providers/teacher_dashboard_provider.dart';
import '../widgets/teacher_content.dart';
import '../widgets/teacher_header.dart';

class TeacherPage extends ConsumerStatefulWidget {
  const TeacherPage({super.key});

  @override
  ConsumerState<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends ConsumerState<TeacherPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  static const int _kSlots = 2;
  static const Duration _kTotal = Duration(milliseconds: 700);
  static const Duration _kStagger = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kTotal);

    _fades = List.generate(_kSlots, (i) {
      final start = (i * _kStagger.inMilliseconds) / _kTotal.inMilliseconds;
      final end = (start + 0.55).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slides = _fades.map((a) {
      return Tween<Offset>(
        begin: const Offset(0, 0.14),
        end: Offset.zero,
      ).animate(a);
    }).toList();

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<TeacherQuickAction> _buildActions(String? classroomId) => [
        TeacherQuickAction(
          icon: FontAwesomeIcons.school,
          title: 'Minha Turma',
          subtitle: classroomId != null
              ? 'Ver alunos e resultados'
              : 'Nenhuma turma ainda',
          iconColor: const Color(0xFF8B72D0),
          iconBg: const Color(0x1A8B72D0),
          onTap: () => context.push(AppRoutes.teacherClassroom),
        ),
        TeacherQuickAction(
          icon: FontAwesomeIcons.penToSquare,
          title: 'Criar Questões',
          subtitle: 'Escreva suas próprias questões manualmente',
          iconColor: const Color(0xFF72D09C),
          iconBg: const Color(0x1A72D09C),
          onTap: () => context.push(AppRoutes.teacherCreateQuiz),
        ),
        TeacherQuickAction(
          icon: FontAwesomeIcons.wandMagicSparkles,
          title: 'Criar Questões com IA',
          subtitle: 'Personalizar questões por tema e dificuldade',
          iconColor: const Color(0xFF7296D0),
          iconBg: const Color(0x1A7296D0),
          onTap: () => context.push(AppRoutes.teacherIaQuiz),
        ),
        TeacherQuickAction(
          icon: FontAwesomeIcons.chartLine,
          title: 'Dashboard de Alunos',
          subtitle: 'Acompanhe a evolução da turma em tempo real',
          iconColor: const Color(0xFF72ACD0),
          iconBg: const Color(0x1A72ACD0),
          onTap: () => _showComingSoon('Dashboard de Alunos'),
        ),
      ];

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature em breve!',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  Widget _animated(int slot, Widget child) => FadeTransition(
        opacity: _fades[slot],
        child: SlideTransition(position: _slides[slot], child: child),
      );

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final displayName =
        user?.displayName ?? user?.email.split('@').first ?? 'Professor';

    final asyncDashboard = ref.watch(teacherDashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: asyncDashboard.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, __) => _buildContent(
            context,
            displayName: displayName,
            stats: _fallbackStats(),
            classroomId: null,
          ),
          data: (dashboard) => _buildContent(
            context,
            displayName: displayName,
            stats: _buildStats(dashboard),
            classroomId: dashboard?.classroomId,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String displayName,
    required List<TeacherStatItem> stats,
    required String? classroomId,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _animated(
            0,
            TeacherHeader(
              displayName: displayName,
              onLogout: () =>
                  ref.read(loginControllerProvider.notifier).signOut(),
              stats: stats,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _animated(
            1,
            TeacherContent(
              actions: _buildActions(classroomId),
              activities: _buildActivities(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<TeacherStatItem> _buildStats(TeacherDashboardData? dashboard) {
    if (dashboard == null) return _fallbackStats();
    return [
      TeacherStatItem(
        value: dashboard.totalStudents.toString(),
        label: 'Alunos\nna Turma',
        icon: FontAwesomeIcons.userGroup,
      ),
      TeacherStatItem(
        value: dashboard.totalQuestions.toString(),
        label: 'Questões\nCriadas',
        icon: FontAwesomeIcons.fileLines,
      ),
      TeacherStatItem(
        value: dashboard.averageScoreFormatted,
        label: 'Média\nda Turma',
        icon: FontAwesomeIcons.chartSimple,
      ),
    ];
  }

  List<TeacherStatItem> _fallbackStats() => [
        const TeacherStatItem(
          value: '—',
          label: 'Alunos\nna Turma',
          icon: FontAwesomeIcons.userGroup,
        ),
        const TeacherStatItem(
          value: '—',
          label: 'Questões\nCriadas',
          icon: FontAwesomeIcons.fileLines,
        ),
        const TeacherStatItem(
          value: '—',
          label: 'Média\nda Turma',
          icon: FontAwesomeIcons.chartSimple,
        ),
      ];

  List<TeacherActivityItem> _buildActivities() => const [
        TeacherActivityItem(
          description: 'Crie questões e compartilhe com sua turma',
          timeAgo: '',
          icon: FontAwesomeIcons.penToSquare,
          dotColor: Color(0xFF72D09C),
        ),
        TeacherActivityItem(
          description: 'Acompanhe o progresso dos alunos pelo dashboard',
          timeAgo: '',
          icon: FontAwesomeIcons.chartLine,
          dotColor: Color(0xFF72ACD0),
        ),
      ];
}