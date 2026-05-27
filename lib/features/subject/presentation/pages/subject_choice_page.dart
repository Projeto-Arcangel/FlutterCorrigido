import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../classroom/presentation/widgets/classroom_sheet.dart';


class SubjectChoicePage extends ConsumerWidget {
  const SubjectChoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                ref.read(loginControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: const SafeArea(
        child: _SubjectList(),
      ),
    );
  }
}

// ── Lista interna ─────────────────────────────────────────────────────────────
class _SubjectList extends StatelessWidget {
  const _SubjectList();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Título ──────────────────────────────────────────────
            Text(
              'Pronto para estudar?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),

            // ── Botão "Entrar em Turma" ───────────────────────────
            const _EnterClassroomButton(),
          ],
        ),
      ),
    );
  }
}


// ── Botão "Entrar em Turma" ───────────────────────────────────────────────────
/// Sempre abre o bottom sheet de turmas — o sheet já mostra as turmas
/// actuais do aluno em "MINHAS TURMAS" e permite entrar numa nova.
class _EnterClassroomButton extends StatelessWidget {
  const _EnterClassroomButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => showClassroomSheet(context),
        icon: const Icon(Icons.school_rounded, size: 20),
        label: const Text(
          'Entrar em Turma',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}
