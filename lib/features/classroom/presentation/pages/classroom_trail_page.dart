import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/domain/entities/level_utils.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/entities/classroom_phase.dart';
import '../providers/classroom_providers.dart';

/// Trilha de fases de uma sala de aula (similar à LessonListPage,
/// mas exibe as phases criadas pelo professor dentro da classroom).
class ClassroomTrailPage extends ConsumerWidget {
  const ClassroomTrailPage({super.key, required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPhases = ref.watch(classroomPhasesProvider(classroom.id));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            _ClassroomTrailHeader(classroom: classroom),
            const SizedBox(height: 12),

            // ── Lista de fases ──────────────────────────────────
            Expanded(
              child: asyncPhases.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => _EmptyClassroomTrail(),
                data: (phases) {
                  if (phases.isEmpty) return _EmptyClassroomTrail();
                  return _ClassroomTrailList(
                    phases: phases,
                    classroom: classroom,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header da trilha de classroom ──────────────────────────────────────────

class _ClassroomTrailHeader extends ConsumerWidget {
  const _ClassroomTrailHeader({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).valueOrNull;
    final asyncProgress =
        user == null ? null : ref.watch(userProgressProvider(user.id));
    final progress = asyncProgress?.valueOrNull;

    final int level = progress?.level ?? 1;
    final int gold = progress?.gold ?? 0;
    final int xpForLevel = xpRequiredForLevel(level);
    final double xpAtLevelStart = totalXpForLevel(level);
    final double xpIntoLevel =
        ((progress?.xp ?? 0) - xpAtLevelStart).clamp(0, xpForLevel.toDouble());
    final double levelProgress =
        xpForLevel > 0 ? (xpIntoLevel / xpForLevel).clamp(0.0, 1.0) : 0.0;

    final Color mutedColor = isDark ? Colors.white54 : AppColors.textSecondary;
    final Color primaryText = isDark ? Colors.white : AppColors.textPrimary;
    final Color avatarBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              // Botão voltar
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: mutedColor,
                ),
                onPressed: () => context.pop(),
              ),
              const Spacer(),

              // Avatar + progress ring + level (centro)
              Column(
                children: [
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.profile),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              value: levelProgress,
                              strokeWidth: 2.5,
                              backgroundColor: avatarBg,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: avatarBg,
                            child: Icon(
                              Icons.person,
                              color: mutedColor,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Nv. $level',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Moedas
              Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.coins,
                    color: Color(0xFFEAD47F),
                    size: 20,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    gold.toString().padLeft(4, '0'),
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Nome da sala
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    classroom.name,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Prof. ${classroom.teacherName}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8FA3AE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zigue-zague (mesma lógica da trilha normal) ──────────────────────────────
const double _kTrailMaxWidth = 320;

Widget _trailRow({required int index, required Widget cell}) {
  final col = index % 3;
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kTrailMaxWidth),
      child: Row(
        children: List.generate(3, (c) {
          return Expanded(
            child: Center(
              child: c == col ? cell : const SizedBox.shrink(),
            ),
          );
        }),
      ),
    ),
  );
}

// ── Lista em zigue-zague para fases de classroom ─────────────────────────────
class _ClassroomTrailList extends StatelessWidget {
  const _ClassroomTrailList({
    required this.phases,
    required this.classroom,
  });
  final List<ClassroomPhase> phases;
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: phases.length,
      itemBuilder: (context, i) => _PhaseNode(
        phase: phases[i],
        index: i,
        classroom: classroom,
      ),
    );
  }
}

// ── Nó individual da fase ────────────────────────────────────────────────────
class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.phase,
    required this.index,
    required this.classroom,
  });
  final ClassroomPhase phase;
  final int index;
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: _trailRow(
        index: index,
        cell: _PhaseButton(
          phase: phase,
          index: index,
          classroom: classroom,
        ),
      ),
    );
  }
}

// ── Botão da fase ────────────────────────────────────────────────────────────
class _PhaseButton extends StatelessWidget {
  const _PhaseButton({
    required this.phase,
    required this.index,
    required this.classroom,
  });
  final ClassroomPhase phase;
  final int index;
  final Classroom classroom;

  // Todas as fases de classroom estão desbloqueadas para os alunos
  bool get _unlocked => true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _unlocked
          ? () => context.push(
                AppRoutes.classroomLessonPath(classroom.id, phase.id),
                extra: {
                  'classroom': classroom,
                  'phase': phase,
                },
              )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OvalPhase(unlocked: _unlocked, index: index),
          const SizedBox(height: 6),
          Text(
            phase.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Oval com ícone ──────────────────────────────────────────────────────────
class _OvalPhase extends StatelessWidget {
  const _OvalPhase({required this.unlocked, required this.index});
  final bool unlocked;
  final int index;

  static const _shades = [
    Color(0xFF3B7DD8),
    Color(0xFF2E69B8),
    Color(0xFF4A8FE8),
    Color(0xFF1E5BA0),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _shades[index % _shades.length];

    final Widget icon = unlocked
        ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)
        : Icon(Icons.lock_outlined,
            color: Colors.white.withValues(alpha: 0.5), size: 28,);

    return Container(
      width: 98,
      height: 79,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: icon),
    );
  }
}

// ── Trilha vazia ────────────────────────────────────────────────────────────
class _EmptyClassroomTrail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.quiz_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text(
              'O professor ainda não criou\nnenhuma fase nesta sala.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8FA3AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
