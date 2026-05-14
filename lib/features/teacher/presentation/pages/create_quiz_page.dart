import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local
// Verde-teal — distinto do azul-IA (ia_quiz_page) e do verde do header.
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color accent = Color(0xFF72D09C);
  static const Color accentSubtle = Color(0x1A72D09C);
  static const Color gradientEnd = Color(0xFF4EB882);

  static const Color history = Color(0xFFB8906A);
  static const Color historySubtle = Color(0x1AB8906A);

  static const Color border = Color(0x14FFFFFF);
  static const Color textMuted = Color(0xFF8FA3AE);
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelos de apresentação
// ─────────────────────────────────────────────────────────────────────────────

enum _Difficulty {
  easy(1, 'Fácil'),
  medium(2, 'Médio'),
  hard(3, 'Difícil'),
  expert(4, 'Expert');

  const _Difficulty(this.stars, this.label);
  final int stars;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// Heurística #1: contagem dinâmica de questões visível o tempo todo.
// Heurística #3: botão Voltar sempre acessível.
// Heurística #5: botão desabilitado enquanto tema estiver vazio.
// Heurística #8: hierarquia visual clara, sem elementos supérfluos.
// ─────────────────────────────────────────────────────────────────────────────

class CreateQuizPage extends ConsumerStatefulWidget {
  const CreateQuizPage({super.key});

  @override
  ConsumerState<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends ConsumerState<CreateQuizPage> {
  final _topicCtrl = TextEditingController();
  final _focusNode = FocusNode();

  _Difficulty _difficulty = _Difficulty.medium;
  double _quantity = 5;

  bool get _canSave => _topicCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_canSave) return;
    _focusNode.unfocus();

    // Obtém o ID da primeira sala do professor.
    // É necessário aguardar a resolução do provider para garantir
    // que o classroomId esteja disponível antes de navegar.
    final user = ref.read(authStateProvider).valueOrNull;
    String? classroomId;

    if (user != null) {
      // Tenta obter do cache primeiro (síncrono)
      final cached = ref.read(teacherClassroomsProvider(user.id));
      classroomId = cached.valueOrNull?.firstOrNull?.id;

      // Se não resolveu ainda, busca de forma assíncrona
      if (classroomId == null) {
        try {
          final classrooms =
              await ref.read(teacherClassroomsProvider(user.id).future);
          classroomId = classrooms.firstOrNull?.id;
        } catch (_) {
          // Continua sem classroomId — o fluxo trata isso
        }
      }
    }

    if (!mounted) return;

    await context.push(
      AppRoutes.teacherCustomizeQuiz,
      extra: <String, dynamic>{
        'quantity': _quantity.round(),
        'topic': _topicCtrl.text.trim(),
        'difficulty': _difficulty.label,
        'classroomId': classroomId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onBack: context.pop),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ScreenTitle(),
                      const SizedBox(height: 32),

                      // Disciplina fixa — somente História por ora
                      _sectionLabel('DISCIPLINA'),
                      const SizedBox(height: 10),
                      const _SubjectBadge(),
                      const SizedBox(height: 28),

                      // Tema específico
                      _sectionLabel('TEMA ESPECÍFICO'),
                      const SizedBox(height: 10),
                      _TopicField(
                        controller: _topicCtrl,
                        focusNode: _focusNode,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 28),

                      // Dificuldade
                      _sectionLabel('DIFICULDADE'),
                      const SizedBox(height: 10),
                      _DifficultySelector(
                        selected: _difficulty,
                        onSelect: (d) => setState(() => _difficulty = d),
                      ),
                      const SizedBox(height: 28),

                      // Quantidade — label + contador dinâmico (Nielsen #1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionLabel('QUANTIDADE'),
                          Text(
                            '${_quantity.round()} questões',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _QuantitySlider(
                        value: _quantity,
                        onChanged: (v) => setState(() => _quantity = v),
                      ),
                      const SizedBox(height: 28),

                      // Resumo da configuração — Nielsen #1 (feedback contínuo)
                      if (_topicCtrl.text.trim().isNotEmpty) ...[
                        _ConfigSummary(
                          topic: _topicCtrl.text.trim(),
                          difficulty: _difficulty,
                          quantity: _quantity.round(),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Botão principal
                      _SaveButton(
                        enabled: _canSave,
                        saving: false,
                        onTap: _onSave,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.textMuted,
          letterSpacing: 2.0,
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(24),
          splashColor: _C.accentSubtle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen Title
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _C.accentSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.penToSquare,
              color: _C.accent,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criar Questões',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              Text(
                'Configure e escreva suas próprias questões',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _C.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Badge — História (fixo)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectBadge extends StatelessWidget {
  const _SubjectBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.historySubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _C.history.withValues(alpha: 0.40),
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.buildingColumns,
            size: 13,
            color: _C.history,
          ),
          const SizedBox(width: 8),
          Text(
            'História',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.history,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Topic Field
// ─────────────────────────────────────────────────────────────────────────────

class _TopicField extends StatelessWidget {
  const _TopicField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      style: GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      cursorColor: _C.accent,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'Ex: Revolução Francesa, Segunda Guerra, colonização...',
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _C.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty Selector
// Heurística #6: estrelas + rótulo tornam cada nível reconhecível.
// ─────────────────────────────────────────────────────────────────────────────

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({
    required this.selected,
    required this.onSelect,
  });

  final _Difficulty selected;
  final ValueChanged<_Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _Difficulty.values.asMap().entries.map((entry) {
        final isLast = entry.key == _Difficulty.values.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: _DifficultyOption(
              difficulty: entry.value,
              isSelected: selected == entry.value,
              onTap: () => onSelect(entry.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  final _Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _C.accentSubtle : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _C.accent.withValues(alpha: 0.55)
                : _C.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(difficulty.stars, (_) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: FaIcon(
                    FontAwesomeIcons.solidStar,
                    size: 10,
                    color: isSelected
                        ? _C.accent
                        : _C.textMuted.withValues(alpha: 0.35),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              difficulty.label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? _C.accent : _C.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity Slider
// ─────────────────────────────────────────────────────────────────────────────

class _QuantitySlider extends StatelessWidget {
  const _QuantitySlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: _C.accent,
        inactiveTrackColor: AppColors.surfaceDark,
        thumbColor: _C.accent,
        overlayColor: _C.accentSubtle,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      child: Slider(
        value: value,
        min: 1,
        max: 20,
        divisions: 19,
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config Summary — aparece dinamicamente ao preencher o tema
// Heurística #1: feedback em tempo real consolidando as escolhas feitas.
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigSummary extends StatelessWidget {
  const _ConfigSummary({
    required this.topic,
    required this.difficulty,
    required this.quantity,
  });

  final String topic;
  final _Difficulty difficulty;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: topic.isEmpty ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.accentSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _C.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.listCheck,
                  size: 14,
                  color: _C.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic,
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
                    '$quantity questões · ${difficulty.label}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _C.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save Button
// Heurística #1: estado de loading indica progresso.
// Heurística #5: desabilitado sem tema — previne envio vazio.
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
                        FontAwesomeIcons.penToSquare,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Começar a Criar',
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
