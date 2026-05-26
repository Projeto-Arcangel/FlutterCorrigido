import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
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
/// - Aluno já matriculado → navega direto para a trilha da sala.
/// - Sem turma → abre o bottom sheet para digitar o código.
class _EnterClassroomButton extends ConsumerWidget {
  const _EnterClassroomButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClassrooms = ref.watch(userClassroomsProvider);
    final existingClassroom = asyncClassrooms.valueOrNull?.firstOrNull;

    return SizedBox(
      width: 320,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () {
          if (existingClassroom != null) {
            context.push(
              AppRoutes.classroomTrailPath(existingClassroom.id),
              extra: existingClassroom,
            );
          } else {
            showClassroomSheet(context);
          }
        },
        icon: const Icon(
          Icons.school_rounded,
          size: 20,
        ),
        label: Text(
          existingClassroom != null
              ? existingClassroom.name
              : 'Entrar em Turma',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(
            color: AppColors.primary,
            width: 1.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
    );
  }
}
