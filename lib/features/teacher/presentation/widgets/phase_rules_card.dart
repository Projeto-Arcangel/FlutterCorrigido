import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../classroom/domain/entities/phase_rules.dart';
import 'classroom_palette.dart';

/// Regras da fase, em Gerenciar fase: abertura e fechamento (opcionais),
/// a nota mínima para liberar a próxima fase (opcional) e o relógio por
/// questão (desligado por padrão).
///
/// [onSave] devolve a mensagem de erro, ou `null` se salvou.
class PhaseRulesCard extends StatefulWidget {
  const PhaseRulesCard({super.key, required this.rules, required this.onSave});

  final PhaseRules rules;
  final Future<String?> Function(PhaseRules rules) onSave;

  @override
  State<PhaseRulesCard> createState() => _PhaseRulesCardState();
}

class _PhaseRulesCardState extends State<PhaseRulesCard> {
  final _passCtrl = TextEditingController();
  bool _expanded = false;
  bool _saving = false;
  String? _error;

  DateTime? _opensAt;
  DateTime? _closesAt;
  bool _requirePass = false;
  bool _timer = false;
  String _timerLevel = 'normal';

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant PhaseRulesCard old) {
    super.didUpdateWidget(old);
    // Recarregou do servidor (ex.: depois de salvar): sem edição em curso,
    // mostra o valor novo.
    if (old.rules != widget.rules && !_dirty) _reset();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    final r = widget.rules;
    _opensAt = r.opensAt;
    _closesAt = r.closesAt;
    _requirePass = r.passPct != null;
    _passCtrl.text = r.passPct == null ? '70' : formatPct(r.passPct!);
    _timer = r.timerEnabled;
    _timerLevel = r.timerLevel;
    _error = null;
  }

  /// Nota mínima digitada (aceita vírgula); `null` se inválida.
  double? get _typedPass =>
      double.tryParse(_passCtrl.text.trim().replaceAll(',', '.'));

  PhaseRules get _draft => PhaseRules(
        opensAt: _opensAt,
        closesAt: _closesAt,
        passPct: _requirePass ? (_typedPass ?? -1) : null,
        timerEnabled: _timer,
        timerLevel: _timerLevel,
      );

  bool get _dirty => _draft != widget.rules;

  Future<void> _pick({required bool opening}) async {
    final current = opening ? _opensAt : _closesAt;
    final now = DateTime.now();
    final base = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: opening ? 'Abertura da fase' : 'Fechamento da fase',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay.fromDateTime(current)
          : (opening
              ? const TimeOfDay(hour: 7, minute: 0)
              : const TimeOfDay(hour: 23, minute: 59)),
      helpText: opening ? 'Horário de abertura' : 'Horário de fechamento',
    );
    if (time == null || !mounted) return;
    // Em UTC, como o servidor devolve: o mesmo instante compara igual
    // depois de salvar (DateTime local ≠ UTC no ==).
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute)
            .toUtc();
    setState(() {
      if (opening) {
        _opensAt = value;
      } else {
        _closesAt = value;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
      if (error == null) _expanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = widget.rules.summary();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REGRAS DA FASE',
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: ClassroomPalette.textMuted,
            letterSpacing: 1.8,
          ),
        ),
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
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ClassroomPalette.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.event_available_outlined,
                          color: ClassroomPalette.gold,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prazo, nota mínima e relógio',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ClassroomPalette.primaryText(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.isEmpty
                                  ? 'Sempre aberta · basta concluir para '
                                      'liberar a próxima'
                                  : _capitalize(summary),
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
                        turns: _expanded ? 0.5 : 0,
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
              if (_expanded) _form(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _form(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: ClassroomPalette.divider(isDark), height: 1),
          const SizedBox(height: 14),
          const _Label('ABERTURA'),
          const SizedBox(height: 6),
          _DateRow(
            value: _opensAt,
            empty: 'Aberta desde já',
            enabled: !_saving,
            onPick: () => _pick(opening: true),
            onClear: () => setState(() => _opensAt = null),
          ),
          const SizedBox(height: 14),
          const _Label('FECHAMENTO'),
          const SizedBox(height: 6),
          _DateRow(
            value: _closesAt,
            empty: 'Sem prazo',
            enabled: !_saving,
            onPick: () => _pick(opening: false),
            onClear: () => setState(() => _closesAt = null),
          ),
          const SizedBox(height: 8),
          const _Hint(
            'Fora desse período o aluno não responde a fase. Quem já '
            'respondeu continua vendo a nota.',
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _requirePass,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                      _requirePass = v;
                      _error = null;
                    }),
            activeTrackColor: AppColors.primary,
            title: Text(
              'Exigir nota mínima para liberar a próxima fase',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
          ),
          if (_requirePass) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _passCtrl,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: (_) => setState(() => _error = null),
                    decoration: InputDecoration(
                      suffixText: '%',
                      isDense: true,
                      filled: true,
                      fillColor: ClassroomPalette.fieldFill(isDark),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: _Hint('na melhor tentativa do aluno')),
              ],
            ),
            const SizedBox(height: 8),
            const _Hint(
              'O aluno pode refazer a fase até atingir; a nota oficial '
              'continua a da 1ª tentativa. Se a fase fechar, a próxima '
              'libera mesmo sem a nota.',
            ),
          ],
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _timer,
            onChanged: _saving
                ? null
                : (v) => setState(() {
                      _timer = v;
                      _error = null;
                    }),
            activeTrackColor: AppColors.primary,
            title: Text(
              'Relógio: tempo para responder cada questão',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.primaryText(isDark),
              ),
            ),
          ),
          if (_timer) ...[
            const SizedBox(height: 4),
            const _Label('TEMPO AUTOMÁTICO'),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                for (final level in timerLevels)
                  ButtonSegment(
                    value: level,
                    label: Text(_capitalize(timerLevelLabel(level))),
                  ),
              ],
              selected: {_timerLevel},
              showSelectedIcon: false,
              onSelectionChanged: _saving
                  ? null
                  : (s) => setState(() {
                        _timerLevel = s.first;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 8),
            const _Hint(
              'Sem tempo escolhido na questão, o tempo cresce com o tamanho '
              'do texto: numa questão curta, cerca de 15 s (curto), 25 s '
              '(normal) ou 40 s (longo). Para escolher o tempo de uma '
              'questão, toque no relógio dela na lista de questões. Tempo '
              'esgotado vale 0, e quem responde rápido ganha pontos extras.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ClassroomPalette.danger,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving || !_dirty ? null : () => setState(_reset),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving || !_dirty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.value,
    required this.empty,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? value;
  final String empty;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = value;
    return Row(
      children: [
        Expanded(
          child: Text(
            v == null ? empty : PhaseDateFormat.short(v),
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: v == null ? FontWeight.w500 : FontWeight.w800,
              color: v == null
                  ? ClassroomPalette.textMuted
                  : ClassroomPalette.primaryText(isDark),
            ),
          ),
        ),
        TextButton(
          onPressed: enabled ? onPick : null,
          child: Text(v == null ? 'Definir' : 'Alterar'),
        ),
        if (v != null)
          IconButton(
            tooltip: 'Remover data',
            onPressed: enabled ? onClear : null,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ClassroomPalette.textMuted,
          letterSpacing: 1.8,
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ClassroomPalette.textMuted,
          height: 1.4,
        ),
      );
}
