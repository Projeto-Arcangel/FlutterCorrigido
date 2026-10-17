import '../domain/entities/classroom_phase.dart';
import '../domain/entities/phase_rules.dart';

/// O que acontece quando o aluno toca numa fase da trilha.
enum PhaseTapAction {
  /// Abre a fase para responder.
  play,

  /// Não abre: mostra [PhaseAccess.message].
  message,

  /// Fase encerrada que o aluno respondeu: mostra a nota, sem responder.
  showResult,
}

class PhaseAccess {
  const PhaseAccess.play()
      : action = PhaseTapAction.play,
        message = null;
  const PhaseAccess.message(String this.message)
      : action = PhaseTapAction.message;
  const PhaseAccess.showResult()
      : action = PhaseTapAction.showResult,
        message = null;

  final PhaseTapAction action;
  final String? message;
}

/// Decide o toque na fase a partir do estado calculado no servidor.
/// [previous] é a fase anterior na trilha (para explicar o bloqueio).
PhaseAccess phaseAccess(
  ClassroomPhase phase, {
  ClassroomPhase? previous,
  DateTime? now,
}) {
  if (phase.status == PhaseStatus.closed) {
    if (phase.completed) return const PhaseAccess.showResult();
    final closes = phase.closesAt;
    return PhaseAccess.message(
      closes == null
          ? 'Esta fase foi encerrada.'
          : 'Esta fase foi encerrada em '
              '${PhaseDateFormat.short(closes, now: now)}.',
    );
  }
  if (phase.locked) return PhaseAccess.message(lockedMessage(previous));
  if (phase.status == PhaseStatus.scheduled) {
    final opens = phase.opensAt;
    return PhaseAccess.message(
      opens == null
          ? 'Esta fase ainda não abriu.'
          : 'Esta fase abre em ${PhaseDateFormat.short(opens, now: now)}.',
    );
  }
  return const PhaseAccess.play();
}

/// Por que a fase está bloqueada: falta a nota mínima na anterior, ou
/// falta concluir a anterior.
String lockedMessage(ClassroomPhase? previous) {
  if (previous != null && previous.needsPassScore) {
    return 'Tire pelo menos ${formatPct(previous.passPct!)}% na fase '
        '"${previous.title}" para liberar esta.';
  }
  return 'Conclua a fase anterior para liberar esta.';
}

/// Linha curta abaixo do nome da fase na trilha (`null` = nada a dizer).
String? phaseCaption(ClassroomPhase phase, {DateTime? now}) {
  if (phase.status == PhaseStatus.closed) return 'Encerrada';
  final opens = phase.opensAt;
  if (phase.status == PhaseStatus.scheduled && opens != null) {
    return 'Abre ${PhaseDateFormat.short(opens, now: now)}';
  }
  if (phase.inProgress && !phase.locked) return 'Em andamento';
  if (phase.needsPassScore) {
    return 'Precisa de ${formatPct(phase.passPct!)}%';
  }
  final closes = phase.closesAt;
  if (closes != null && !phase.locked) {
    return 'Até ${PhaseDateFormat.short(closes, now: now)}';
  }
  return null;
}
