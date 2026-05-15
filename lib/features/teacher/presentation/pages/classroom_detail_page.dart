import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_result.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../providers/teacher_dashboard_provider.dart';
import '../widgets/classroom_form_sheet.dart';
import '../widgets/classroom_palette.dart';

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

  static const int _n = 4;
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
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return widget.classroom;
    // .cast<Classroom>() resolve a covariance: o datasource devolve
    // List<ClassroomModel> mas o tipo declarado é List<Classroom>.
    final list = ref
        .read(teacherClassroomsProvider(user.uid))
        .valueOrNull
        ?.cast<Classroom>();
    return list?.firstWhere(
          (c) => c.id == widget.classroom.id,
          orElse: () => widget.classroom,
        ) ??
        widget.classroom;
  }

  Future<void> _onEdit() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final classroom = _currentClassroom();

    await ClassroomFormSheet.show(
      context: context,
      userId: user.uid,
      displayName: user.displayName ?? user.email ?? 'Professor',
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
        final user = ref.read(firebaseAuthProvider).currentUser;
        if (user != null) {
          ref.invalidate(teacherClassroomsProvider(user.uid));
        }
        ref.invalidate(teacherDashboardProvider);
        Navigator.of(context).pop(); // volta para a listagem
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    // Observa a lista de turmas para reagir a edições/deleções.
    final asyncList = ref.watch(teacherClassroomsProvider(user.uid));
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
            const SizedBox(height: 24),
            _Animated(
              fade: _fades[1],
              slide: _slides[1],
              child: _CodeSection(code: classroom.code),
            ),
            const SizedBox(height: 32),
            _Animated(
              fade: _fades[2],
              slide: _slides[2],
              child: _StudentsSection(classroom: classroom),
            ),
            const SizedBox(height: 32),
            _Animated(
              fade: _fades[3],
              slide: _slides[3],
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  children: [
                    Text(
                      classroom.name,
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
// Código da turma + botão copiar
// ─────────────────────────────────────────────────────────────────────────────

class _CodeSection extends StatefulWidget {
  const _CodeSection({required this.code});
  final String code;

  @override
  State<_CodeSection> createState() => _CodeSectionState();
}

class _CodeSectionState extends State<_CodeSection> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CodeCard(code: widget.code),
        const SizedBox(height: 12),
        _CopyButton(copied: _copied, onTap: _copy),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final spacedCode = code.split('').join(' ');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      foregroundPainter: const _DashedBorderPainter(
        color: ClassroomPalette.gold,
        borderRadius: 20,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: ClassroomPalette.cardBg(isDark),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'CÓDIGO DA TURMA',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.goldDim,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              spacedCode,
              style: GoogleFonts.nunito(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: ClassroomPalette.gold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Compartilhe com seus alunos para entrarem na turma',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: ClassroomPalette.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    this.borderRadius = 20,
  });

  final Color color;
  final double borderRadius;

  static const double _strokeWidth = 1.5;
  static const double _dashWidth = 7;
  static const double _dashSpace = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? _dashWidth : _dashSpace;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + len),
            paint,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.borderRadius != borderRadius;
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});
  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = copied ? ClassroomPalette.success : ClassroomPalette.gold;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            copied ? Icons.check_rounded : Icons.copy_rounded,
            key: ValueKey(copied),
            size: 18,
            color: color,
          ),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            copied ? 'Código copiado!' : 'Copiar código',
            key: ValueKey(copied),
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seção de alunos
// ─────────────────────────────────────────────────────────────────────────────

class _StudentsSection extends StatelessWidget {
  const _StudentsSection({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = classroom.studentCount;
    const max = Classroom.maxStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'ALUNOS', trailing: '$count / $max'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClassroomPalette.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClassroomPalette.border(isDark)),
          ),
          child: count == 0
              ? const _EmptyHint(
                  icon: Icons.person_add_outlined,
                  text:
                      'Nenhum aluno entrou ainda.\nCompartilhe o código da turma!',
                )
              : _CapacityBar(current: count, max: max),
        ),
      ],
    );
  }
}

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.current, required this.max});
  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = current / max;
    final barColor =
        ratio > 0.85 ? ClassroomPalette.danger : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current aluno${current == 1 ? '' : 's'} matriculado${current == 1 ? '' : 's'}',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
            Text(
              '${max - current} vagas livres',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ClassroomPalette.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 7,
          ),
        ),
      ],
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
  const _SectionLabel({required this.text, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.textMuted,
                letterSpacing: 2.2,
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ClassroomPalette.textMuted,
                ),
              ),
          ],
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