import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local — mesmo verde-teal de create_quiz_page (mesmo fluxo).
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color accent = Color(0xFF72D09C);
  static const Color accentSubtle = Color(0x1A72D09C);
  static const Color gradientEnd = Color(0xFF4EB882);

  static const Color border = Color(0x14FFFFFF);
  static const Color divider = Color(0x1AFFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);

}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de dados de cada questão
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionData {
  _QuestionData()
      : textCtrl = TextEditingController(),
        altCtrls = List.generate(4, (_) => TextEditingController()),
        correctIndex = null;

  final TextEditingController textCtrl;
  final List<TextEditingController> altCtrls;
  int? correctIndex;

  bool get isComplete =>
      textCtrl.text.trim().isNotEmpty &&
      altCtrls.every((c) => c.text.trim().isNotEmpty) &&
      correctIndex != null;

  void dispose() {
    textCtrl.dispose();
    for (final c in altCtrls) {
      c.dispose();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// Heurística #1: barra de progresso mostra quantas questões estão completas.
// Heurística #3: botão Voltar sempre visível; salvar só ativo ao completar tudo.
// Heurística #5: botão desabilitado até todas as questões estarem preenchidas.
// Heurística #6: badge de letra (A, B, C, D) torna alternativas reconhecíveis.
// Heurística #8: cards compactos, sem elementos supérfluos.
// ─────────────────────────────────────────────────────────────────────────────

class CustomizeQuizPage extends StatefulWidget {
  const CustomizeQuizPage({
    super.key,
    required this.quantity,
    required this.topic,
    required this.difficulty,
  });

  final int quantity;
  final String topic;
  final String difficulty;

  @override
  State<CustomizeQuizPage> createState() => _CustomizeQuizPageState();
}

class _CustomizeQuizPageState extends State<CustomizeQuizPage> {
  late final List<_QuestionData> _questions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _questions = List.generate(widget.quantity, (_) => _QuestionData());
  }

  @override
  void dispose() {
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  int get _completedCount => _questions.where((q) => q.isComplete).length;
  bool get _canSave => _completedCount == widget.quantity && !_saving;

  Future<void> _onSave() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    // Placeholder — substituir pela persistência real (Firestore / local)
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.solidCircleCheck,
              size: 15,
              color: _C.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Questionário salvo com sucesso!',
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.quantity == 0
        ? 0.0
        : _completedCount / widget.quantity;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Barra de topo ──────────────────────────────────────────
              _TopBar(onBack: context.pop),

              // ── Faixa de contexto + progresso ─────────────────────────
              _InfoStrip(
                topic: widget.topic,
                difficulty: widget.difficulty,
                completedCount: _completedCount,
                totalCount: widget.quantity,
                progress: progress,
              ),

              // ── Lista de questões ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.quantity; i++) ...[
                        _QuestionCard(
                          key: ValueKey(i),
                          data: _questions[i],
                          index: i,
                          onChanged: () => setState(() {}),
                        ),
                        if (i < widget.quantity - 1)
                          const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Botão fixo no rodapé ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _SaveButton(
                  enabled: _canSave,
                  saving: _saving,
                  onTap: _onSave,
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
            'Editor de Questões',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          // Espaço espelho para centralizar o título
          const SizedBox(width: 68),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info Strip — contexto da configuração + barra de progresso
// Heurística #1: progresso sempre visível sem ocupar espaço excessivo.
// ─────────────────────────────────────────────────────────────────────────────

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.topic,
    required this.difficulty,
    required this.completedCount,
    required this.totalCount,
    required this.progress,
  });

  final String topic;
  final String difficulty;
  final int completedCount;
  final int totalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final allDone = completedCount == totalCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(color: _C.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha superior: tema + chip de dificuldade
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
              _DifficultyChip(label: difficulty),
            ],
          ),
          const SizedBox(height: 8),

          // Barra de progresso + contador
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0x14FFFFFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(_C.accent),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedCount/$totalCount',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Texto de status
          Text(
            allDone
                ? 'Todas as questões preenchidas!'
                : '$completedCount de $totalCount questões completas',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: allDone ? _C.accent : _C.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _C.accentSubtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.accent,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question Card
// Heurística #1: checkmark aparece quando a questão está completa.
// Heurística #4: estilo consistente entre todos os cards.
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.data,
    required this.index,
    required this.onChanged,
  });

  final _QuestionData data;
  final int index;
  final VoidCallback onChanged;

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final complete = data.isComplete;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete
              ? _C.accent.withValues(alpha: 0.35)
              : _C.border,
          width: complete ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho do card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Número da questão
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: complete ? _C.accentSubtle : const Color(0x14FFFFFF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: complete ? _C.accent : _C.textMuted,
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
                const Spacer(),
                // Checkmark de questão completa — Nielsen #1
                AnimatedOpacity(
                  opacity: complete ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: const FaIcon(
                    FontAwesomeIcons.solidCircleCheck,
                    size: 16,
                    color: _C.accent,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _C.divider),

          // ── Campo da pergunta ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: data.textCtrl,
              onChanged: (_) => onChanged(),
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              cursorColor: _C.accent,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Digite a pergunta...',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 14,
                  color: _C.textMuted,
                ),
                filled: true,
                fillColor: AppColors.backgroundDark,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  borderSide: const BorderSide(color: _C.accent, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Cabeçalho das alternativas ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Text(
                  'ALTERNATIVAS',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.textMuted,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· toque no círculo para marcar a correta',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _C.textMuted.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          // ── Alternativas A-D ──────────────────────────────────────────
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: _C.divider,
                indent: 14,
                endIndent: 14,
              ),
            _AlternativeTile(
              letter: _letters[i],
              controller: data.altCtrls[i],
              isCorrect: data.correctIndex == i,
              onSelectCorrect: () {
                data.correctIndex = i;
                onChanged();
              },
              onChanged: onChanged,
            ),
          ],

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alternative Tile
// Heurística #6: badge de letra (A-D) + indicador visual da correta.
// ─────────────────────────────────────────────────────────────────────────────

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Indicador de resposta correta (radio) ─────────────────────
          GestureDetector(
            onTap: onSelectCorrect,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
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
                    ? const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Badge da letra ─────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
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

          // ── Campo de texto da alternativa ─────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              cursorColor: _C.accent,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Alternativa $letter',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 13,
                  color: _C.textMuted,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                border: InputBorder.none,
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: _C.border,
                    width: 1.0,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isCorrect
                        ? _C.accent
                        : _C.accent.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save Button
// Heurística #1: spinner indica salvamento em andamento.
// Heurística #5: gradiente desabilitado até todas as questões estarem prontas.
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onTap,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.40,
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
                        'Salvar Questionário',
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
