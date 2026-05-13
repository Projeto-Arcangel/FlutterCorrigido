import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../widgets/role_card.dart';
import '../widgets/role_selection_header.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeTitle;
  late final Animation<double> _fadeCards;
  late final Animation<Offset>  _slideCards;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeTitle = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _fadeCards = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );

    _slideCards = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    ));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onRoleSelected(String role) {
    // Futuramente: ref.read(selectedRoleProvider.notifier).state = role;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2428),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              FadeTransition(
                opacity: _fadeTitle,
                child: const RoleSelectionHeader(),
              ),

              const Spacer(flex: 4),

              FadeTransition(
                opacity: _fadeCards,
                child: Text(
                  'COMO VOCÊ VAI ENTRAR?',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8FA3AE),
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SlideTransition(
                position: _slideCards,
                child: FadeTransition(
                  opacity: _fadeCards,
                  child: RoleCard(
                    emoji: '🎒',
                    accentColor: const Color(0xFFEAD47F),
                    title: 'Sou Aluno',
                    subtitle: 'Estudar por conta própria ou via turma',
                    onTap: () => _onRoleSelected('student'),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              SlideTransition(
                position: _slideCards,
                child: FadeTransition(
                  opacity: _fadeCards,
                  child: RoleCard(
                    emoji: '📋',
                    accentColor: const Color(0xFF72D082),
                    title: 'Sou Professor',
                    subtitle: 'Gerenciar turmas, conteúdos e acompanhar alunos',
                    onTap: () => _onRoleSelected('teacher'),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}