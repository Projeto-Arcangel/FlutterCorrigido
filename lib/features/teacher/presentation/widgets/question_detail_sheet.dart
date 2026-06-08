import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../lesson/domain/entities/question.dart';
import 'classroom_palette.dart';

/// Bottom sheet que mostra uma questão **completa** (enunciado, imagem,
/// alternativas com a correta destacada e explicação) e permite **editá-la**.
///
/// Retorna o [Question] atualizado via `Navigator.pop` quando o professor
/// salva; `null` se fechar sem salvar. Os campos de imagem são **preservados**
/// (não são editáveis aqui) para não apagar a imagem de questões do ENEM.
class QuestionDetailSheet extends StatefulWidget {
  const QuestionDetailSheet({
    super.key,
    required this.question,
    required this.order,
  });

  final Question question;

  /// Posição da questão na fase (1-based) — só para o título.
  final int order;

  @override
  State<QuestionDetailSheet> createState() => _QuestionDetailSheetState();
}

class _QuestionDetailSheetState extends State<QuestionDetailSheet> {
  static const _letters = ['A', 'B', 'C', 'D', 'E'];

  bool _editing = false;

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

  String _letterFor(int i) => i < _letters.length ? _letters[i] : '${i + 1}';

  bool get _isValid =>
      _textCtrl.text.trim().isNotEmpty &&
      _optionCtrls.every((c) => c.text.trim().isNotEmpty);

  void _resetEdits() {
    _textCtrl.text = widget.question.text;
    for (var i = 0; i < _optionCtrls.length; i++) {
      _optionCtrls[i].text = widget.question.options[i];
    }
    _explanationCtrl.text = widget.question.explanation;
    _correctIndex = widget.question.correctAnswer;
  }

  void _save() {
    if (!_isValid) return;
    // Preserva imagem/tipo/id — só texto, alternativas, correta e explicação
    // são editáveis aqui.
    final updated = Question(
      id: widget.question.id,
      text: _textCtrl.text.trim(),
      options: _optionCtrls.map((c) => c.text.trim()).toList(),
      correctAnswer: _correctIndex,
      explanation: _explanationCtrl.text.trim(),
      type: widget.question.type,
      imageUrl: widget.question.imageUrl,
      imageAuthor: widget.question.imageAuthor,
      imageSource: widget.question.imageSource,
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                  color: ClassroomPalette.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Cabeçalho
            Row(
              children: [
                Text(
                  _editing
                      ? 'Editar questão ${widget.order}'
                      : 'Questão ${widget.order}',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ClassroomPalette.primaryText(isDark),
                  ),
                ),
                const Spacer(),
                if (_editing)
                  TextButton(
                    onPressed: () => setState(() {
                      _resetEdits();
                      _editing = false;
                    }),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ClassroomPalette.textMuted,
                      ),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Editar',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: _editing ? _buildEdit(isDark) : _buildView(isDark),
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _isValid ? _save : null,
                child: AnimatedOpacity(
                  opacity: _isValid ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
          ],
        ),
      ),
    );
  }

  // ── Modo VISUALIZAÇÃO ───────────────────────────────────────────────────

  Widget _buildView(bool isDark) {
    final q = widget.question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (q.hasImage) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _showFullImage(context, q.imageUrl!, isDark),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                q.imageUrl!,
                fit: BoxFit.contain,
                height: 180,
                width: double.infinity,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  alignment: Alignment.center,
                  color: isDark ? Colors.white10 : Colors.black12,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: ClassroomPalette.textMuted,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          if ((q.imageAuthor ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                (q.imageSource ?? '').isNotEmpty
                    ? '${q.imageAuthor} — ${q.imageSource}'
                    : q.imageAuthor!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: ClassroomPalette.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        // Enunciado
        Text(
          q.text.trim().isEmpty ? 'Questão sem enunciado' : _stripUrls(q.text),
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: ClassroomPalette.primaryText(isDark),
          ),
        ),
        const SizedBox(height: 14),
        // Alternativas
        for (var i = 0; i < q.options.length; i++)
          _ViewAlternative(
            letter: _letterFor(i),
            text: q.options[i],
            isCorrect: i == q.correctAnswer,
            isDark: isDark,
          ),
        // Explicação
        if (q.explanation.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: Color(0xFF4CAF50),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    q.explanation.trim(),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: ClassroomPalette.primaryText(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Modo EDIÇÃO ─────────────────────────────────────────────────────────

  Widget _buildEdit(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.question.hasImage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'A imagem da questão é mantida ao salvar.',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: ClassroomPalette.textMuted,
              ),
            ),
          ),
        const _EditLabel('ENUNCIADO'),
        const SizedBox(height: 6),
        _editField(
          controller: _textCtrl,
          maxLines: 4,
          hint: 'Pergunta...',
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        const _EditLabel(
          'ALTERNATIVAS · toque no círculo para marcar a correta',
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _optionCtrls.length; i++) ...[
          _OptionEditRow(
            letter: _letterFor(i),
            controller: _optionCtrls[i],
            isCorrect: i == _correctIndex,
            isDark: isDark,
            onSelectCorrect: () => setState(() => _correctIndex = i),
            onChanged: () => setState(() {}),
          ),
          if (i < _optionCtrls.length - 1) const SizedBox(height: 6),
        ],
        const SizedBox(height: 16),
        const _EditLabel('EXPLICAÇÃO (OPCIONAL)'),
        const SizedBox(height: 6),
        _editField(
          controller: _explanationCtrl,
          maxLines: 3,
          hint: 'Justificativa pedagógica da resposta correta',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required int maxLines,
    required String hint,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ClassroomPalette.primaryText(isDark),
      ),
      maxLines: maxLines,
      minLines: 1,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: ClassroomPalette.textMuted,
        ),
        filled: true,
        fillColor: ClassroomPalette.fieldFill(isDark),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

// ── Alternativa (modo visualização) ─────────────────────────────────────────

class _ViewAlternative extends StatelessWidget {
  const _ViewAlternative({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isDark,
  });

  final String letter;
  final String text;
  final bool isCorrect;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CAF50);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect
            ? green.withValues(alpha: 0.12)
            : ClassroomPalette.fieldFill(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCorrect
              ? green.withValues(alpha: 0.45)
              : ClassroomPalette.border(isDark),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color:
                  isCorrect ? green : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                letter,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isCorrect ? Colors.white : AppColors.primary,
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
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
          ),
          if (isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle_rounded, size: 16, color: green),
            ),
        ],
      ),
    );
  }
}

// ── Linha de alternativa (modo edição) ──────────────────────────────────────

class _OptionEditRow extends StatelessWidget {
  const _OptionEditRow({
    required this.letter,
    required this.controller,
    required this.isCorrect,
    required this.isDark,
    required this.onSelectCorrect,
    required this.onChanged,
  });

  final String letter;
  final TextEditingController controller;
  final bool isCorrect;
  final bool isDark;
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
              color: isCorrect ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: isCorrect
                    ? AppColors.primary
                    : ClassroomPalette.textMuted.withValues(alpha: 0.4),
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
            color: isCorrect
                ? AppColors.primary.withValues(alpha: 0.15)
                : ClassroomPalette.fieldFill(isDark),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              letter,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color:
                    isCorrect ? AppColors.primary : ClassroomPalette.textMuted,
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
              color: ClassroomPalette.primaryText(isDark),
            ),
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: 'Alternativa $letter',
              hintStyle: GoogleFonts.nunito(
                fontSize: 12,
                color: ClassroomPalette.textMuted,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: ClassroomPalette.border(isDark)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ClassroomPalette.textMuted,
          letterSpacing: 1.6,
        ),
      );
}

// ── Imagem em tela cheia ────────────────────────────────────────────────────

void _showFullImage(BuildContext context, String url, bool isDark) {
  showDialog<void>(
    context: context,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Scaffold(
        backgroundColor:
            isDark ? Colors.black.withValues(alpha: 0.92) : Colors.black87,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Remove URLs soltas do texto (artefatos de import do ENEM) na exibição.
String _stripUrls(String text) {
  var out = text.replaceAll(
    RegExp(r'https?://\S+', caseSensitive: false),
    '',
  );
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return out.trim();
}
