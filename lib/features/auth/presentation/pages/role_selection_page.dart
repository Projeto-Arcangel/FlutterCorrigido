import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/user.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/role_card.dart';
import '../widgets/role_selection_header.dart';

class RoleSelectionPage extends ConsumerStatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  ConsumerState<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends ConsumerState<RoleSelectionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeTitle;
  late final Animation<double> _fadeCards;
  late final Animation<Offset> _slideCards;

  /// Marca quando uma das cards foi tocada e o `setRole` está em vôo.
  /// Bloqueia toques duplos e ilustra loading.
  bool _saving = false;

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

  Future<void> _onRoleSelected(UserRole role) async {
    if (_saving) return;

    final fbUser = ref.read(firebaseAuthProvider).currentUser;
    if (fbUser == null) {
      // Defesa em profundidade: o router não deveria deixar chegar aqui
      // sem usuário logado, mas se acontecer (deep link, race condition),
      // não tenta gravar e deixa o redirect resolver.
      return;
    }

    setState(() => _saving = true);

    final result = await ref.read(userRepositoryProvider).setRole(
          userId: fbUser.uid,
          role: role,
        );

    if (role == UserRole.teacher && result.isRight()) {
      // Cria uma turma padrão para o professor recém-cadastrado
      final createClassroom = ref.read(createClassroomProvider);
      final displayName =
          fbUser.displayName ?? fbUser.email?.split('@').first ?? 'Professor';
      await createClassroom(
        name: 'Minha Primeira Turma',
        teacherId: fbUser.uid,
        teacherName: displayName,
        description: 'Turma gerada automaticamente.',
      );
    }

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message),
            backgroundColor: const Color(0xFF7D2E2E),
          ),
        );
      },
      (_) {
        // Invalida o cache para forçar o refetch. O router observa este
        // provider e, ao receber o novo valor, dispara o redirect para
        // /subjects automaticamente.
        ref.invalidate(currentUserRoleProvider);
      },
    );
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
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: RoleCard(
                      emoji: '🎒',
                      accentColor: const Color(0xFFEAD47F),
                      title: 'Sou Aluno',
                      subtitle: 'Estudar por conta própria ou via turma',
                      onTap: () => _onRoleSelected(UserRole.student),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SlideTransition(
                position: _slideCards,
                child: FadeTransition(
                  opacity: _fadeCards,
                  child: AbsorbPointer(
                    absorbing: _saving,
                    child: RoleCard(
                      emoji: '📋',
                      accentColor: const Color(0xFF72D082),
                      title: 'Sou Professor',
                      subtitle:
                          'Gerenciar turmas, conteúdos e acompanhar alunos',
                      onTap: () => _onRoleSelected(UserRole.teacher),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
