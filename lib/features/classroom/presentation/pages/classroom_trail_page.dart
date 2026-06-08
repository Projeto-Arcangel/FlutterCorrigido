import 'package:cached_network_image/cached_network_image.dart';
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
import '../../domain/entities/classroom_result.dart';
import '../providers/classroom_providers.dart';


// ── Trilha de fases de uma sala de aula ──────────────────────────────────────

class ClassroomTrailPage extends ConsumerWidget {
  const ClassroomTrailPage({
    super.key,
    required this.classroomId,
    this.classroom,
  });

  final String classroomId;

  /// Passado via `extra` na navegação. Pode ser null se o GoRouter
  /// reconstruiu a rota (ex.: mudança de nome nas configurações dispara
  /// authStateChanges). Nesse caso, carregamos via [classroomByIdProvider].
  final Classroom? classroom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se já temos o objeto classroom (navegação normal), usamos direto.
    // Caso contrário, buscamos do Supabase via provider.
    if (classroom != null) {
      return _ClassroomTrailContent(classroom: classroom!);
    }

    final asyncClassroom = ref.watch(classroomByIdProvider(classroomId));
    return asyncClassroom.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Erro ao carregar a turma.')),
      ),
      data: (loaded) {
        if (loaded == null) {
          return const Scaffold(
            body: Center(child: Text('Turma não encontrada.')),
          );
        }
        return _ClassroomTrailContent(classroom: loaded);
      },
    );
  }
}

// ── Conteúdo principal da trilha ──────────────────────────────────────────────

class _ClassroomTrailContent extends ConsumerWidget {
  const _ClassroomTrailContent({required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aluno: questões SEM gabarito (anti-cola). O feedback vem do servidor
    // na tela de resultado (submit_quiz), não do payload local.
    final asyncPhases = ref.watch(studentPhasesProvider(classroom.id));

    // Fases já concluídas pelo aluno (para travar a trilha em ordem).
    final completedPhaseIds =
        ref.watch(studentCompletedPhasesProvider(classroom.id)).valueOrNull ??
            const <String>{};

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ClassroomTrailHeader(classroom: classroom),
            const SizedBox(height: 4),
            Expanded(
              child: asyncPhases.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => _EmptyClassroomTrail(),
                data: (phases) {
                  if (phases.isEmpty) return _EmptyClassroomTrail();
                  final sorted = [...phases]
                    ..sort((a, b) => a.order.compareTo(b.order));
                  return _ClassroomTrailList(
                    phases: sorted,
                    classroom: classroom,
                    completedPhaseIds: completedPhaseIds,
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

// ── Header ────────────────────────────────────────────────────────────────────

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

    // Ranking: posição do aluno logado na lista ordenada por % de acertos
    final asyncRanking = ref.watch(classroomRankingProvider(classroom.id));
    final rankedList = asyncRanking.valueOrNull ?? [];
    final rankIndex = rankedList.indexWhere((r) => r.studentId == user?.id);
    final int? rank = rankIndex >= 0 ? rankIndex + 1 : null;

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
          // ── Linha de controles ───────────────────────────────────
          // Botão de voltar fixo à esquerda; grupo central (ranking +
          // avatar + moedas) fica dentro de Expanded+Center para que
          // o avatar fique sempre centralizado na tela. Um SizedBox
          // espelho à direita equilibra a largura do IconButton.
          Row(
            children: [
              // Voltar
              IconButton(
                tooltip: 'Voltar',
                icon: Icon(Icons.chevron_left, color: primaryText, size: 28),
                onPressed: () => context.pop(),
              ),

              // Grupo central totalmente centralizado
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ← Ranking (esquerda do avatar)
                      _RankChip(
                        rank: rank,
                        onTap: () => _showRankingSheet(
                          context,
                          classroom.id,
                          user?.id,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ← Avatar + anel de XP + nível
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.profile),
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: CircularProgressIndicator(
                                      value: levelProgress,
                                      strokeWidth: 3,
                                      backgroundColor: avatarBg,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  ClipOval(
                                    child: user?.photoUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: user!.photoUrl!,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              width: 50,
                                              height: 50,
                                              color: avatarBg,
                                              child: Icon(
                                                Icons.person,
                                                color: mutedColor,
                                                size: 28,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            color: avatarBg,
                                            child: Icon(
                                              Icons.person,
                                              color: mutedColor,
                                              size: 28,
                                            ),
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

                      const SizedBox(width: 16),

                      // ← Moedas (direita do avatar)
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                ),
              ),

              // Espelho do IconButton para manter o grupo central simétrico
              const SizedBox(width: 48),
            ],
          ),

          const SizedBox(height: 8),

          // ── Banner da sala ────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
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

  void _showRankingSheet(
    BuildContext context,
    String classroomId,
    String? currentUserId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RankingSheet(
        classroomId: classroomId,
        currentUserId: currentUserId,
      ),
    );
  }
}

// ── Chip de ranking ───────────────────────────────────────────────────────────

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank, required this.onTap});

  final int? rank;
  final VoidCallback onTap;

  Color get _color {
    if (rank == null) return AppColors.textSecondary;
    if (rank! == 1) return const Color(0xFFEAD47F);
    if (rank! == 2) return const Color(0xFFC0C0C0);
    if (rank! == 3) return const Color(0xFFCD7F32);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_rounded,
              size: 14,
              color: _color,
            ),
            const SizedBox(width: 4),
            Text(
              rank != null ? '#$rank' : '--',
              style: TextStyle(
                color: _color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet de ranking ───────────────────────────────────────────────────

class _RankingSheet extends ConsumerWidget {
  const _RankingSheet({
    required this.classroomId,
    required this.currentUserId,
  });

  final String classroomId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.backgroundDark : Colors.white;
    final asyncRanking = ref.watch(classroomRankingProvider(classroomId));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFEAD47F),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ranking da Turma',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: asyncRanking.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
                error: (_, __) => _EmptyRanking(isDark: isDark),
                data: (results) => results.isEmpty
                    ? _EmptyRanking(isDark: isDark)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: results.length,
                        itemBuilder: (_, i) => _RankingTile(
                          result: results[i],
                          position: i + 1,
                          isCurrentUser:
                              results[i].studentId == currentUserId,
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

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Nenhum resultado ainda.',
        style: TextStyle(
          color: isDark ? Colors.white54 : AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.result,
    required this.position,
    required this.isCurrentUser,
  });

  final ClassroomResult result;
  final int position;
  final bool isCurrentUser;

  Color _positionColor(int pos) {
    if (pos == 1) return const Color(0xFFEAD47F);
    if (pos == 2) return const Color(0xFFC0C0C0);
    if (pos == 3) return const Color(0xFFCD7F32);
    return AppColors.primary;
  }

  String _medal(int pos) {
    if (pos == 1) return '🥇';
    if (pos == 2) return '🥈';
    if (pos == 3) return '🥉';
    return '#$pos';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posColor = _positionColor(position);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(14),
        border: isCurrentUser
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          // Posição / medalha
          SizedBox(
            width: 32,
            child: Text(
              _medal(position),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: position <= 3 ? 18 : 13,
                fontWeight: FontWeight.bold,
                color: posColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nome + "Você"
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.studentName,
                  style: TextStyle(
                    color: isDark
                        ? Colors.white
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCurrentUser)
                  const Text(
                    'Você',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Porcentagem + barra
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.percentageFormatted,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.percentage,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white12
                        : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      position <= 3 ? posColor : AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lista da trilha (base→topo, estilo Duolingo) ──────────────────────────────
// `reverse: true`: o item 0 (marcador "Início da trilha") fica EMBAIXO e as
// fases sobem de baixo para cima, na ordem (a 1ª fase logo acima do início).
// Dentro de cada item o conector vem DEPOIS do nó para, sob reverse, ficar
// entre esta fase e a anterior (sem conector solto no topo).

class _ClassroomTrailList extends StatelessWidget {
  const _ClassroomTrailList({
    required this.phases,
    required this.classroom,
    required this.completedPhaseIds,
  });

  final List<ClassroomPhase> phases;
  final Classroom classroom;
  final Set<String> completedPhaseIds;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // +1 para o marcador "Início da trilha" (no fim da lista = base da tela)
      itemCount: phases.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return const _TrailStartMarker();
        final phaseIndex = i - 1;
        final phase = phases[phaseIndex];
        final completed = completedPhaseIds.contains(phase.id);
        // Trava em ordem: a 1ª fase é sempre livre; as demais só liberam
        // quando a fase anterior já foi concluída. Uma fase anterior VAZIA
        // (sem questões, que o aluno não consegue concluir) não trava a próxima.
        final bool locked;
        if (phaseIndex == 0) {
          locked = false;
        } else {
          final prev = phases[phaseIndex - 1];
          final prevDone =
              completedPhaseIds.contains(prev.id) || prev.questions.isEmpty;
          locked = !prevDone;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PhaseNode(
              phase: phase,
              index: phaseIndex,
              classroom: classroom,
              locked: locked,
              completed: completed,
            ),
            const _NodeConnector(),
          ],
        );
      },
    );
  }
}

// ── Marcador "Início da trilha" ───────────────────────────────────────────────

class _TrailStartMarker extends StatelessWidget {
  const _TrailStartMarker();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
              'Início da trilha',
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
    );
  }
}

// ── Conector entre nós (pontos estilo Duolingo) ───────────────────────────────

class _NodeConnector extends StatelessWidget {
  const _NodeConnector();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.4 : 0.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nó individual da fase ─────────────────────────────────────────────────────

class _PhaseNode extends StatelessWidget {
  const _PhaseNode({
    required this.phase,
    required this.index,
    required this.classroom,
    required this.locked,
    required this.completed,
  });

  final ClassroomPhase phase;
  final int index;
  final Classroom classroom;
  final bool locked;
  final bool completed;

  // Padrão de zigue-zague S-curve: centro → direita → centro → esquerda
  static const List<int> _zigzag = [1, 2, 1, 0];

  @override
  Widget build(BuildContext context) {
    final col = _zigzag[index % _zigzag.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Row(
            children: List.generate(3, (c) {
              return Expanded(
                child: Center(
                  child: c == col
                      ? _PhaseButton(
                          phase: phase,
                          index: index,
                          classroom: classroom,
                          locked: locked,
                          completed: completed,
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Botão da fase ─────────────────────────────────────────────────────────────

class _PhaseButton extends StatelessWidget {
  const _PhaseButton({
    required this.phase,
    required this.index,
    required this.classroom,
    required this.locked,
    required this.completed,
  });

  final ClassroomPhase phase;
  final int index;
  final Classroom classroom;
  final bool locked;
  final bool completed;

  void _onTap(BuildContext context) {
    if (locked) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Conclua a fase anterior para desbloquear esta.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    context.push(
      AppRoutes.classroomLessonPath(classroom.id, phase.id),
      extra: {'classroom': classroom, 'phase': phase},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OvalPhase(index: index, locked: locked, completed: completed),
          const SizedBox(height: 6),
          Text(
            phase.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: locked
                  ? (isDark
                      ? Colors.white38
                      : AppColors.textSecondary.withValues(alpha: 0.6))
                  : (isDark ? Colors.white70 : AppColors.textSecondary),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Oval com ícone ────────────────────────────────────────────────────────────

class _OvalPhase extends StatelessWidget {
  const _OvalPhase({
    required this.index,
    required this.locked,
    required this.completed,
  });

  final int index;
  final bool locked;
  final bool completed;

  static const _shades = [
    Color(0xFF3B7DD8),
    Color(0xFF2E69B8),
    Color(0xFF4A8FE8),
    Color(0xFF1E5BA0),
  ];

  // Cinza neutro para fases bloqueadas.
  static const Color _lockedColor = Color(0xFF90A4AE);

  @override
  Widget build(BuildContext context) {
    final color = locked ? _lockedColor : _shades[index % _shades.length];
    final IconData icon;
    if (locked) {
      icon = Icons.lock_rounded;
    } else if (completed) {
      icon = Icons.check_rounded;
    } else {
      icon = Icons.play_arrow_rounded;
    }
    return Container(
      width: 98,
      height: 79,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: locked ? 0.2 : 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    );
  }
}

// ── Estado vazio ──────────────────────────────────────────────────────────────

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
