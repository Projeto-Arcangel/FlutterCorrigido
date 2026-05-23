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
    // subjectsProvider não é necessário aqui, mas mantido para futura expansão
    // (ex.: exibir badge de desbloqueio na tela de escolha).
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
              'Qual caminho você\ndeseja trilhar?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),

            // ── Botão "Sua trilha" (preenchido / primário) ───────────
            const _PersonalTrailButton(),
            const SizedBox(height: 16),

            // ── Separador visual ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Botão "Entrar em Turma" (contornado) ─────────────────
            const _EnterClassroomButton(),
          ],
        ),
      ),
    );
  }
}

// ── Botão "Sua trilha" ────────────────────────────────────────────────────────
/// Navega para a trilha pessoal do aluno (lesson_list_page).
/// Estilo preenchido com a cor primária do app, para maior destaque.
class _PersonalTrailButton extends StatelessWidget {
  const _PersonalTrailButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 52,
      child: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.personalTrail),
        icon: const Icon(Icons.route_rounded, size: 20),
        label: const Text(
          'Sua trilha',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
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
