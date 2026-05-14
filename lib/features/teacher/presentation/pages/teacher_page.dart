import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
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

  final List<TeacherStatItem> _stats = const [
    TeacherStatItem(
      value: '32',
      label: 'Alunos\nAtivos',
      icon: FontAwesomeIcons.userGroup,
    ),
    TeacherStatItem(
      value: '156',
      label: 'Questões\nCriadas',
      icon: FontAwesomeIcons.fileLines,
    ),
    TeacherStatItem(
      value: '78%',
      label: 'Média\nda Turma',
      icon: FontAwesomeIcons.chartSimple,
    ),
  ];

  List<TeacherQuickAction> get _actions => [
        TeacherQuickAction(
          icon: FontAwesomeIcons.school,
          title: 'Minha Turma',
          subtitle: '3ª A · 32 alunos · 78% média',
          iconColor: const Color(0xFF8B72D0),
          iconBg: const Color(0x1A8B72D0),
          onTap: () => _showComingSoon('Minha Turma'),
        ),
        TeacherQuickAction(
          icon: FontAwesomeIcons.wandMagicSparkles,
          title: 'Criar Questões com IA',
          subtitle: 'Personalizar questões por tema e dificuldade',
          iconColor: const Color(0xFF7296D0),
          iconBg: const Color(0x1A7296D0),
          onTap: () => _showComingSoon('Criar Questões com IA'),
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

  final List<TeacherActivityItem> _activities = const [
    TeacherActivityItem(
      description: "Beatriz Costa concluiu 'Grécia e Roma' com 100%",
      timeAgo: 'há 2h',
      icon: FontAwesomeIcons.solidCircleCheck,
      dotColor: Color(0xFFFFB347),
    ),
    TeacherActivityItem(
      description: 'Diego Alves enviou o exercício de Sociologia',
      timeAgo: 'há 4h',
      icon: FontAwesomeIcons.fileArrowUp,
      dotColor: Color(0xFF72ACD0),
    ),
    TeacherActivityItem(
      description: 'Você criou 5 questões de Filosofia com IA',
      timeAgo: 'ontem',
      icon: FontAwesomeIcons.wandMagicSparkles,
      dotColor: Color(0xFF8B72D0),
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _animated(
                0,
                TeacherHeader(
                  displayName: displayName,
                  onLogout: () =>
                      ref.read(loginControllerProvider.notifier).signOut(),
                  stats: _stats,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                1,
                TeacherContent(
                  actions: _actions,
                  activities: _activities,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}
