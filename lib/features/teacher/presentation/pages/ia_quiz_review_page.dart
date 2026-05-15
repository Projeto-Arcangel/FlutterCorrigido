import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../../../ia_quiz/domain/entities/ia_generation_result.dart';
import '../../../ia_quiz/domain/entities/ia_model_option.dart';
import '../../../ia_quiz/domain/entities/ia_question_draft.dart';
import '../../../lesson/domain/entities/question.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local — verde-teal igual ao customize_quiz (mesmo fluxo de
// salvar fase em uma turma).
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color accent = Color(0xFF72D09C);
  static const Color accentSubtle = Color(0x1A72D09C);
  static const Color gradientEnd = Color(0xFF4EB882);

  static const Color iaAccent = Color(0xFF7296D0);
  static const Color iaSubtle = Color(0x1A7296D0);

  static const Color danger = Color(0xFFFF6B6B);

  static const Color border = Color(0x14FFFFFF);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// Heurística #1: progresso (X aceitas) sempre visível no rodapé.
// Heurística #3: Voltar acessível; Salvar bloqueado se nenhuma aceita.
// Heurística #5: editar é não-destrutivo (sheet com cancelar).
// ─────────────────────────────────────────────────────────────────────────────

class IaQuizReviewPage extends ConsumerStatefulWidget {
  const IaQuizReviewPage({
    super.key,
    required this.result,
    required this.topic,
    required this.difficulty,
    this.classroomId,
  });

  final IaGenerationResult result;
  final String topic;
  final String difficulty;
  final String? classroomId;

  @override
  ConsumerState<IaQuizReviewPage> createState() => _IaQuizReviewPageState();
}

class _IaQuizReviewPageState extends ConsumerState<IaQuizReviewPage> {
  late List<IaQuestionDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.result.questions
        .map((q) => IaQuestionDraft(question: q))
        .toList();
  }

  int get _acceptedCount => _drafts.where((d) => d.isAccepted).length;
  bool get _canSave =>
      _acceptedCount > 0 &&
      !_saving &&
      (widget.classroomId?.isNotEmpty ?? false);

  void _toggleAccept(int index) {
    setState(() {
      _drafts[index] = _drafts[index]
          .copyWith(isAccepted: !_drafts[index].isAccepted);
    });
  }

  Future<void> _editDraft(int index) async {
    final updated = await showModalBottomSheet<Question>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditQuestionSheet(question: _drafts[index].question),
    );

    if (updated != null) {
      setState(() {
        _drafts[index] = _drafts[index].copyWith(
          question: updated,
          isEdited: true,
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;

    setState(() => _saving = true);

    final acceptedQuestions = _drafts
        .where((d) => d.isAccepted)
        .map((d) => d.question)
        .toList();

    final useCase = ref.read(saveClassroomQuizProvider);
    final result = await useCase(
      classroomId: widget.classroomId!,
      title: widget.topic,
      description:
          '${acceptedQuestions.length} questões · ${widget.difficulty} · IA',
      questions: acceptedQuestions,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (failure) => _showSnack(failure.message, isError: true),
      (_) {
        _showSnack('Fase criada na sua turma com sucesso!');
        // Volta para a tela do professor — pop duplo (review + form).
        context.pop();
        context.pop();
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            FaIcon(
              isError
                  ? FontAwesomeIcons.circleExclamation
                  : FontAwesomeIcons.solidCircleCheck,
              size: 15,
              color: isError ? _C.danger : _C.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(onBack: context.pop),
            _InfoStrip(
              topic: widget.topic,
              difficulty: widget.difficulty,
              modelUsed: widget.result.modelUsed,
              usedFallback: widget.result.usedFallback,
              acceptedCount: _acceptedCount,
              totalCount: _drafts.length,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    for (var i = 0; i < _drafts.length; i++) ...[
                      _QuestionReviewCard(
                        key: ValueKey(i),
                        draft: _drafts[i],
                        index: i,
                        onToggleAccept: () => _toggleAccept(i),
                        onEdit: () => _editDraft(i),
                      ),
                      if (i < _drafts.length - 1) const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SaveButton(
                enabled: _canSave,
                saving: _saving,
                acceptedCount: _acceptedCount,
                hasClassroom:
                    widget.classroomId?.isNotEmpty ?? false,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              splashColor: _C.accentSubtle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _C.accent,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Voltar',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Revisar Questões',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 68),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Strip — contexto da geração + banner de fallback se houver
// ─────────────────────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.topic,
    required this.difficulty,
    required this.modelUsed,
    required this.usedFallback,
    required this.acceptedCount,
    required this.totalCount,
  });

  final String topic;
  final String difficulty;
  final IaModelOption modelUsed;
  final bool usedFallback;
  final int acceptedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(bottom: BorderSide(color: _C.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tema + chip de dificuldade
          Row(
            children: [
              Expanded(
                child: Text(
                  topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: difficulty,
                color: _C.accent,
                subtle: _C.accentSubtle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Modelo usado + contador
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.microchip,
                size: 11,
                color: _C.iaAccent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  usedFallback
                      ? 'Fallback: ${modelUsed.label}'
                      : 'Gerado com ${modelUsed.label}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: usedFallback
                        ? _C.danger.withValues(alpha: 0.9)
                        : _C.textMuted,
                  ),
                ),
              ),
              Text(
                '$acceptedCount/$totalCount aceitas',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.subtle,
  });
  final String label;
  final Color color;
  final Color subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: subtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question Review Card
// Heurística #1: estado visual claro entre aceita/descartada.
// Heurística #6: alternativas com letras + destaque na correta.
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({
    super.key,
    required this.draft,
    required this.index,
    required this.onToggleAccept,
    required this.onEdit,
  });

  final IaQuestionDraft draft;
  final int index;
  final VoidCallback onToggleAccept;
  final VoidCallback onEdit;

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final accepted = draft.isAccepted;
    final q = draft.question;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: accepted ? 1.0 : 0.45,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accepted
                ? _C.accent.withValues(alpha: 0.35)
                : _C.border,
            width: accepted ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accepted
                          ? _C.accentSubtle
                          : const Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accepted ? _C.accent : _C.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Questão ${index + 1}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (draft.isEdited) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _C.iaSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'editada',
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _C.iaAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: onEdit,
                    tooltip: 'Editar',
                    icon: const FaIcon(
                      FontAwesomeIcons.penToSquare,
                      size: 14,
                      color: _C.iaAccent,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleAccept,
                    tooltip: accepted ? 'Descartar' : 'Aceitar',
                    icon: FaIcon(
                      accepted
                          ? FontAwesomeIcons.solidCircleCheck
                          : FontAwesomeIcons.circleXmark,
                      size: 18,
                      color: accepted ? _C.accent : _C.danger,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: _C.divider),

            // Enunciado
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Text(
                q.text,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),

            // Alternativas
            for (var i = 0; i < q.options.length; i++)
              _AlternativeRow(
                letter: _letters[i],
                text: q.options[i],
                isCorrect: i == q.correctAnswer,
              ),

            // Explicação
            if (q.explanation.isNotEmpty) ...[
              const Divider(height: 1, color: _C.divider, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.lightbulb,
                      size: 12,
                      color: _C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.explanation,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _C.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.letter,
    required this.text,
    required this.isCorrect,
  });

  final String letter;
  final String text;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isCorrect ? _C.accentSubtle : const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                letter,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isCorrect ? _C.accent : _C.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                color: isCorrect ? Colors.white : Colors.white70,
              ),
            ),
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: FaIcon(
                FontAwesomeIcons.solidCircleCheck,
                size: 12,
                color: _C.accent,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save Button
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.acceptedCount,
    required this.hasClassroom,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final int acceptedCount;
  final bool hasClassroom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = !hasClassroom
        ? 'Sem turma ativa'
        : acceptedCount == 0
            ? 'Aceite ao menos 1 questão'
            : 'Salvar $acceptedCount questões na turma';

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled && !saving ? onTap : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [_C.accent, _C.gradientEnd],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: enabled ? null : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.solidCircleCheck,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Question Sheet — bottom sheet para editar uma questão.
// Heurística #3 (controle): cancelar fecha sem salvar.
// Heurística #5 (prevenção): só permite salvar com todos os campos OK.
// ─────────────────────────────────────────────────────────────────────────────

class _EditQuestionSheet extends StatefulWidget {
  const _EditQuestionSheet({required this.question});

  final Question question;

  @override
  State<_EditQuestionSheet> createState() => _EditQuestionSheetState();
}

class _EditQuestionSheetState extends State<_EditQuestionSheet> {
  late final TextEditingController _textCtrl;
  late final List<TextEditingController> _optionCtrls;
  late final TextEditingController _explanationCtrl;
  late int _correctIndex;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.question.text);
    _optionCtrls = widget.question.options
        .map((o) => TextEditingController(text: o))
        .toList();
    _explanationCtrl = TextEditingController(text: widget.question.explanation);
    _correctIndex = widget.question.correctAnswer;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    _explanationCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _textCtrl.text.trim().isNotEmpty &&
      _optionCtrls.every((c) => c.text.trim().isNotEmpty);

  void _onSave() {
    if (!_isValid) return;
    final updated = Question(
      id: widget.question.id,
      text: _textCtrl.text.trim(),
      options: _optionCtrls.map((c) => c.text.trim()).toList(),
      correctAnswer: _correctIndex,
      explanation: _explanationCtrl.text.trim(),
      type: widget.question.type,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _C.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'Editar Questão',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('ENUNCIADO'),
                    const SizedBox(height: 6),
                    _editField(
                      controller: _textCtrl,
                      maxLines: 3,
                      hint: 'Pergunta...',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _label('ALTERNATIVAS · toque no círculo para marcar a correta'),
                    const SizedBox(height: 6),
                    for (var i = 0; i < _optionCtrls.length; i++) ...[
                      _OptionEditRow(
                        letter: ['A', 'B', 'C', 'D'][i],
                        controller: _optionCtrls[i],
                        isCorrect: i == _correctIndex,
                        onSelectCorrect: () =>
                            setState(() => _correctIndex = i),
                        onChanged: () => setState(() {}),
                      ),
                      if (i < _optionCtrls.length - 1)
                        const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 16),
                    _label('EXPLICAÇÃO (OPCIONAL)'),
                    const SizedBox(height: 6),
                    _editField(
                      controller: _explanationCtrl,
                      maxLines: 3,
                      hint: 'Justificativa pedagógica da resposta correta',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _isValid ? _onSave : null,
              child: AnimatedOpacity(
                opacity: _isValid ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.accent, _C.gradientEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Salvar alterações',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _C.textMuted,
          letterSpacing: 1.6,
        ),
      );

  Widget _editField({
    required TextEditingController controller,
    required int maxLines,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      maxLines: maxLines,
      minLines: 1,
      cursorColor: _C.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: _C.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.accent, width: 1.4),
        ),
      ),
    );
  }
}

class _OptionEditRow extends StatelessWidget {
  const _OptionEditRow({
    required this.letter,
    required this.controller,
    required this.isCorrect,
    required this.onSelectCorrect,
    required this.onChanged,
  });

  final String letter;
  final TextEditingController controller;
  final bool isCorrect;
  final VoidCallback onSelectCorrect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onSelectCorrect,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 20,
            height: 20,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect ? _C.accent : Colors.transparent,
              border: Border.all(
                color: isCorrect
                    ? _C.accent
                    : _C.textMuted.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: isCorrect
                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: isCorrect ? _C.accentSubtle : const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              letter,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCorrect ? _C.accent : _C.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            cursorColor: _C.accent,
            decoration: InputDecoration(
              hintText: 'Alternativa $letter',
              hintStyle: GoogleFonts.nunito(
                fontSize: 12,
                color: _C.textMuted,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: _C.border),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _C.border),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _C.accent, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}