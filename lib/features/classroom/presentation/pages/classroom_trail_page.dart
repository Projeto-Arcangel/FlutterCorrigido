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
import '../../domain/entities/phase_rules.dart';
import '../phase_access.dart';
import '../providers/classroom_providers.dart';
import '../widgets/classmate_profile_sheet.dart';


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
    // Aluno: questões SEM gabarito (anti-cola). A correção vem do servidor
    // a cada resposta (answer_question), não do payload local.
    final asyncPhases = ref.watch(studentPhasesProvider(classroom.id));

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
                            onTap: () =>
                                context.push(AppRoutes.profileInClassroom),
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

    // expand: false — a folha ocupa só a própria altura, então tocar acima
    // dela (no fundo escurecido) fecha o ranking.
    return DraggableScrollableSheet(
      expand: false,
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
                          onTap: () => showClassmateProfile(
                            context,
                            classroomId: classroomId,
                            studentId: results[i].studentId,
                            name: results[i].studentName,
                            isCurrentUser:
                                results[i].studentId == currentUserId,
                          ),
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
    required this.onTap,
  });

  final ClassroomResult result;
  final int position;
  final bool isCurrentUser;

  /// Abre o perfil do aluno.
  final VoidCallback onTap;

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

    // Tocar abre o perfil (nome, nível, estrelas e conquistas na turma).
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isCurrentUser
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.surfaceDark : Colors.grey.shade50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isCurrentUser
              ? BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: _row(isDark, posColor),
          ),
        ),
      ),
    );
  }

  Widget _row(bool isDark, Color posColor) {
    return Row(
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
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? Colors.white38 : AppColors.textSecondary,
          ),
        ],
    );
  }
}

// ── Lista da trilha (topo→base) ───────────────────────────────────────────────
// O item 0 (marcador "Início da trilha") fica NO TOPO e as fases descem na
// ordem (a 1ª fase logo abaixo do início). A tela abre no topo, já mostrando
// o início e a 1ª fase. Dentro de cada item o conector vem ANTES do nó, para
// ficar entre esta fase e a anterior (sem conector solto no fim).

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // +1 para o marcador "Início da trilha" (1º item = topo da tela)
      itemCount: phases.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return const _TrailStartMarker();
        final phaseIndex = i - 1;
        final phase = phases[phaseIndex];
        // Bloqueio, prazo e nota mínima vêm prontos do servidor
        // (student_phase_states): a trilha só mostra.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _NodeConnector(),
            _PhaseNode(
              phase: phase,
              previous: phaseIndex == 0 ? null : phases[phaseIndex - 1],
              index: phaseIndex,
              classroom: classroom,
            ),
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
    required this.previous,
    required this.index,
    required this.classroom,
  });

  final ClassroomPhase phase;
  final ClassroomPhase? previous;
  final int index;
  final Classroom classroom;

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
                          previous: previous,
                          index: index,
                          classroom: classroom,
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
    required this.previous,
    required this.index,
    required this.classroom,
  });

  final ClassroomPhase phase;
  final ClassroomPhase? previous;
  final int index;
  final Classroom classroom;

  /// Fora de alcance agora (bloqueada, agendada ou encerrada sem resposta):
  /// aparece em cinza.
  bool get _unavailable =>
      phase.locked ||
      phase.status == PhaseStatus.scheduled ||
      (phase.status == PhaseStatus.closed && !phase.completed);

  void _onTap(BuildContext context) {
    final access = phaseAccess(phase, previous: previous);
    switch (access.action) {
      case PhaseTapAction.play:
        context.push(
          AppRoutes.classroomLessonPath(classroom.id, phase.id),
          extra: {'classroom': classroom, 'phase': phase},
        );
      case PhaseTapAction.message:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(access.message!),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
      case PhaseTapAction.showResult:
        showDialog<void>(
          context: context,
          builder: (_) => _ClosedPhaseResultDialog(phase: phase),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final caption = phaseCaption(phase);
    final muted = isDark
        ? Colors.white38
        : AppColors.textSecondary.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OvalPhase(
            index: index,
            unavailable: _unavailable,
            icon: _iconFor(phase),
          ),
          if (phase.completed) ...[
            const SizedBox(height: 4),
            _TrailStars(count: phase.stars),
          ],
          const SizedBox(height: 6),
          Text(
            phase.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _unavailable
                  ? muted
                  : (isDark ? Colors.white70 : AppColors.textSecondary),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: phase.needsPassScore
                    ? const Color(0xFFE0A85B)
                    : muted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(ClassroomPhase phase) {
    if (phase.status == PhaseStatus.closed && !phase.completed) {
      return Icons.event_busy_rounded;
    }
    if (phase.locked) return Icons.lock_rounded;
    if (phase.status == PhaseStatus.scheduled) return Icons.schedule_rounded;
    if (phase.completed) return Icons.check_rounded;
    return Icons.play_arrow_rounded;
  }
}

/// Fase encerrada que o aluno respondeu: mostra a nota, sem responder de
/// novo.
class _ClosedPhaseResultDialog extends StatelessWidget {
  const _ClosedPhaseResultDialog({required this.phase});

  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context) {
    final score = phase.scorePct;
    final best = phase.bestPct;
    return AlertDialog(
      title: Text(phase.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Esta fase foi encerrada e não aceita mais respostas.'),
          if (score != null) ...[
            const SizedBox(height: 12),
            Text(
              'Sua nota: ${formatPct(score)}%',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
          if (best != null && score != null && best > score) ...[
            const SizedBox(height: 4),
            Text('Melhor tentativa: ${formatPct(best)}%'),
          ],
          const SizedBox(height: 8),
          _TrailStars(count: phase.stars, size: 22),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}

// ── Estrelas da fase (melhor tentativa) ───────────────────────────────────────

class _TrailStars extends StatelessWidget {
  const _TrailStars({required this.count, this.size = 16});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black26;
    return Semantics(
      label: '$count de 3 estrelas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < count ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < count ? const Color(0xFFFFC83D) : off,
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
    required this.unavailable,
    required this.icon,
  });

  final int index;
  final bool unavailable;
  final IconData icon;

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
    final color =
        unavailable ? _lockedColor : _shades[index % _shades.length];
    return Container(
      width: 98,
      height: 79,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: unavailable ? 0.2 : 0.4),
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
