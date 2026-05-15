import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../widgets/classroom_form_sheet.dart';
import '../widgets/classroom_palette.dart';
import 'classroom_detail_page.dart';

/// Painel de gerenciamento de turmas do professor.
///
/// - Lista todas as turmas como cards clicáveis.
/// - FAB "+" para criar nova turma (abre [ClassroomFormSheet]).
/// - Cada card navega para [ClassroomDetailPage].
/// - Sem turmas: estado vazio com call-to-action.
class ClassroomListPage extends ConsumerStatefulWidget {
  const ClassroomListPage({super.key});

  @override
  ConsumerState<ClassroomListPage> createState() => _ClassroomListPageState();
}

class _ClassroomListPageState extends ConsumerState<ClassroomListPage> {
  Future<void> _openCreateSheet() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    await ClassroomFormSheet.show(
      context: context,
      userId: user.uid,
      displayName: user.displayName ?? user.email ?? 'Professor',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    final asyncClassrooms = ref.watch(teacherClassroomsProvider(user.uid));

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: asyncClassrooms.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _ErrorView(
            message: 'Não foi possível carregar suas turmas.',
            onRetry: () =>
                ref.invalidate(teacherClassroomsProvider(user.uid)),
          ),
          data: (classrooms) => classrooms.isEmpty
              ? _EmptyState(onCreate: _openCreateSheet)
              : _ClassroomList(classrooms: classrooms),
        ),
      ),
      floatingActionButton: asyncClassrooms.whenOrNull(
        data: (classrooms) => classrooms.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _openCreateSheet,
                backgroundColor: ClassroomPalette.gold,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Nova turma',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Minhas Turmas',
        style: GoogleFonts.nunito(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
      leading: IconButton(
        tooltip: 'Voltar',
        icon: Icon(Icons.chevron_left, color: textColor, size: 28),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de cards (estado com 1+ turmas)
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomList extends StatelessWidget {
  const _ClassroomList({required this.classrooms});
  final List<Classroom> classrooms;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: classrooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ClassroomCard(classroom: classrooms[i]),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom});
  final Classroom classroom;

  void _open(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomDetailPage(classroom: classroom),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: ClassroomPalette.cardBg(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClassroomPalette.border(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ClassroomPalette.goldSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: ClassroomPalette.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classroom.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ClassroomPalette.primaryText(isDark),
                          ),
                        ),
                        if (classroom.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            classroom.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: ClassroomPalette.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ClassroomPalette.textMuted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.tag_rounded,
                    label: classroom.code,
                    color: ClassroomPalette.gold,
                    monospace: true,
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: Icons.people_outline_rounded,
                    label:
                        '${classroom.studentCount}/${Classroom.maxStudents}',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: classroom.isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    label: classroom.isActive ? 'Ativa' : 'Inativa',
                    color: classroom.isActive
                        ? ClassroomPalette.success
                        : ClassroomPalette.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool monospace;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: monospace ? 1.5 : 0,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio (sem turmas) — call to action para criar a primeira
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: ClassroomPalette.goldSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                color: ClassroomPalette.gold,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Crie sua primeira turma',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gere um código de acesso e compartilhe com seus alunos.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: ClassroomPalette.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Criar turma',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ClassroomPalette.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado de erro
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: ClassroomPalette.dangerSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: ClassroomPalette.danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ClassroomPalette.primaryText(isDark),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Tentar novamente',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}