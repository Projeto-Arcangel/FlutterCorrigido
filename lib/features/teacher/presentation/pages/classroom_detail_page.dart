import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_phase.dart';
import '../../../classroom/domain/entities/classroom_result.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../providers/teacher_dashboard_provider.dart';
import '../widgets/classroom_form_sheet.dart';
import '../widgets/classroom_palette.dart';
import 'phase_management_page.dart';

/// Tela de detalhe de uma única turma.
///
/// Recebe o [Classroom] inicial via construtor (vindo da lista) e mantém
/// uma cópia local sincronizada com o provider — assim, após editar via
/// [ClassroomFormSheet], a tela reflete imediatamente as mudanças.
class ClassroomDetailPage extends ConsumerStatefulWidget {
  const ClassroomDetailPage({super.key, required this.classroom});

  final Classroom classroom;

  @override
  ConsumerState<ClassroomDetailPage> createState() =>
      _ClassroomDetailPageState();
}

class _ClassroomDetailPageState extends ConsumerState<ClassroomDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  static const int _n = 3;
  static const Duration _dur = Duration(milliseconds: 700);
  static const Duration _stagger = Duration(milliseconds: 80);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _dur);
    _fades = List.generate(_n, (i) {
      final s = (i * _stagger.inMilliseconds) / _dur.inMilliseconds;
      final e = (s + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(s, e, curve: Curves.easeOut),
      );
    });
    _slides = _fades
        .map(
          (a) => Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(a),
        )
        .toList();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Lê o Classroom atual: prefere a versão do provider (caso tenha
  /// sido editado) e cai para o que veio via construtor.
  Classroom _currentClassroom() {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return widget.classroom;
    final list = ref
        .read(teacherClassroomsProvider(user.id))
        .valueOrNull
        ?.cast<Classroom>();
    return list?.firstWhere(
          (c) => c.id == widget.classroom.id,
          orElse: () => widget.classroom,
        ) ??
        widget.classroom;
  }

  Future<void> _onEdit() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    final classroom = _currentClassroom();

    await ClassroomFormSheet.show(
      context: context,
      userId: user.id,
      displayName: (user.userMetadata?['display_name'] as String?) ??
          user.email ??
          'Professor',
      classroom: classroom,
    );
  }

  Future<void> _onDelete() async {
    final classroom = _currentClassroom();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteConfirmDialog(classroom: classroom),
    );
    if (confirmed != true || !mounted) return;

    final result =
        await ref.read(deleteClassroomProvider)(classroom.id);

    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            f.message,
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: ClassroomPalette.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      ),
      (_) {
        final user = ref.read(supabaseClientProvider).auth.currentUser;
        if (user != null) {
          ref.invalidate(teacherClassroomsProvider(user.id));
        }
        ref.invalidate(teacherDashboardProvider);
        Navigator.of(context).pop(); // volta para a listagem
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    // Observa a lista de turmas para reagir a edições/deleções.
    final asyncList = ref.watch(teacherClassroomsProvider(user.id));
    final classroom = asyncList.valueOrNull?.cast<Classroom>().firstWhere(
          (c) => c.id == widget.classroom.id,
          orElse: () => widget.classroom,
        ) ??
        widget.classroom;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            _Animated(
              fade: _fades[0],
              slide: _slides[0],
              child: _ClassroomHeaderCard(classroom: classroom),
            ),
            const SizedBox(height: 28),
            _Animated(
              fade: _fades[1],
              slide: _slides[1],
              child: _PhasesSection(classroom: classroom),
            ),
            const SizedBox(height: 28),
            _Animated(
              fade: _fades[2],
              slide: _slides[2],
              child: _ResultsSection(classroomId: classroom.id),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Detalhes da Turma',
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
      actions: [
        PopupMenuButton<_DetailAction>(
          icon: Icon(Icons.more_vert_rounded, color: textColor),
          tooltip: 'Opções da turma',
          color: ClassroomPalette.cardBg(isDark),
          onSelected: (a) {
            switch (a) {
              case _DetailAction.edit:
                _onEdit();
              case _DetailAction.delete:
                _onDelete();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _DetailAction.edit,
              child: _MenuRow(
                icon: Icons.edit_outlined,
                label: 'Editar turma',
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
            const PopupMenuItem(
              value: _DetailAction.delete,
              child: _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir turma',
                color: ClassroomPalette.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _DetailAction { edit, delete }

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de confirmação de exclusão
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: ClassroomPalette.cardBg(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: ClassroomPalette.dangerSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: ClassroomPalette.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Excluir turma?',
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Você está prestes a excluir "${classroom.name}".',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ClassroomPalette.primaryText(isDark),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Isso vai remover ${classroom.studentCount} aluno'
            '${classroom.studentCount == 1 ? '' : 's'}, todas as fases, '
            'questões e resultados desta turma.\n\n'
            'Esta ação é irreversível.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ClassroomPalette.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ClassroomPalette.textMuted,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ClassroomPalette.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Excluir',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wrapper de animação (idêntico ao usado na lista)
// ─────────────────────────────────────────────────────────────────────────────

class _Animated extends StatelessWidget {
  const _Animated({
    required this.fade,
    required this.slide,
    required this.child,
  });
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Header card da turma
//
// Layout: ícone + nome/descrição à esquerda; à direita, o código da
// turma com tamanho grande e um único botão para copiar (apenas o
// ícone, para reduzir a área ocupada — Nielsen #8, design minimalista).
// Os chips de status (alunos e ativa/inativa) ficam embaixo.
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomHeaderCard extends StatelessWidget {
  const _ClassroomHeaderCard({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ClassroomPalette.goldSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: ClassroomPalette.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      classroom.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ClassroomPalette.primaryText(isDark),
                        height: 1.2,
                      ),
                    ),
                    if (classroom.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        classroom.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ClassroomPalette.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _InlineClassCode(code: classroom.code),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusChip(
                icon: Icons.people_outline_rounded,
                label:
                    '${classroom.studentCount}/${Classroom.maxStudents} alunos',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _StatusChip(
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Código da turma inline — exibido no canto direito do header card.
//
// Heurísticas:
//  - #1 (visibilidade): o código fica visível, com letras grandes, sem
//    precisar de uma seção dedicada.
//  - #8 (minimalismo): apenas o ícone de copiar, sem o rótulo "copiar".
//  - #1 (feedback): o ícone troca para um check ao copiar.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineClassCode extends StatefulWidget {
  const _InlineClassCode({required this.code});
  final String code;

  @override
  State<_InlineClassCode> createState() => _InlineClassCodeState();
}

class _InlineClassCodeState extends State<_InlineClassCode> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: ClassroomPalette.goldSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ClassroomPalette.gold.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CÓDIGO',
            style: GoogleFonts.nunito(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ClassroomPalette.goldDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.code,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: ClassroomPalette.gold,
                  letterSpacing: 1.6,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  onPressed: _copy,
                  tooltip: _copied ? 'Código copiado' : 'Copiar código',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  splashRadius: 18,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 16,
                      color: _copied
                          ? ClassroomPalette.success
                          : ClassroomPalette.gold,
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

// ─────────────────────────────────────────────────────────────────────────────
// Seção de fases — listagem, reordenação e criação
//
// Heurísticas:
//  - #1 (visibilidade): cada fase mostra ordem, nome e contagem de
//    questões; o estado vazio explica o próximo passo.
//  - #3 (controle): o professor pode arrastar para reordenar e tocar
//    para gerenciar/editar.
//  - #5 (prevenção de erro): criar uma fase exige um nome válido antes
//    de prosseguir.
//  - #7 (flexibilidade): atalho "+" sempre visível no cabeçalho da
//    seção.
// ─────────────────────────────────────────────────────────────────────────────

class _PhasesSection extends ConsumerStatefulWidget {
  const _PhasesSection({required this.classroom});
  final Classroom classroom;

  @override
  ConsumerState<_PhasesSection> createState() => _PhasesSectionState();
}

class _PhasesSectionState extends ConsumerState<_PhasesSection> {
  bool _reordering = false;
  bool _savingOrder = false;

  Future<void> _onCreatePhase() async {
    final created = await showModalBottomSheet<ClassroomPhase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhaseFormSheet(classroomId: widget.classroom.id),
    );

    if (created != null && mounted) {
      ref.invalidate(classroomPhasesProvider(widget.classroom.id));
      // Após criar, abre a tela de gerenciamento da fase nova para que
      // o professor já adicione questões.
      _openPhaseManagement(created);
    }
  }

  void _openPhaseManagement(ClassroomPhase phase) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PhaseManagementPage(
          classroom: widget.classroom,
          phase: phase,
        ),
      ),
    );
  }

  Future<void> _persistOrder(List<ClassroomPhase> reorderedPhases) async {
    setState(() => _savingOrder = true);
    final useCase = ref.read(reorderPhasesProvider);
    final result = await useCase(
      classroomId: widget.classroom.id,
      orderedPhaseIds: reorderedPhases.map((p) => p.id).toList(),
    );
    if (!mounted) return;
    setState(() => _savingOrder = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            f.message,
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: ClassroomPalette.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      (_) => ref.invalidate(classroomPhasesProvider(widget.classroom.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPhases =
        ref.watch(classroomPhasesProvider(widget.classroom.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhasesHeader(
          phaseCount: asyncPhases.valueOrNull?.length ?? 0,
          reordering: _reordering,
          canReorder: (asyncPhases.valueOrNull?.length ?? 0) >= 2,
          onCreate: _onCreatePhase,
          onToggleReorder: () =>
              setState(() => _reordering = !_reordering),
        ),
        const SizedBox(height: 10),
        asyncPhases.when(
          loading: () => _LoadingBox(isDark: isDark),
          error: (_, __) => _ErrorBox(
            isDark: isDark,
            onRetry: () =>
                ref.invalidate(classroomPhasesProvider(widget.classroom.id)),
          ),
          data: (phases) {
            if (phases.isEmpty) {
              return _EmptyPhasesBox(
                isDark: isDark,
                onCreate: _onCreatePhase,
              );
            }
            return _PhasesList(
              phases: phases,
              reordering: _reordering,
              busy: _savingOrder,
              onTap: _openPhaseManagement,
              onReorder: (newList) => _persistOrder(newList),
            );
          },
        ),
      ],
    );
  }
}

class _PhasesHeader extends StatelessWidget {
  const _PhasesHeader({
    required this.phaseCount,
    required this.reordering,
    required this.canReorder,
    required this.onCreate,
    required this.onToggleReorder,
  });

  final int phaseCount;
  final bool reordering;
  final bool canReorder;
  final VoidCallback onCreate;
  final VoidCallback onToggleReorder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FASES DA TURMA',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ClassroomPalette.textMuted,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phaseCount == 0
                      ? 'Crie a primeira fase desta turma'
                      : '$phaseCount fase${phaseCount == 1 ? '' : 's'} '
                          'cadastrada${phaseCount == 1 ? '' : 's'}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ClassroomPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (canReorder)
            _HeaderButton(
              icon: reordering
                  ? Icons.check_rounded
                  : Icons.swap_vert_rounded,
              label: reordering ? 'Concluir' : 'Reordenar',
              color: reordering
                  ? ClassroomPalette.success
                  : AppColors.primary,
              onTap: onToggleReorder,
            ),
          if (canReorder) const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.add_rounded,
            label: 'Nova fase',
            color: ClassroomPalette.gold,
            onTap: onCreate,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhasesList extends StatefulWidget {
  const _PhasesList({
    required this.phases,
    required this.reordering,
    required this.busy,
    required this.onTap,
    required this.onReorder,
  });

  final List<ClassroomPhase> phases;
  final bool reordering;
  final bool busy;
  final ValueChanged<ClassroomPhase> onTap;
  final ValueChanged<List<ClassroomPhase>> onReorder;

  @override
  State<_PhasesList> createState() => _PhasesListState();
}

class _PhasesListState extends State<_PhasesList> {
  late List<ClassroomPhase> _local;

  @override
  void initState() {
    super.initState();
    _local = [...widget.phases];
  }

  @override
  void didUpdateWidget(covariant _PhasesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phases != widget.phases) {
      _local = [...widget.phases];
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      var to = newIndex;
      if (to > oldIndex) to -= 1;
      final moved = _local.removeAt(oldIndex);
      _local.insert(to, moved);
    });
    widget.onReorder(_local);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _local.length,
        onReorder: _onReorder,
        proxyDecorator: (child, _, __) => Material(
          color: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        itemBuilder: (_, i) {
          final phase = _local[i];
          return _PhaseTile(
            key: ValueKey(phase.id),
            index: i,
            phase: phase,
            reordering: widget.reordering,
            disabled: widget.busy,
            onTap: widget.reordering ? null : () => widget.onTap(phase),
          );
        },
      ),
    );
  }
}

class _PhaseTile extends StatelessWidget {
  const _PhaseTile({
    super.key,
    required this.index,
    required this.phase,
    required this.reordering,
    required this.disabled,
    required this.onTap,
  });

  final int index;
  final ClassroomPhase phase;
  final bool reordering;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase.title.isEmpty ? 'Fase sem nome' : phase.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ClassroomPalette.primaryText(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${phase.totalQuestions} '
                  'quest${phase.totalQuestions == 1 ? 'ão' : 'ões'}'
                  '${phase.description.isEmpty ? '' : ' · ${phase.description}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ClassroomPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (reordering)
            ReorderableDragStartListener(
              index: index,
              enabled: !disabled,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: ClassroomPalette.textMuted,
                  size: 20,
                ),
              ),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              color: ClassroomPalette.textMuted,
              size: 22,
            ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          if (index > 0)
            Divider(
              height: 1,
              color: ClassroomPalette.divider(isDark),
              indent: 16,
              endIndent: 16,
            ),
          InkWell(onTap: onTap, child: body),
        ],
      ),
    );
  }
}

class _EmptyPhasesBox extends StatelessWidget {
  const _EmptyPhasesBox({required this.isDark, required this.onCreate});
  final bool isDark;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: ClassroomPalette.goldSubtle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.layers_outlined,
              color: ClassroomPalette.gold,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhuma fase criada ainda',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: ClassroomPalette.primaryText(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Crie uma fase para começar a adicionar questões '
            'manualmente ou com IA.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ClassroomPalette.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Criar primeira fase',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ClassroomPalette.gold,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.isDark, required this.onRetry});
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: ClassroomPalette.textMuted,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'Não foi possível carregar as fases.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ClassroomPalette.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Tentar novamente',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de criação de fase
// Pede o nome (obrigatório) e a descrição (opcional) antes de criar.
// ─────────────────────────────────────────────────────────────────────────────

class _PhaseFormSheet extends ConsumerStatefulWidget {
  const _PhaseFormSheet({required this.classroomId});
  final String classroomId;

  @override
  ConsumerState<_PhaseFormSheet> createState() => _PhaseFormSheetState();
}

class _PhaseFormSheetState extends ConsumerState<_PhaseFormSheet> {
  final _nameCtrl = TextEditingController();
  String? _selectedSubject;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selectedSubject != null &&
      !_saving;

  Future<void> _onSave() async {
    if (!_isValid) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final useCase = ref.read(createEmptyPhaseProvider);
    final result = await useCase(
      classroomId: widget.classroomId,
      title: _nameCtrl.text,
      description: _selectedSubject!,
    );
    if (!mounted) return;

    result.fold(
      (f) => setState(() {
        _saving = false;
        _error = f.message;
      }),
      (phase) {
        Navigator.of(context).pop(phase);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: ClassroomPalette.cardBg(isDark),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ClassroomPalette.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ClassroomPalette.goldSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: ClassroomPalette.gold,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nova fase',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ClassroomPalette.primaryText(isDark),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ClassroomPalette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SheetLabel(text: 'NOME DA FASE'),
            const SizedBox(height: 6),
            _SheetField(
              controller: _nameCtrl,
              hint: 'Ex: Revolução Industrial',
              autofocus: true,
              maxLines: 1,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 14),
            _SheetLabel(text: 'DISCIPLINA'),
            const SizedBox(height: 6),
            _SubjectDropdown(
              value: _selectedSubject,
              onChanged: (v) => setState(() => _selectedSubject = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ClassroomPalette.dangerSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ClassroomPalette.danger.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: ClassroomPalette.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ClassroomPalette.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _isValid ? _onSave : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _saving ? 'Criando...' : 'Criar fase',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ClassroomPalette.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: ClassroomPalette.textMuted,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: (_) => onChanged(),
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 2,
      cursorColor: ClassroomPalette.gold,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ClassroomPalette.primaryText(isDark),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: ClassroomPalette.textMuted,
        ),
        filled: true,
        fillColor: ClassroomPalette.fieldFill(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: ClassroomPalette.gold, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown de disciplina — usado no _PhaseFormSheet ao criar uma nova fase.
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectDropdown extends StatelessWidget {
  const _SubjectDropdown({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  static const List<String> _subjects = [
    'português',
    'matemática',
    'história',
    'geografia',
    'filosofia',
    'sociologia',
    'biologia',
    'química',
    'física',
    'artes',
    'educação física',
  ];

  String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      onChanged: onChanged,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ClassroomPalette.primaryText(isDark),
      ),
      dropdownColor: ClassroomPalette.cardBg(isDark),
      iconEnabledColor: ClassroomPalette.textMuted,
      hint: Text(
        'Escolha a disciplina',
        style: GoogleFonts.nunito(
          fontSize: 13,
          color: ClassroomPalette.textMuted,
        ),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: ClassroomPalette.fieldFill(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ClassroomPalette.gold,
            width: 1.5,
          ),
        ),
      ),
      items: _subjects
          .map(
            (s) => DropdownMenuItem<String>(
              value: s,
              child: Text(
                _label(s),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ClassroomPalette.primaryText(isDark),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seção de resultados
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsSection extends ConsumerWidget {
  const _ResultsSection({required this.classroomId});
  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncResults = ref.watch(classroomResultsProvider(classroomId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'RESULTADOS'),
        const SizedBox(height: 10),
        asyncResults.when(
          loading: () => Container(
            height: 80,
            decoration: BoxDecoration(
              color: ClassroomPalette.cardBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClassroomPalette.border(isDark)),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ClassroomPalette.cardBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClassroomPalette.border(isDark)),
            ),
            child: const _EmptyHint(
              icon: Icons.cloud_off_outlined,
              text: 'Não foi possível carregar os resultados.',
            ),
          ),
          data: (results) {
            if (results.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ClassroomPalette.cardBg(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ClassroomPalette.border(isDark)),
                ),
                child: const _EmptyHint(
                  icon: Icons.bar_chart_outlined,
                  text:
                      'Nenhum aluno completou atividades ainda.\nCrie questões para começar!',
                ),
              );
            }

            final sorted = [...results]
              ..sort((a, b) => b.percentage.compareTo(a.percentage));

            return Container(
              decoration: BoxDecoration(
                color: ClassroomPalette.cardBg(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ClassroomPalette.border(isDark)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < sorted.length; i++) ...[
                    _ResultTile(result: sorted[i]),
                    if (i < sorted.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                          color: ClassroomPalette.divider(isDark),
                          height: 1,
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final ClassroomResult result;

  Color get _scoreColor {
    if (result.percentage >= 0.7) return ClassroomPalette.success;
    if (result.percentage >= 0.4) return ClassroomPalette.gold;
    return ClassroomPalette.danger;
  }

  String get _initials {
    final parts = result.studentName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ClassroomPalette.primaryText(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.correctAnswers} / ${result.totalQuestions} acertos',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ClassroomPalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _scoreColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              result.percentageFormatted,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilitários
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ClassroomPalette.textMuted,
            letterSpacing: 2.2,
          ),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: ClassroomPalette.textMuted.withValues(alpha: 0.5),
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ClassroomPalette.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}
