import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../classroom/domain/entities/classroom_activity.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
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

  /// Limite inicial de atividades carregadas.
  static const int _kInitialLimit = 3;

  /// Quantidade de atividades adicionais por clique em "Ver mais".
  static const int _kPageSize = 5;

  /// Quantas atividades estão sendo requisitadas no momento.
  int _activityLimit = _kInitialLimit;

  /// Flag visual enquanto carrega mais atividades.
  bool _isLoadingMore = false;

  /// Indica se todas as atividades foram carregadas (servidor retornou
  /// menos do que o pedido).
  bool _allLoaded = false;

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
          title: 'Minhas Turmas',
          subtitle: classroomId != null
              ? 'Gerencie alunos, fases e questões'
              : 'Crie sua primeira turma',
          iconColor: const Color(0xFF8B72D0),
          iconBg: const Color(0x1A8B72D0),
          onTap: () => context.push(AppRoutes.teacherClassroom),
        ),
        TeacherQuickAction(
          icon: FontAwesomeIcons.chartLine,
          title: 'Dashboard de Alunos',
          subtitle: 'Acompanhe a evolução e exporte as notas da turma',
          iconColor: const Color(0xFF72D082),
          iconBg: const Color(0x1A72D082),
          onTap: () => context.push(
            AppRoutes.teacherStudentDashboard,
            extra: <String, dynamic>{'classroomId': classroomId},
          ),
        ),
      ];

  Widget _animated(int slot, Widget child) => FadeTransition(
        opacity: _fades[slot],
        child: SlideTransition(position: _slides[slot], child: child),
      );

  /// Carrega mais atividades recentes.
  Future<void> _loadMore() async {
    if (_isLoadingMore || _allLoaded) return;
    setState(() => _isLoadingMore = true);

    final newLimit = _activityLimit + _kPageSize;
    setState(() => _activityLimit = newLimit);

    // Aguarda o provider resolver os dados novos.
    // Como o provider é autoDispose.family, ele será invalidado e
    // o novo limite será aplicado no próximo build.
    // O estado de isLoadingMore será desligado quando os dados novos chegarem.
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final displayName =
        user?.displayName ?? user?.email.split('@').first ?? 'Professor';

    final asyncDashboard = ref.watch(teacherDashboardProvider);
    final asyncActivities = ref.watch(recentActivitiesProvider(_activityLimit));

    final activities = asyncActivities.when(
      loading: () => <TeacherActivityItem>[],
      error: (_, __) => <TeacherActivityItem>[],
      data: (events) {
        // Se o provider retornou menos do que pedimos, todas já foram carregadas.
        if (events.length < _activityLimit && !_allLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _allLoaded = true);
          });
        }
        // Desliga o loading quando dados chegam.
        if (_isLoadingMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isLoadingMore = false);
          });
        }
        return _mapActivities(events);
      },
    );

    return Scaffold(
      body: SafeArea(
        child: asyncDashboard.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, __) => _buildContent(
            context,
            displayName: displayName,
            classroomId: null,
            activities: activities,
          ),
          data: (dashboard) => _buildContent(
            context,
            displayName: displayName,
            classroomId: dashboard?.classroomId,
            activities: activities,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String displayName,
    required String? classroomId,
    required List<TeacherActivityItem> activities,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _animated(0, TeacherHeader(displayName: displayName)),
        ),
        SliverToBoxAdapter(
          child: _animated(
            1,
            TeacherContent(
              actions: _buildActions(classroomId),
              activities: activities.isNotEmpty
                  ? activities
                  : _placeholderActivities(),
              onLoadMore: activities.isNotEmpty ? _loadMore : null,
              allLoaded: _allLoaded || activities.isEmpty,
              isLoadingMore: _isLoadingMore,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<TeacherActivityItem> _mapActivities(
    List<ClassroomActivity> events,
  ) {
    return events.map((e) {
      return TeacherActivityItem(
        description: e.description,
        timeAgo: _timeAgo(e.createdAt),
        icon: _activityIcon(e.type),
        dotColor: _activityColor(e.type),
      );
    }).toList();
  }

  List<TeacherActivityItem> _placeholderActivities() => const [
        TeacherActivityItem(
          description: 'Crie uma fase para começar',
          timeAgo: '',
          icon: FontAwesomeIcons.layerGroup,
          dotColor: Color(0xFF8B72D0),
        ),
        TeacherActivityItem(
          description: 'Acompanhe o progresso pelo dashboard',
          timeAgo: '',
          icon: FontAwesomeIcons.chartLine,
          dotColor: Color(0xFF72D082),
        ),
      ];

  IconData _activityIcon(String type) {
    switch (type) {
      case 'phase_created':
        return FontAwesomeIcons.layerGroup;
      case 'student_joined':
        return FontAwesomeIcons.userPlus;
      case 'student_completed':
        return FontAwesomeIcons.circleCheck;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'phase_created':
        return const Color(0xFF8B72D0);
      case 'student_joined':
        return const Color(0xFF72B2D0);
      case 'student_completed':
        return const Color(0xFF72D082);
      default:
        return const Color(0xFF8FA3AE);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    return 'há ${diff.inDays ~/ 7} sem';
  }
}