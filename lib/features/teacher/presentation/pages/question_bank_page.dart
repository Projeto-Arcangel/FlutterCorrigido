import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/question_bank.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';
import '../../../plans/presentation/providers/plan_providers.dart';
import '../widgets/classroom_palette.dart';

abstract class _C {
  static const accent = Color(0xFFB28AD9);
  static const textMuted = Color(0xFF8FA3AE);

  static Color cardBg(bool d) => d ? AppColors.surfaceDark : Colors.white;
  static Color border(bool d) => d ? const Color(0x14FFFFFF) : Colors.black12;
  static Color text(bool d) => d ? Colors.white : AppColors.textPrimary;
  static Color fieldFill(bool d) =>
      d ? AppColors.backgroundDark : const Color(0xFFF1F4F8);
}

/// Máximo por cópia (o mesmo da RPC copy_questions_to_phase).
const _kMaxCopy = 100;

/// "Reutilizar minhas questões": escolhe questões das outras fases e turmas
/// do professor e COPIA para esta fase (editar a cópia não muda a original).
/// As cópias contam no limite de questões guardadas do plano. Daqui o
/// professor também exclui questões: elas somem da fase em que estão.
///
/// Devolve `true` se copiou alguma questão.
class QuestionBankPage extends ConsumerStatefulWidget {
  const QuestionBankPage({
    super.key,
    required this.phaseId,
    required this.phaseTitle,
  });

  final String phaseId;
  final String phaseTitle;

  @override
  ConsumerState<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends ConsumerState<QuestionBankPage> {
  final _search = TextEditingController();
  String _query = '';
  String? _classroomId;
  bool _showInPhase = false;

  /// Seleção em ordem de toque: as cópias entram nessa ordem.
  final _selected = <String>[];
  bool _copying = false;
  bool _deleting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(BankEntry entry) {
    setState(() {
      if (_selected.remove(entry.id)) return;
      if (_selected.length >= _kMaxCopy) {
        _snack('Copie no máximo $_kMaxCopy questões por vez.', isError: true);
        return;
      }
      _selected.add(entry.id);
    });
  }

  Future<void> _copy() async {
    if (_selected.isEmpty || _copying) return;
    setState(() => _copying = true);
    final count = _selected.length;
    final result =
        await ref.read(classroomRepositoryProvider).copyQuestionsToPhase(
              phaseId: widget.phaseId,
              questionIds: List.of(_selected),
            );
    if (!mounted) return;
    setState(() => _copying = false);
    // Copiou ou não, o uso do plano pode ter mudado.
    ref.invalidate(myPlanProvider);
    result.fold(
      (failure) => _snack(failure.message, isError: true),
      (copied) {
        ref.invalidate(questionBankProvider);
        Navigator.of(context).pop(true);
        _snack(
          copied == 1
              ? '1 questão copiada para a fase.'
              : '${copied == 0 ? count : copied} questões copiadas para a '
                  'fase.',
        );
      },
    );
  }

  /// Exclui a questão só da fase desta linha (as cópias em outras fases
  /// continuam), depois de confirmar.
  Future<void> _delete(BankEntry entry) async {
    if (_deleting || _copying) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteQuestionDialog(entry: entry),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await ref
        .read(classroomRepositoryProvider)
        .deleteBankQuestions(questionIds: [entry.id]);
    if (!mounted) return;
    setState(() => _deleting = false);
    result.fold(
      (failure) => _snack(failure.message, isError: true),
      (_) {
        _selected.remove(entry.id);
        // A lista e o espaço do plano mudaram.
        ref
          ..invalidate(questionBankProvider)
          ..invalidate(myPlanProvider);
        _snack(
          'Questão excluída de ${entry.question.classroomName} · '
          '${entry.question.phaseTitle}.',
        );
      },
    );
  }

  /// O ScaffoldMessenger é o do app: o aviso continua visível depois de
  /// voltar para a fase.
  void _snack(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        backgroundColor: ClassroomPalette.cardBg(isDark),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: Duration(seconds: isError ? 6 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bankAsync = ref.watch(questionBankProvider);
    final plan = ref.watch(myPlanProvider).valueOrNull;
    final storageLeft = plan?.storageRemaining;
    final overStorage = storageLeft != null && _selected.length > storageLeft;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Reutilizar minhas questões',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _C.text(isDark),
          ),
        ),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: Icon(Icons.chevron_left, color: _C.text(isDark), size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: bankAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            text: ErrorMessages.from(
              e,
              fallback: 'Não foi possível carregar suas questões.',
            ),
            action: 'Tentar de novo',
            onAction: () => ref.invalidate(questionBankProvider),
          ),
          data: (all) {
            final entries = buildBankEntries(all, phaseId: widget.phaseId);
            if (entries.isEmpty) {
              return const _Message(
                text: 'Você ainda não tem questões em outras fases. As '
                    'questões que você criar ou gerar nas suas turmas '
                    'aparecem aqui para reutilizar.',
              );
            }
            final classrooms = <String, String>{
              for (final e in entries)
                e.question.classroomId: e.question.classroomName,
            };
            final visible = filterBank(
              entries,
              query: _query,
              classroomId: _classroomId,
              showInPhase: _showInPhase,
            );
            final hiddenInPhase = entries.where((e) => e.inThisPhase).length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Escolha as questões e copie para "${widget.phaseTitle}". '
                    'São cópias: editar uma não muda a outra.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.textMuted,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar no enunciado, alternativas ou fase',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: _C.fieldFill(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    children: [
                      _Chip(
                        label: 'Todas as turmas',
                        selected: _classroomId == null,
                        onTap: () => setState(() => _classroomId = null),
                      ),
                      for (final c in classrooms.entries)
                        _Chip(
                          label: c.value,
                          selected: _classroomId == c.key,
                          onTap: () => setState(() => _classroomId = c.key),
                        ),
                    ],
                  ),
                ),
                if (hiddenInPhase > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CheckboxListTile(
                      dense: true,
                      value: _showInPhase,
                      onChanged: (v) =>
                          setState(() => _showInPhase = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        hiddenInPhase == 1
                            ? 'Mostrar a que já está nesta fase'
                            : 'Mostrar as $hiddenInPhase que já estão nesta '
                                'fase',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: visible.isEmpty
                      ? const _Message(
                          text: 'Nenhuma questão encontrada com esses '
                              'filtros.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final e = visible[i];
                            return _BankTile(
                              entry: e,
                              selected: _selected.contains(e.id),
                              enabled: !_copying && !_deleting,
                              onTap: () => _toggle(e),
                              onDelete: () => _delete(e),
                            );
                          },
                        ),
                ),
                _CopyBar(
                  count: _selected.length,
                  storageLeft: storageLeft,
                  copying: _copying,
                  onCopy: overStorage ? null : _copy,
                  onClear: () => setState(_selected.clear),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  const _BankTile({
    required this.entry,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onDelete,
  });

  final BankEntry entry;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final q = entry.question;
    final where = '${q.classroomName} · ${q.phaseTitle}';
    return Semantics(
      checked: selected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? _C.accent.withValues(alpha: 0.12)
                : _C.cardBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _C.accent : _C.border(isDark),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                activeColor: _C.accent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.text(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      where,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.textMuted,
                      ),
                    ),
                    if (entry.inThisPhase ||
                        q.aiGenerated ||
                        q.question.type.usesContent) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (q.question.type.usesContent)
                            _Badge(
                              text: q.question.type.label,
                              color: const Color(0xFF26A69A),
                            ),
                          if (entry.inThisPhase)
                            const _Badge(
                              text: 'Já está nesta fase',
                              color: Color(0xFFE0A23B),
                            ),
                          if (q.aiGenerated)
                            const _Badge(
                              text: 'Gerada com IA',
                              color: Color(0xFF7296D0),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Excluir questão',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: ClassroomPalette.danger,
                  size: 20,
                ),
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirma a exclusão dizendo de qual fase a questão vai sumir.
class _DeleteQuestionDialog extends StatelessWidget {
  const _DeleteQuestionDialog({required this.entry});

  final BankEntry entry;

  @override
  Widget build(BuildContext context) {
    final q = entry.question;
    final textStyle = GoogleFonts.nunito(fontSize: 14, height: 1.4);

    return AlertDialog(
      title: Text(
        'Excluir esta questão?',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              q.question.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Ela vai sumir da fase '),
                  TextSpan(
                    text: '${q.classroomName} · ${q.phaseTitle}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: '. As cópias em outras fases continuam.',
                  ),
                ],
              ),
              style: textStyle,
            ),
            const SizedBox(height: 12),
            Text(
              'Os alunos deixam de ver a questão nessa fase. Não dá para '
              'desfazer.',
              style: textStyle,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: ClassroomPalette.danger,
          ),
          child: const Text('Excluir'),
        ),
      ],
    );
  }
}

class _CopyBar extends StatelessWidget {
  const _CopyBar({
    required this.count,
    required this.storageLeft,
    required this.copying,
    required this.onCopy,
    required this.onClear,
  });

  final int count;
  final int? storageLeft;
  final bool copying;
  final VoidCallback? onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final left = storageLeft;
    final over = left != null && count > left;
    final String info;
    if (left == null) {
      info = '';
    } else if (left == 0) {
      info = 'Seu plano não tem espaço para novas questões. Apague questões '
          'que você não usa mais ou mude de plano.';
    } else if (over) {
      info = 'Só cabem mais $left no seu plano: desmarque '
          '${count - left}.';
    } else {
      info = 'Cabem mais $left questões no seu plano.';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: _C.cardBg(isDark),
        border: Border(top: BorderSide(color: _C.border(isDark))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                info,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: over || left == 0
                      ? const Color(0xFFE0795B)
                      : _C.textMuted,
                ),
              ),
            ),
          Row(
            children: [
              if (count > 0)
                TextButton(
                  onPressed: copying ? null : onClear,
                  child: const Text('Limpar'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: count == 0 || copying ? null : onCopy,
                style: FilledButton.styleFrom(backgroundColor: _C.accent),
                icon: copying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const FaIcon(FontAwesomeIcons.copy, size: 14),
                label: Text(
                  count == 0
                      ? 'Escolha as questões'
                      : count == 1
                          ? 'Copiar 1 questão'
                          : 'Copiar $count questões',
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _C.textMuted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
