import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';
import '../../../lesson/domain/entities/question_kinds.dart';

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

/// Nível do relógio: o tempo de cada questão cresce com o tamanho do
/// texto e é ajustado pelo nível (servidor: `question_time_limit`).
const timerLevels = ['short', 'normal', 'long'];

String timerLevelLabel(String level) => switch (level) {
      'short' => 'curto',
      'long' => 'longo',
      _ => 'normal',
    };

/// Tempos que o professor pode escolher para uma questão (o banco aceita
/// de 5 s a 10 min).
const questionTimeChoices = [10, 15, 20, 30, 45, 60, 90, 120, 180, 300, 600];

/// Tempo automático de uma questão (sem tempo escolhido): ~20 s + 1 s a
/// cada 12 caracteres (enunciado, alternativas, itens e dicas) + o tempo
/// de mexer ([extraSeconds], ver `Question.extraSeconds`), ajustado pelo
/// nível, em múltiplos de 5, entre 15 s e 5 min. Mesma conta do servidor
/// (`question_time_limit`), que é quem vale; aqui é só para mostrar.
int autoTimeLimit(
  String text,
  List<String> options,
  String level, {
  List<String> contentTexts = const [],
  int extraSeconds = 0,
}) {
  int sum(List<String> xs) => xs.fold<int>(0, (s, o) => s + o.length);
  final chars = text.length + sum(options) + sum(contentTexts);
  final mult = switch (level) {
    'short' => 0.6,
    'long' => 1.5,
    _ => 1.0,
  };
  final raw = (20 + chars / 12.0 + extraSeconds) * mult;
  return ((raw / 5).round() * 5).clamp(15, 300);
}

/// [autoTimeLimit] de uma questão salva.
int autoTimeLimitOf(Question q, String level) => autoTimeLimit(
      q.text,
      q.options,
      level,
      contentTexts: q.contentTexts,
      extraSeconds: q.extraSeconds,
    );

/// "45 s", "1 min", "1 min 30 s".
String formatSeconds(int seconds) {
  if (seconds < 60) return '$seconds s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min $s s';
}

/// Prazo, nota mínima e relógio de uma fase, definidos pelo professor.
/// Tudo opcional: sem datas a fase fica sempre aberta; sem nota mínima,
/// basta concluir a fase para liberar a próxima; sem relógio, sem tempo.
class PhaseRules extends Equatable {
  const PhaseRules({
    this.opensAt,
    this.closesAt,
    this.passPct,
    this.timerEnabled = false,
    this.timerLevel = 'normal',
  });

  /// A partir de quando a fase aceita respostas.
  final DateTime? opensAt;

  /// Até quando a fase aceita respostas.
  final DateTime? closesAt;

  /// Nota (%) que o aluno precisa tirar — na melhor tentativa — para
  /// liberar a próxima fase.
  final double? passPct;

  /// Relógio por questão; tempo esgotado vale 0.
  final bool timerEnabled;

  /// 'short' | 'normal' | 'long' (guardado mesmo com o relógio desligado).
  final String timerLevel;

  bool get isEmpty =>
      opensAt == null && closesAt == null && passPct == null && !timerEnabled;

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
    if (!timerLevels.contains(timerLevel)) {
      return 'Escolha o tempo do relógio: curto, normal ou longo.';
    }
    return null;
  }

  /// Resumo curto para listas: "abre 20/10 às 8h · até 25/10 · mín. 70%".
  String summary({DateTime? now}) {
    final parts = [
      if (opensAt != null) 'abre ${PhaseDateFormat.short(opensAt!, now: now)}',
      if (closesAt != null) 'até ${PhaseDateFormat.short(closesAt!, now: now)}',
      if (passPct != null) 'mín. ${formatPct(passPct!)}%',
      if (timerEnabled) 'relógio ${timerLevelLabel(timerLevel)}',
    ];
    return parts.join(' · ');
  }

  @override
  List<Object?> get props =>
      [opensAt, closesAt, passPct, timerEnabled, timerLevel];
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
