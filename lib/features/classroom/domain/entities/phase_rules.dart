import 'package:equatable/equatable.dart';

/// Situação da fase para o aluno agora, calculada no servidor
/// (`student_phase_states`).
enum PhaseStatus {
  /// Ainda não abriu (antes de [PhaseRules.opensAt]).
  scheduled,

  /// Aceita respostas.
  open,

  /// Já fechou (depois de [PhaseRules.closesAt]): quem respondeu vê a nota,
  /// quem não respondeu não responde mais.
  closed;

  static PhaseStatus fromDb(Object? value) => switch (value) {
        'scheduled' => PhaseStatus.scheduled,
        'closed' => PhaseStatus.closed,
        _ => PhaseStatus.open,
      };
}

/// Prazo e nota mínima de uma fase, definidos pelo professor. Tudo
/// opcional: sem datas a fase fica sempre aberta; sem nota mínima, basta
/// concluir a fase para liberar a próxima.
class PhaseRules extends Equatable {
  const PhaseRules({this.opensAt, this.closesAt, this.passPct});

  /// A partir de quando a fase aceita respostas.
  final DateTime? opensAt;

  /// Até quando a fase aceita respostas.
  final DateTime? closesAt;

  /// Nota (%) que o aluno precisa tirar — na melhor tentativa — para
  /// liberar a próxima fase.
  final double? passPct;

  bool get isEmpty => opensAt == null && closesAt == null && passPct == null;

  /// Por que não dá para salvar (`null` = pode). Mesmas regras do banco.
  String? validate() {
    final opens = opensAt;
    final closes = closesAt;
    if (opens != null && closes != null && !closes.isAfter(opens)) {
      return 'O fechamento precisa ser depois da abertura.';
    }
    final pass = passPct;
    if (pass != null && (pass <= 0 || pass > 100)) {
      return 'A nota mínima vai de 1% a 100%.';
    }
    return null;
  }

  /// Resumo curto para listas: "abre 20/10 às 8h · até 25/10 · mín. 70%".
  String summary({DateTime? now}) {
    final parts = [
      if (opensAt != null) 'abre ${PhaseDateFormat.short(opensAt!, now: now)}',
      if (closesAt != null) 'até ${PhaseDateFormat.short(closesAt!, now: now)}',
      if (passPct != null) 'mín. ${formatPct(passPct!)}%',
    ];
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => [opensAt, closesAt, passPct];
}

/// "70" para 70.0; "72,5" para 72.5.
String formatPct(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString().replaceAll('.', ',');
}

/// Datas da fase no horário do aparelho.
abstract final class PhaseDateFormat {
  /// "20/10 às 8h", "20/10 às 8h30"; com o ano quando não é o ano atual:
  /// "20/10/2027 às 8h".
  static String short(DateTime value, {DateTime? now}) {
    final d = value.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final year = d.year == current.year ? '' : '/${d.year}';
    final minutes = d.minute == 0 ? '' : two(d.minute);
    return '${two(d.day)}/${two(d.month)}$year às ${d.hour}h$minutes';
  }
}
