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

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color gold        = Color(0xFFE8A020);
  static const Color goldDim     = Color(0x80E8A020);
  static const Color goldSubtle  = Color(0x1AE8A020);
  static const Color divider     = Color(0x1AFFFFFF);
  static const Color textMuted   = Color(0xFF8FA3AE);
  static const Color cardBorder  = Color(0x1AFFFFFF);
  static const Color danger      = Color(0xFFFF5963);
  static const Color dangerSubtle= Color(0x26FF5963);
  static const Color success     = Color(0xFF72D09C);
}

// ─────────────────────────────────────────────────────────────────────────────
// Página principal
//
// Heurísticas de Nielsen:
//   #1  Visibilidade: AppBar "Minha Turma" e back button contextualizam.
//   #2  Correspondência: o código da turma é exibido exatamente como o
//       professor o compartilha — não como um hash ou UUID interno.
//   #3  Controle: "Copiar código" com feedback visual imediato.
//   #4  Consistência: paleta, tipografia Nunito e padrão de card idênticos
//       ao restante do app.
//   #5  Prevenção de erros: validação inline no formulário de criação.
//   #6  Reconhecimento: ícones + rótulos em cada seção.
//   #7  Eficiência: cópia com 1 toque, sem necessidade de selecionar texto.
//   #8  Minimalismo: hierarquia visual clara; informação prioritária primeiro.
// ─────────────────────────────────────────────────────────────────────────────

class ClassroomListPage extends ConsumerStatefulWidget {
  const ClassroomListPage({super.key});

  @override
  ConsumerState<ClassroomListPage> createState() => _ClassroomListPageState();
}

class _ClassroomListPageState extends ConsumerState<ClassroomListPage>
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) return const SizedBox.shrink();

    final asyncClassrooms =
        ref.watch(teacherClassroomsProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: asyncClassrooms.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _ErrorView(
            message: 'Não foi possível carregar a turma.',
            onRetry: () =>
                ref.invalidate(teacherClassroomsProvider(user.uid)),
          ),
          data: (classrooms) => classrooms.isEmpty
              ? _CreateView(
                  userId: user.uid,
                  displayName: user.displayName ?? user.email ?? 'Professor',
                )
              : _DetailView(
                  classroom: classrooms.first,
                  fades: _fades,
                  slides: _slides,
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Minha Turma',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon:
              const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot animado reutilizável
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
// Rótulo de seção com contagem opcional
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
                color: _C.textMuted,
                letterSpacing: 2.2,
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.textMuted,
                ),
              ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo de formulário dark
// ─────────────────────────────────────────────────────────────────────────────

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      style: GoogleFonts.nunito(fontSize: 15, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.nunito(fontSize: 14, color: _C.textMuted),
        hintStyle: GoogleFonts.nunito(fontSize: 14, color: _C.textMuted),
        filled: true,
        fillColor: AppColors.backgroundDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _C.danger, width: 2),
        ),
        errorStyle: GoogleFonts.nunito(fontSize: 12, color: _C.danger),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio → formulário para criar a primeira turma
// ─────────────────────────────────────────────────────────────────────────────

class _CreateView extends ConsumerStatefulWidget {
  const _CreateView({
    required this.userId,
    required this.displayName,
  });
  final String userId;
  final String displayName;

  @override
  ConsumerState<_CreateView> createState() => _CreateViewState();
}

class _CreateViewState extends ConsumerState<_CreateView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final result = await ref.read(createClassroomProvider)(
      name: _nameCtrl.text.trim(),
      teacherId: widget.userId,
      teacherName: widget.displayName,
      description: _descCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            f.message,
            style: GoogleFonts.nunito(color: Colors.white),
          ),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      ),
      (_) {
        ref.invalidate(teacherClassroomsProvider(widget.userId));
        ref.invalidate(teacherDashboardProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          children: [
            // Ícone decorativo
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: _C.goldSubtle,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                color: _C.gold,
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gere o código de acesso e compartilhe com seus alunos para que eles entrem na turma.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _C.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Formulário
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _DarkTextField(
                    controller: _nameCtrl,
                    label: 'Nome da turma',
                    hint: 'Ex: 3ºA · Ciências Humanas',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe o nome da turma'
                            : (v.trim().length < 3
                                ? 'Mínimo 3 caracteres'
                                : null),
                  ),
                  const SizedBox(height: 12),
                  _DarkTextField(
                    controller: _descCtrl,
                    label: 'Descrição (opcional)',
                    hint: 'Ex: Turma do 3º ano, período vespertino',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _create,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  _loading ? 'Criando…' : 'Criar Turma',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.gold,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _C.gold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
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
// Vista de detalhe da turma
// ─────────────────────────────────────────────────────────────────────────────

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({
    required this.classroom,
    required this.fades,
    required this.slides,
  });
  final Classroom classroom;
  final List<Animation<double>> fades;
  final List<Animation<Offset>> slides;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.classroom.code));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final classroom = widget.classroom;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // ── 0: header da turma ────────────────────────────────────────────
        _Animated(
          fade: widget.fades[0],
          slide: widget.slides[0],
          child: _ClassroomHeaderCard(classroom: classroom),
        ),
        const SizedBox(height: 24),

        // ── 1: card do código ─────────────────────────────────────────────
        _Animated(
          fade: widget.fades[1],
          slide: widget.slides[1],
          child: Column(
            children: [
              _CodeCard(code: classroom.code),
              const SizedBox(height: 12),
              _CopyButton(copied: _copied, onTap: _copyCode),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ── 2: alunos ─────────────────────────────────────────────────────
        _Animated(
          fade: widget.fades[2],
          slide: widget.slides[2],
          child: _StudentsSection(classroom: classroom),
        ),
        const SizedBox(height: 32),

        // ── 3: resultados ─────────────────────────────────────────────────
        _Animated(
          fade: widget.fades[3],
          slide: widget.slides[3],
          child: _ResultsSection(classroomId: classroom.id),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card cabeçalho: nome, descrição e metadados da turma
// ─────────────────────────────────────────────────────────────────────────────

class _ClassroomHeaderCard extends StatelessWidget {
  const _ClassroomHeaderCard({required this.classroom});
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone da turma
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.goldSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: _C.gold,
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
                        color: Colors.white,
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
                          color: _C.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chips de status
          Row(
            children: [
              _StatusChip(
                icon: Icons.people_outline_rounded,
                label: '${classroom.studentCount}/${Classroom.maxStudents} alunos',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              _StatusChip(
                icon: classroom.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.cancel_outlined,
                label: classroom.isActive ? 'Ativa' : 'Inativa',
                color:
                    classroom.isActive ? _C.success : _C.textMuted,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
// Card do código da turma (elemento central do design)
// ─────────────────────────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final spacedCode = code.split('').join(' ');

    return CustomPaint(
      foregroundPainter: const _DashedBorderPainter(
        color: _C.gold,
        borderRadius: 20,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'CÓDIGO DA TURMA',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.goldDim,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              spacedCode,
              style: GoogleFonts.nunito(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: _C.gold,
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
                color: _C.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter de borda tracejada (sem dependências externas)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Botão de copiar código com feedback visual
// Heurística #3 – Visibilidade de status: ícone e texto mudam ao copiar.
// ─────────────────────────────────────────────────────────────────────────────

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onTap});
  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = copied ? _C.success : _C.gold;
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
    final count = classroom.studentCount;
    const max = Classroom.maxStudents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          text: 'ALUNOS',
          trailing: '$count / $max',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.cardBorder),
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
    final ratio = current / max;
    final barColor =
        ratio > 0.85 ? _C.danger : AppColors.primary;

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
                color: Colors.white,
              ),
            ),
            Text(
              '${max - current} vagas livres',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seção de resultados (lê diretamente do Firestore via provider)
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsSection extends ConsumerWidget {
  const _ResultsSection({required this.classroomId});
  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResults =
        ref.watch(classroomResultsProvider(classroomId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'RESULTADOS'),
        const SizedBox(height: 10),
        asyncResults.when(
          loading: () => Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.cardBorder),
            ),
            child: const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.cardBorder),
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
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.cardBorder),
                ),
                child: const _EmptyHint(
                  icon: Icons.bar_chart_outlined,
                  text:
                      'Nenhum aluno completou atividades ainda.\nCrie questões para começar!',
                ),
              );
            }

            final sorted = [...results]
              ..sort(
                (a, b) => b.percentage.compareTo(a.percentage),
              );

            return Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.cardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < sorted.length; i++) ...[
                    _ResultTile(result: sorted[i]),
                    if (i < sorted.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(color: _C.divider, height: 1,),
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

// ─────────────────────────────────────────────────────────────────────────────
// Tile de resultado individual
// ─────────────────────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final ClassroomResult result;

  Color get _scoreColor {
    if (result.percentage >= 0.7) return _C.success;
    if (result.percentage >= 0.4) return _C.gold;
    return _C.danger;
  }

  String get _initials {
    final parts = result.studentName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Avatar com iniciais
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

          // Nome + acertos
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.correctAnswers} / ${result.totalQuestions} acertos',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _C.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Badge de porcentagem
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _scoreColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _scoreColor.withValues(alpha: 0.4),
              ),
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
// Componentes utilitários
// ─────────────────────────────────────────────────────────────────────────────

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
            Icon(icon, color: _C.textMuted.withValues(alpha: 0.5), size: 32),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _C.dangerSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  color: _C.danger,
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
                  color: Colors.white,
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
                  side: const BorderSide(
                    color: AppColors.primary,
                  ),
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