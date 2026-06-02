import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_phase.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../../../enem/presentation/pages/enem_bank_page.dart';
import '../../../lesson/domain/entities/question.dart';
import '../widgets/classroom_palette.dart';

/// Tela de gerenciamento de uma fase específica de uma turma.
///
/// Permite ao professor:
///   - editar o nome e a descrição da fase;
///   - adicionar questões à fase via IA ou manualmente;
///   - puxar questões do ENEM (em breve);
///   - reorganizar a ordem das questões;
///   - excluir a fase.
///
/// A criação de questões aqui é **sempre vinculada a esta fase**
/// (passando `phaseId`), eliminando o problema antigo em que as
/// questões eram criadas na "última turma" ou em uma fase nova
/// solta.
class PhaseManagementPage extends ConsumerStatefulWidget {
  const PhaseManagementPage({
    super.key,
    required this.classroom,
    required this.phase,
  });

  final Classroom classroom;
  final ClassroomPhase phase;

  @override
  ConsumerState<PhaseManagementPage> createState() =>
      _PhaseManagementPageState();
}

class _PhaseManagementPageState extends ConsumerState<PhaseManagementPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _detailsExpanded = false;
  bool _savingDetails = false;

  String _initialName = '';
  String _initialDesc = '';

  @override
  void initState() {
    super.initState();
    _initialName = widget.phase.title;
    _initialDesc = widget.phase.description;
    _nameCtrl = TextEditingController(text: _initialName);
    _descCtrl = TextEditingController(text: _initialDesc);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Encontra a fase atualizada no provider — após salvar detalhes ou
  /// adicionar questões, o widget reflete o estado atual.
  ClassroomPhase _currentPhase(List<ClassroomPhase>? phases) {
    if (phases == null) return widget.phase;
    return phases.firstWhere(
      (p) => p.id == widget.phase.id,
      orElse: () => widget.phase,
    );
  }

  bool get _detailsDirty =>
      _nameCtrl.text.trim() != _initialName.trim() ||
      _descCtrl.text.trim() != _initialDesc.trim();

  bool get _canSaveDetails =>
      _nameCtrl.text.trim().isNotEmpty &&
      _detailsDirty &&
      !_savingDetails;

  Future<void> _saveDetails() async {
    if (!_canSaveDetails) return;
    setState(() => _savingDetails = true);

    final useCase = ref.read(updatePhaseProvider);
    final result = await useCase(
      classroomId: widget.classroom.id,
      phaseId: widget.phase.id,
      title: _nameCtrl.text,
      description: _descCtrl.text,
    );

    if (!mounted) return;
    setState(() => _savingDetails = false);

    result.fold(
      (f) => _showSnack(f.message, isError: true),
      (_) {
        _showSnack('Detalhes da fase atualizados.');
        setState(() {
          _initialName = _nameCtrl.text.trim();
          _initialDesc = _descCtrl.text.trim();
          _detailsExpanded = false;
        });
        ref.invalidate(classroomPhasesProvider(widget.classroom.id));
      },
    );
  }

  Future<void> _openIaFlow() async {
    await context.push(
      AppRoutes.teacherIaQuiz,
      extra: <String, dynamic>{
        'classroomId': widget.classroom.id,
        'phaseId': widget.phase.id,
        'phaseTitle': widget.phase.title,
        'subject': widget.phase.description,
      },
    );
    if (!mounted) return;
    ref.invalidate(classroomPhasesProvider(widget.classroom.id));
  }

  Future<void> _openCustomFlow() async {
    await context.push(
      AppRoutes.teacherCreateQuiz,
      extra: <String, dynamic>{
        'classroomId': widget.classroom.id,
        'phaseId': widget.phase.id,
        'phaseTitle': widget.phase.title,
        'subject': widget.phase.description,
      },
    );
    if (!mounted) return;
    ref.invalidate(classroomPhasesProvider(widget.classroom.id));
  }

  Future<void> _openEnemBank() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EnemBankPage(
          classroomId: widget.classroom.id,
          phaseId: widget.phase.id,
          phaseTitle: widget.phase.title,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(classroomPhasesProvider(widget.classroom.id));
  }

  Future<void> _onDeletePhase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeletePhaseDialog(phase: widget.phase),
    );
    if (confirmed != true || !mounted) return;

    final useCase = ref.read(deletePhaseProvider);
    final result = await useCase(
      classroomId: widget.classroom.id,
      phaseId: widget.phase.id,
    );

    if (!mounted) return;
    result.fold(
      (f) => _showSnack(f.message, isError: true),
      (_) {
        ref.invalidate(classroomPhasesProvider(widget.classroom.id));
        Navigator.of(context).pop();
      },
    );
  }

  Future<void> _persistQuestionsOrder(
    List<Question> reordered,
  ) async {
    final useCase = ref.read(reorderQuestionsInPhaseProvider);
    final result = await useCase(
      classroomId: widget.classroom.id,
      phaseId: widget.phase.id,
      orderedQuestionIds: reordered.map((q) => q.id).toList(),
    );
    if (!mounted) return;
    result.fold(
      (f) => _showSnack(f.message, isError: true),
      (_) => ref.invalidate(classroomPhasesProvider(widget.classroom.id)),
    );
  }

  Future<void> _onDeleteQuestion(Question q) async {
    final useCase = ref.read(deleteQuestionFromPhaseProvider);
    final result = await useCase(
      classroomId: widget.classroom.id,
      phaseId: widget.phase.id,
      questionId: q.id,
    );
    if (!mounted) return;
    result.fold(
      (f) => _showSnack(f.message, isError: true),
      (_) {
        _showSnack('Questão removida da fase.');
        ref.invalidate(classroomPhasesProvider(widget.classroom.id));
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(
              isError
                  ? FontAwesomeIcons.circleExclamation
                  : FontAwesomeIcons.solidCircleCheck,
              size: 14,
              color:
                  isError ? ClassroomPalette.danger : ClassroomPalette.success,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: ClassroomPalette.cardBg(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncPhases =
        ref.watch(classroomPhasesProvider(widget.classroom.id));
    final phase = _currentPhase(asyncPhases.valueOrNull);

    return Scaffold(
      appBar: _buildAppBar(context, isDark),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _PhaseHeaderCard(phase: phase, classroom: widget.classroom),
            const SizedBox(height: 24),
            _DetailsSection(
              nameCtrl: _nameCtrl,
              descCtrl: _descCtrl,
              expanded: _detailsExpanded,
              dirty: _detailsDirty,
              saving: _savingDetails,
              canSave: _canSaveDetails,
              onToggle: () =>
                  setState(() => _detailsExpanded = !_detailsExpanded),
              onChanged: () => setState(() {}),
              onSave: _saveDetails,
              onCancel: () => setState(() {
                _nameCtrl.text = _initialName;
                _descCtrl.text = _initialDesc;
                _detailsExpanded = false;
              }),
            ),
            const SizedBox(height: 24),
            _AddQuestionsSection(
              onIa: _openIaFlow,
              onCustom: _openCustomFlow,
              onEnem: _openEnemBank,
            ),
            const SizedBox(height: 24),
            _QuestionsSection(
              phaseQuestions: phase.questions,
              onReorder: _persistQuestionsOrder,
              onDelete: _onDeleteQuestion,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Gerenciar fase',
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
        IconButton(
          tooltip: 'Excluir fase',
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: ClassroomPalette.danger,
          ),
          onPressed: _onDeletePhase,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de cabeçalho com nome da fase + turma
// ─────────────────────────────────────────────────────────────────────────────

class _PhaseHeaderCard extends StatelessWidget {
  const _PhaseHeaderCard({required this.phase, required this.classroom});

  final ClassroomPhase phase;
  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClassroomPalette.cardBg(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ClassroomPalette.border(isDark)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.layers_outlined,
              color: AppColors.primary,
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
                  phase.title.isEmpty ? 'Fase sem nome' : phase.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ClassroomPalette.primaryText(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${classroom.name} · '
                  '${phase.totalQuestions} '
                  'quest${phase.totalQuestions == 1 ? 'ão' : 'ões'}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ClassroomPalette.textMuted,
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

// ─────────────────────────────────────────────────────────────────────────────
// Seção "Detalhes" — nome + descrição (expansível)
//
// Heurísticas:
//  - #3 (controle): editar é opt-in (botão "Editar" expande o form).
//  - #5 (prevenção): salvar só fica ativo com alterações válidas;
//    cancelar restaura o estado inicial.
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.nameCtrl,
    required this.descCtrl,
    required this.expanded,
    required this.dirty,
    required this.saving,
    required this.canSave,
    required this.onToggle,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final bool expanded;
  final bool dirty;
  final bool saving;
  final bool canSave;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'DETALHES DA FASE'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClassroomPalette.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClassroomPalette.border(isDark)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nome e disciplina',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    ClassroomPalette.primaryText(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              expanded
                                  ? 'Edite os dados e salve as alterações'
                                  : 'Toque para editar o nome ou a disciplina',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: ClassroomPalette.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: ClassroomPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        color: ClassroomPalette.divider(isDark),
                        height: 1,
                      ),
                      const SizedBox(height: 14),
                      _SmallLabel(text: 'NOME DA FASE'),
                      const SizedBox(height: 6),
                      _PhaseField(
                        controller: nameCtrl,
                        hint: 'Ex: Revolução Industrial',
                        maxLines: 1,
                        onChanged: onChanged,
                      ),
                      const SizedBox(height: 14),
                      _SmallLabel(text: 'DISCIPLINA'),
                      const SizedBox(height: 6),
                      _PhaseField(
                        controller: descCtrl,
                        hint: 'Ex: história, matemática, física...',
                        maxLines: 1,
                        onChanged: onChanged,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving || !dirty ? null : onCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ClassroomPalette.textMuted,
                                side: BorderSide(
                                  color:
                                      ClassroomPalette.border(isDark),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: canSave ? onSave : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Salvar',
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhaseField extends StatelessWidget {
  const _PhaseField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 2,
      cursorColor: AppColors.primary,
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
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seção "Adicionar questões" — três opções
// ─────────────────────────────────────────────────────────────────────────────

class _AddQuestionsSection extends StatelessWidget {
  const _AddQuestionsSection({
    required this.onIa,
    required this.onCustom,
    required this.onEnem,
  });

  final VoidCallback onIa;
  final VoidCallback onCustom;
  final VoidCallback onEnem;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'ADICIONAR QUESTÕES'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClassroomPalette.cardBg(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClassroomPalette.border(isDark)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _AddOptionTile(
                icon: FontAwesomeIcons.wandMagicSparkles,
                iconColor: const Color(0xFF7296D0),
                iconBg: const Color(0x1A7296D0),
                title: 'Criar questões com IA',
                subtitle: 'Gere por tema e dificuldade automaticamente',
                onTap: onIa,
              ),
              _AddDivider(),
              _AddOptionTile(
                icon: FontAwesomeIcons.penToSquare,
                iconColor: const Color(0xFF72D09C),
                iconBg: const Color(0x1A72D09C),
                title: 'Criar questões próprias',
                subtitle: 'Escreva e marque a alternativa correta',
                onTap: onCustom,
              ),
              _AddDivider(),
              _AddOptionTile(
                icon: FontAwesomeIcons.graduationCap,
                iconColor: ClassroomPalette.gold,
                iconBg: ClassroomPalette.goldSubtle,
                title: 'Puxar questões do ENEM',
                subtitle: 'Importe da base oficial do exame',
                onTap: onEnem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      color: ClassroomPalette.divider(isDark),
      height: 1,
      indent: 16,
      endIndent: 16,
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.disabled = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: disabled ? 0.72 : 1.0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: FaIcon(icon, color: iconColor, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ClassroomPalette.primaryText(isDark),
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ClassroomPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: iconColor.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de questões + reordenação
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionsSection extends StatefulWidget {
  const _QuestionsSection({
    required this.phaseQuestions,
    required this.onReorder,
    required this.onDelete,
  });

  final List<Question> phaseQuestions;
  final ValueChanged<List<Question>> onReorder;
  final ValueChanged<Question> onDelete;

  @override
  State<_QuestionsSection> createState() => _QuestionsSectionState();
}

class _QuestionsSectionState extends State<_QuestionsSection> {
  bool _reordering = false;
  late List<Question> _local;

  @override
  void initState() {
    super.initState();
    _local = [...widget.phaseQuestions];
  }

  @override
  void didUpdateWidget(covariant _QuestionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phaseQuestions != widget.phaseQuestions) {
      _local = [...widget.phaseQuestions];
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      var to = newIndex;
      if (to > oldIndex) to -= 1;
      final moved = _local.removeAt(oldIndex);
      _local.insert(to, moved);
    });
    widget.onReorder(_local);
  }

  Future<void> _confirmDelete(Question q, int order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteQuestionDialog(order: order),
    );
    if (confirmed == true) widget.onDelete(q);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canReorder = _local.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(text: 'QUESTÕES DA FASE'),
                  const SizedBox(height: 2),
                  Text(
                    _local.isEmpty
                        ? 'Adicione questões usando uma das opções acima'
                        : '${_local.length} '
                            'quest${_local.length == 1 ? 'ão' : 'ões'} '
                            'na fase',
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
              _ToggleButton(
                icon: _reordering
                    ? Icons.check_rounded
                    : Icons.swap_vert_rounded,
                label: _reordering ? 'Concluir' : 'Reordenar',
                color: _reordering
                    ? ClassroomPalette.success
                    : AppColors.primary,
                onTap: () => setState(() => _reordering = !_reordering),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_local.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ClassroomPalette.cardBg(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClassroomPalette.border(isDark)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  color: ClassroomPalette.textMuted.withValues(alpha: 0.6),
                  size: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhuma questão nessa fase ainda.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ClassroomPalette.textMuted,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
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
              onReorder: _reorder,
              proxyDecorator: (child, _, __) => Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
              itemBuilder: (_, i) {
                final q = _local[i];
                return _QuestionTile(
                  key: ValueKey(q.id),
                  index: i,
                  question: q,
                  reordering: _reordering,
                  onDelete: () => _confirmDelete(q, i + 1),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.reordering,
    required this.onDelete,
  });

  final int index;
  final Question question;
  final bool reordering;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
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
                  child: Text(
                    question.text.isEmpty
                        ? 'Questão sem enunciado'
                        : question.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ClassroomPalette.primaryText(isDark),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (reordering)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: ClassroomPalette.textMuted,
                        size: 20,
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Excluir questão',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: ClassroomPalette.danger,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
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
      color: color.withValues(alpha: 0.15),
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

// ─────────────────────────────────────────────────────────────────────────────
// Diálogos de confirmação
// ─────────────────────────────────────────────────────────────────────────────

class _DeletePhaseDialog extends StatelessWidget {
  const _DeletePhaseDialog({required this.phase});
  final ClassroomPhase phase;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: ClassroomPalette.cardBg(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Excluir fase?',
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ClassroomPalette.primaryText(isDark),
        ),
      ),
      content: Text(
        'Você vai apagar "${phase.title}" e suas '
        '${phase.totalQuestions} '
        'quest${phase.totalQuestions == 1 ? 'ão' : 'ões'}.\n\n'
        'Esta ação é irreversível.',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ClassroomPalette.textMuted,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontSize: 13,
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteQuestionDialog extends StatelessWidget {
  const _DeleteQuestionDialog({required this.order});
  final int order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: ClassroomPalette.cardBg(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Excluir questão $order?',
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ClassroomPalette.primaryText(isDark),
        ),
      ),
      content: Text(
        'A questão será removida da fase. '
        'Esta ação não pode ser desfeita.',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: ClassroomPalette.textMuted,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontSize: 13,
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labels utilitários
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.text});
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
