import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../../domain/entities/enem_question.dart';
import '../providers/enem_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta local — mesmo verde-teal do editor de questões (mesmo fluxo de fase).
// ─────────────────────────────────────────────────────────────────────────────

abstract class _C {
  static const Color accent = Color(0xFF72D09C);
  static const Color accentSubtle = Color(0x1A72D09C);
  static const Color gradientEnd = Color(0xFF4EB882);
  static const Color textMuted = Color(0xFF8FA3AE);
  static const Color warn = Color(0xFFE0A23B);

  static Color cardBg(bool d) => d ? AppColors.surfaceDark : Colors.white;
  static Color adaptiveBorder(bool d) =>
      d ? const Color(0x14FFFFFF) : Colors.black12;
  static Color primaryText(bool d) => d ? Colors.white : AppColors.textPrimary;
  static Color fieldFill(bool d) => d ? AppColors.backgroundDark : AppColors.surface;
  static Color disabledBg(bool d) =>
      d ? AppColors.surfaceDark : const Color(0xFFE0E0E0);
}

const _kYears = [2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009];

const _kDisciplines = <String, String>{
  'ciencias-humanas': 'Ciências Humanas',
  'ciencias-natureza': 'Ciências da Natureza',
  'linguagens': 'Linguagens',
  'matematica': 'Matemática',
};

// ─────────────────────────────────────────────────────────────────────────────
// Página — Banco de questões do ENEM
// ─────────────────────────────────────────────────────────────────────────────

class EnemBankPage extends ConsumerStatefulWidget {
  const EnemBankPage({
    super.key,
    required this.classroomId,
    required this.phaseId,
    this.phaseTitle,
  });

  final String classroomId;
  final String phaseId;
  final String? phaseTitle;

  @override
  ConsumerState<EnemBankPage> createState() => _EnemBankPageState();
}

class _EnemBankPageState extends ConsumerState<EnemBankPage> {
  EnemQuery _query = const EnemQuery();
  final Map<String, EnemQuestion> _selected = {};
  final _searchCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(EnemQuestion q) {
    setState(() {
      if (_selected.containsKey(q.id)) {
        _selected.remove(q.id);
      } else {
        _selected[q.id] = q;
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);

    final questions = _selected.values.map((q) => q.toQuestion()).toList();
    final useCase = ref.read(addQuestionsToPhaseProvider);
    final result = await useCase(
      classroomId: widget.classroomId,
      phaseId: widget.phaseId,
      questions: questions,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (failure) => _snack(failure.message, isError: true),
      (_) {
        ref.invalidate(classroomPhasesProvider(widget.classroomId));
        _snack('${questions.length} quest${questions.length == 1 ? 'ão adicionada' : 'ões adicionadas'} à fase!');
        Navigator.of(context).pop();
      },
    );
  }

  void _snack(String msg, {bool isError = false}) {
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
              color: isError ? const Color(0xFFFF6B6B) : _C.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _C.cardBg(isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncResults = ref.watch(enemSearchProvider(_query));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                onBack: () => Navigator.of(context).maybePop(),
                phaseTitle: widget.phaseTitle,
              ),
              _buildFilters(isDark),
              Expanded(
                child: asyncResults.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: _C.accent),
                  ),
                  error: (e, _) => const _MessageView(
                    icon: FontAwesomeIcons.triangleExclamation,
                    text: 'Não foi possível carregar as questões.\nTente novamente.',
                  ),
                  data: (questions) {
                    if (questions.isEmpty) {
                      return const _MessageView(
                        icon: FontAwesomeIcons.magnifyingGlass,
                        text: 'Nenhuma questão encontrada.\nAjuste os filtros acima.',
                      );
                    }
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: questions.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        if (i == questions.length) {
                          return _ResultFooter(count: questions.length, limit: _query.limit);
                        }
                        final q = questions[i];
                        return _EnemCard(
                          question: q,
                          selected: _selected.containsKey(q.id),
                          onTap: () => _toggle(q),
                        );
                      },
                    );
                  },
                ),
              ),
              _BottomBar(
                count: _selected.length,
                saving: _saving,
                onAdd: _addSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filtros ────────────────────────────────────────────────────────────────
  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _C.cardBg(isDark),
        border: Border(bottom: BorderSide(color: _C.adaptiveBorder(isDark))),
      ),
      child: Column(
        children: [
          // Busca
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) =>
                setState(() => _query = _query.copyWith(search: v.trim())),
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _C.primaryText(isDark),
            ),
            cursorColor: _C.accent,
            decoration: InputDecoration(
              hintText: 'Buscar no enunciado...',
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: _C.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: _C.textMuted, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: _C.textMuted,
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = _query.copyWith(search: ''));
                      },
                    ),
              filled: true,
              fillColor: _C.fieldFill(isDark),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _C.adaptiveBorder(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.accent, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Ano + Disciplina
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<int?>(
                  isDark: isDark,
                  hint: 'Ano',
                  value: _query.year,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos os anos')),
                    for (final y in _kYears)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (v) => setState(() => _query = v == null
                      ? _query.copyWith(clearYear: true)
                      : _query.copyWith(year: v),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<String?>(
                  isDark: isDark,
                  hint: 'Disciplina',
                  value: _query.discipline,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    for (final e in _kDisciplines.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => v == null
                      ? _query = _query.copyWith(clearDiscipline: true)
                      : _query = _query.copyWith(discipline: v),),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Idioma + toggle "sem imagem"
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String?>(
                  isDark: isDark,
                  hint: 'Idioma',
                  value: _query.language,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Qualquer idioma')),
                    DropdownMenuItem(value: '', child: Text('Sem idioma')),
                    DropdownMenuItem(value: 'ingles', child: Text('Inglês')),
                    DropdownMenuItem(value: 'espanhol', child: Text('Espanhol')),
                  ],
                  onChanged: (v) => setState(() => v == null
                      ? _query = _query.copyWith(clearLanguage: true)
                      : _query = _query.copyWith(language: v),),
                ),
              ),
              const SizedBox(width: 8),
              _NoImageToggle(
                value: _query.onlyWithoutImages,
                onChanged: (v) =>
                    setState(() => _query = _query.copyWith(onlyWithoutImages: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, this.phaseTitle});

  final VoidCallback onBack;
  final String? phaseTitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(24),
              splashColor: _C.accentSubtle,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, color: _C.accent, size: 14),
                    SizedBox(width: 6),
                    Text('Voltar',
                        style: TextStyle(
                            color: _C.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,),),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Banco ENEM',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              if (phaseTitle != null && phaseTitle!.isNotEmpty)
                Text(
                  'fase: ${phaseTitle!}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.textMuted,
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
// Dropdown de filtro estilizado
// ─────────────────────────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.isDark,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final bool isDark;
  final String hint;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _C.fieldFill(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.adaptiveBorder(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.textMuted),
          dropdownColor: _C.cardBg(isDark),
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _C.primaryText(isDark),
          ),
          hint: Text(hint,
              style: GoogleFonts.nunito(fontSize: 13, color: _C.textMuted),),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle "somente sem imagem"
// ─────────────────────────────────────────────────────────────────────────────

class _NoImageToggle extends StatelessWidget {
  const _NoImageToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: value ? _C.accentSubtle : _C.fieldFill(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? _C.accent.withValues(alpha: 0.55) : _C.adaptiveBorder(isDark),
            width: value ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 18,
              color: value ? _C.accent : _C.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Sem imagem',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value ? _C.accent : _C.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de imagem em tela cheia
// ─────────────────────────────────────────────────────────────────────────────

void _openEnemImage(BuildContext context, String url, bool isDark) {
  showDialog<void>(
    context: context,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Scaffold(
        backgroundColor: isDark
            ? Colors.black.withValues(alpha: 0.92)
            : Colors.black87,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined,
                            color: Colors.white38, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Imagem indisponível',
                          style: GoogleFonts.nunito(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
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
                      child: Icon(Icons.close_rounded,
                          color: Colors.white70, size: 22),
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

// ─────────────────────────────────────────────────────────────────────────────
// Card de questão
// ─────────────────────────────────────────────────────────────────────────────

class _EnemCard extends StatelessWidget {
  const _EnemCard({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  final EnemQuestion question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = question;
    return Material(
      color: _C.cardBg(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? _C.accent.withValues(alpha: 0.6)
                  : _C.adaptiveBorder(isDark),
              width: selected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  _Chip(label: 'ENEM ${q.year}', color: _C.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: _Chip(
                      label: q.disciplineLabel,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Q${q.index}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _C.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? _C.accent : _C.textMuted.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Miniaturas de imagens do enunciado
              if (q.hasImage && q.contextImages.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: q.contextImages.map((url) {
                    return GestureDetector(
                      onTap: () => _openEnemImage(context, url, isDark),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _C.adaptiveBorder(isDark),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: _C.accent.withValues(alpha: 0.5),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.black.withValues(alpha: 0.05),
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                  size: 18,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Enunciado
              if (q.cleanContext.isNotEmpty)
                Text(
                  q.cleanContext,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: _C.primaryText(isDark),
                  ),
                ),
              if (q.alternativesIntroduction.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  q.alternativesIntroduction.trim(),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.primaryText(isDark),
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Alternativas (correta destacada)
              ...q.alternatives.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.letter})',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: a.isCorrect ? _C.accent : _C.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a.text.isEmpty ? '(imagem)' : a.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight:
                                  a.isCorrect ? FontWeight.w700 : FontWeight.w500,
                              color: a.isCorrect
                                  ? _C.accent
                                  : _C.primaryText(isDark).withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.nunito(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rodapé da lista + barra inferior fixa
// ─────────────────────────────────────────────────────────────────────────────

class _ResultFooter extends StatelessWidget {
  const _ResultFooter({required this.count, required this.limit});
  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final capped = count >= limit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          capped
              ? 'Mostrando as primeiras $count questões — refine os filtros.'
              : '$count quest${count == 1 ? 'ão encontrada' : 'ões encontradas'}.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _C.textMuted,
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.count,
    required this.saving,
    required this.onAdd,
  });

  final int count;
  final bool saving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = count > 0 && !saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: _C.cardBg(isDark),
        border: Border(top: BorderSide(color: _C.adaptiveBorder(isDark))),
      ),
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: enabled ? onAdd : null,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [_C.accent, _C.gradientEnd],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: enabled ? null : _C.disabledBg(isDark),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white,),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.plus,
                            size: 15, color: Colors.white,),
                        const SizedBox(width: 10),
                        Text(
                          count == 0
                              ? 'Selecione questões'
                              : 'Adicionar $count à fase',
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
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 32, color: _C.textMuted.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
