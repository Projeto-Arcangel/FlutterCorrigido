import '../../classroom/domain/entities/classroom_phase.dart';
import '../../classroom/domain/entities/classroom_result.dart';
import '../../classroom/domain/entities/phase_attempt.dart';

/// Notas do painel do professor, a partir dos resultados por fase e da
/// lista da turma. Regra da turma: fase FECHADA sem entrega vale 0 (e
/// conta na média); fase ABERTA sem entrega fica como pendente.

/// Fase que já fechou: quem não entregou não pode mais entregar.
bool phaseIsClosed(ClassroomPhase p, {DateTime? now}) =>
    p.closesAt != null && (now ?? DateTime.now()).isAfter(p.closesAt!);

/// Notas no escopo escolhido:
/// - [phaseId] → as notas da fase; se ela já fechou, quem não entregou
///   entra com 0 ("não entregou");
/// - trilha geral (`null`) → média ponderada por aluno sobre TODAS as fases
///   com questões (fase não feita = 0), usando o peso de cada fase. Quem
///   não entregou nada entra com 0 quando alguma fase já fechou.
List<ClassroomResult> gradebookScores({
  required List<ClassroomPhase> phases,
  required List<ClassroomResult> rows,
  required List<ClassroomMember> members,
  String? phaseId,
  DateTime? now,
}) {
  if (phaseId != null) {
    final scoped = rows.where((r) => r.phaseId == phaseId).toList();
    final phase = phases.where((p) => p.id == phaseId).firstOrNull;
    if (phase != null &&
        phase.totalQuestions > 0 &&
        phaseIsClosed(phase, now: now)) {
      final done = {for (final r in scoped) r.studentId};
      for (final m in members) {
        if (done.contains(m.studentId)) continue;
        scoped.add(ClassroomResult(
          studentId: m.studentId,
          studentName: m.name,
          studentRegistration: m.registration,
          phaseId: phase.id,
          totalQuestions: phase.totalQuestions,
          correctAnswers: 0,
          completedAt: phase.closesAt!,
          missing: true,
        ),);
      }
    }
    return scoped;
  }

  final gradable = phases.where((p) => p.totalQuestions > 0).toList();
  final totalWeight = gradable.fold<double>(0, (s, p) => s + p.weight);
  if (gradable.isEmpty || totalWeight <= 0) return const [];

  final byStudent = <String, List<ClassroomResult>>{};
  for (final r in rows) {
    byStudent.putIfAbsent(r.studentId, () => []).add(r);
  }

  final out = <ClassroomResult>[];
  byStudent.forEach((studentId, studentRows) {
    final pctByPhase = <String?, double>{};
    var sumTotal = 0;
    var sumCorrect = 0.0;
    DateTime? last;
    for (final r in studentRows) {
      pctByPhase[r.phaseId] = r.percentage;
      sumTotal += r.totalQuestions;
      sumCorrect += r.correctAnswers;
      if (last == null || r.completedAt.isAfter(last)) last = r.completedAt;
    }
    var weighted = 0.0;
    for (final p in gradable) {
      weighted += (pctByPhase[p.id] ?? 0.0) * p.weight; // ausente = 0
    }
    final first = studentRows.first;
    out.add(ClassroomResult(
      studentId: studentId,
      studentName: first.studentName,
      studentRegistration: first.studentRegistration,
      totalQuestions: sumTotal,
      correctAnswers: sumCorrect,
      completedAt: last ?? DateTime.now(),
      finalScore: weighted / totalWeight,
    ),);
  });

  final closed = gradable.where((p) => phaseIsClosed(p, now: now)).toList();
  if (closed.isNotEmpty) {
    final lastClose =
        closed.map((p) => p.closesAt!).reduce((a, b) => a.isAfter(b) ? a : b);
    for (final m in members) {
      if (byStudent.containsKey(m.studentId)) continue;
      out.add(ClassroomResult(
        studentId: m.studentId,
        studentName: m.name,
        studentRegistration: m.registration,
        totalQuestions: 0,
        correctAnswers: 0,
        completedAt: lastClose,
        finalScore: 0,
        missing: true,
      ),);
    }
  }
  return out;
}

/// Quem ainda pode entregar e não entregou: na fase escolhida (se ainda
/// não fechou) ou, na trilha geral, quem não fez nada (sem fase fechada —
/// com fase fechada eles já aparecem nas notas com 0).
List<ClassroomMember> gradebookPending({
  required List<ClassroomPhase> phases,
  required List<ClassroomResult> rows,
  required List<ClassroomMember> members,
  String? phaseId,
  DateTime? now,
}) {
  if (phaseId != null) {
    final phase = phases.where((p) => p.id == phaseId).firstOrNull;
    if (phase == null ||
        phase.totalQuestions == 0 ||
        phaseIsClosed(phase, now: now)) {
      return const [];
    }
    final done = {
      for (final r in rows)
        if (r.phaseId == phaseId) r.studentId,
    };
    return members.where((m) => !done.contains(m.studentId)).toList();
  }
  final gradable = phases.where((p) => p.totalQuestions > 0);
  if (gradable.any((p) => phaseIsClosed(p, now: now))) return const [];
  final withAny = {for (final r in rows) r.studentId};
  return members.where((m) => !withAny.contains(m.studentId)).toList();
}
