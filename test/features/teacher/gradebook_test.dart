import 'package:arcangel_o_oficial/features/classroom/domain/entities/classroom_phase.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/classroom_result.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_attempt.dart';
import 'package:arcangel_o_oficial/features/lesson/domain/entities/question.dart';
import 'package:arcangel_o_oficial/features/teacher/presentation/gradebook.dart';
import 'package:flutter_test/flutter_test.dart';

const _q = Question(
  id: 'q',
  text: 'Q',
  options: ['A', 'B'],
  correctAnswer: 0,
  explanation: '',
  type: QuestionType.multipleChoice,
);

ClassroomPhase _phase(String id, {DateTime? closesAt, int questions = 2}) =>
    ClassroomPhase(
      id: id,
      classroomId: 'c',
      title: id,
      description: '',
      order: 1,
      createdAt: DateTime(2026),
      questions: List.filled(questions, _q),
      closesAt: closesAt,
    );

ClassroomResult _row(String student, String phase, double correct) =>
    ClassroomResult(
      studentId: student,
      studentName: student.toUpperCase(),
      phaseId: phase,
      totalQuestions: 2,
      correctAnswers: correct,
      completedAt: DateTime(2026, 10, 10),
    );

void main() {
  final now = DateTime(2026, 10, 16, 12);
  final closed = _phase('f1', closesAt: DateTime(2026, 10, 15));
  final open = _phase('f2', closesAt: DateTime(2026, 10, 20));
  const members = [
    ClassroomMember(studentId: 'ana', name: 'Ana'),
    ClassroomMember(studentId: 'bia', name: 'Bia', inProgressPhaseIds: {'f2'}),
    ClassroomMember(studentId: 'caio', name: 'Caio'),
  ];
  final rows = [_row('ana', 'f1', 1.5), _row('ana', 'f2', 2), _row('bia', 'f2', 1)];

  test('fase fechada: quem não entregou entra com 0', () {
    final scores = gradebookScores(
      phases: [closed, open],
      rows: rows,
      members: members,
      phaseId: 'f1',
      now: now,
    );
    expect(scores.map((r) => r.studentId), ['ana', 'bia', 'caio']);
    expect(scores.first.percentage, 0.75); // nota parcial: 1,5 de 2
    final missing = scores.where((r) => r.missing).toList();
    expect(missing.map((r) => r.studentName), ['Bia', 'Caio']);
    expect(missing.every((r) => r.percentage == 0), isTrue);
    expect(
      gradebookPending(
        phases: [closed, open],
        rows: rows,
        members: members,
        phaseId: 'f1',
        now: now,
      ),
      isEmpty,
    );
  });

  test('fase aberta: quem não entregou fica pendente, fora da média', () {
    final scores = gradebookScores(
      phases: [closed, open],
      rows: rows,
      members: members,
      phaseId: 'f2',
      now: now,
    );
    expect(scores.map((r) => r.studentId), ['ana', 'bia']);
    expect(scores.any((r) => r.missing), isFalse);
    final pending = gradebookPending(
      phases: [closed, open],
      rows: rows,
      members: members,
      phaseId: 'f2',
      now: now,
    );
    expect(pending.map((m) => m.name), ['Caio']);
  });

  test('trilha geral: com fase fechada, quem não fez nada entra com 0', () {
    final scores = gradebookScores(
      phases: [closed, open],
      rows: rows,
      members: members,
      now: now,
    );
    final byId = {for (final r in scores) r.studentId: r};
    expect(byId['ana']!.percentage, closeTo(0.875, 1e-9)); // (75% + 100%) / 2
    expect(byId['ana']!.correctAnswers, 3.5);
    expect(byId['bia']!.percentage, 0.25); // f1 fechada sem entrega = 0
    expect(byId['caio']!.missing, isTrue);
    expect(byId['caio']!.percentage, 0);
  });

  test('trilha geral sem fase fechada: quem não fez nada só aparece como pendente',
      () {
    final phases = [_phase('f1'), _phase('f2')];
    final scores = gradebookScores(
      phases: phases,
      rows: rows,
      members: members,
      now: now,
    );
    expect(scores.map((r) => r.studentId).toSet(), {'ana', 'bia'});
    expect(
      gradebookPending(phases: phases, rows: rows, members: members, now: now)
          .map((m) => m.name),
      ['Caio'],
    );
  });
}
