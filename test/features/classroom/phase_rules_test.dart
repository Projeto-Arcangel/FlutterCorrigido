import 'package:arcangel_o_oficial/features/classroom/data/models/classroom_phase_model.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/classroom_phase.dart';
import 'package:arcangel_o_oficial/features/classroom/domain/entities/phase_rules.dart';
import 'package:arcangel_o_oficial/features/classroom/presentation/phase_access.dart';
import 'package:flutter_test/flutter_test.dart';

ClassroomPhase _phase({
  String title = 'Fase',
  PhaseStatus status = PhaseStatus.open,
  bool locked = false,
  bool completed = false,
  bool inProgress = false,
  double? passPct,
  double? bestPct,
  double? scorePct,
  DateTime? opensAt,
  DateTime? closesAt,
}) =>
    ClassroomPhase(
      id: title,
      classroomId: 'c',
      title: title,
      description: '',
      order: 1,
      createdAt: DateTime(2026),
      questions: const [],
      status: status,
      locked: locked,
      completed: completed,
      inProgress: inProgress,
      passPct: passPct,
      bestPct: bestPct,
      scorePct: scorePct,
      opensAt: opensAt,
      closesAt: closesAt,
    );

void main() {
  // Datas locais de referência (o app mostra no horário do aparelho).
  final now = DateTime(2026, 10, 15, 10);
  final opens = DateTime(2026, 10, 20, 8);
  final closes = DateTime(2026, 10, 25, 18, 30);

  group('PhaseRules', () {
    test('valida como o banco', () {
      expect(const PhaseRules().validate(), isNull);
      expect(PhaseRules(opensAt: opens, closesAt: closes).validate(), isNull);
      expect(
        PhaseRules(opensAt: closes, closesAt: opens).validate(),
        'O fechamento precisa ser depois da abertura.',
      );
      expect(
        PhaseRules(opensAt: opens, closesAt: opens).validate(),
        'O fechamento precisa ser depois da abertura.',
      );
      expect(const PhaseRules(passPct: 0).validate(), contains('1% a 100%'));
      expect(const PhaseRules(passPct: 101).validate(), contains('1% a 100%'));
      expect(const PhaseRules(passPct: 100).validate(), isNull);
      expect(
        const PhaseRules(timerEnabled: true, timerLevel: 'turbo').validate(),
        contains('curto, normal ou longo'),
      );
      expect(const PhaseRules(timerEnabled: true).isEmpty, isFalse);
    });

    test('resumo curto para listas', () {
      expect(const PhaseRules().summary(now: now), '');
      expect(
        PhaseRules(opensAt: opens, closesAt: closes, passPct: 70)
            .summary(now: now),
        'abre 20/10 às 8h · até 25/10 às 18h30 · mín. 70%',
      );
      expect(
        const PhaseRules(timerEnabled: true, timerLevel: 'short').summary(),
        'relógio curto',
      );
      expect(const PhaseRules(timerLevel: 'long').summary(), '');
    });

    test('datas: ano só quando não é o atual', () {
      expect(PhaseDateFormat.short(opens, now: now), '20/10 às 8h');
      expect(
        PhaseDateFormat.short(DateTime(2027, 2, 3, 9, 5), now: now),
        '03/02/2027 às 9h05',
      );
    });

    test('porcentagem', () {
      expect(formatPct(70), '70');
      expect(formatPct(72.5), '72,5');
      expect(formatPct(66.666), '66,7');
    });
  });

  group('toque na fase da trilha', () {
    test('aberta e livre: joga', () {
      expect(phaseAccess(_phase()).action, PhaseTapAction.play);
    });

    test('bloqueada sem nota mínima: concluir a anterior', () {
      final a = phaseAccess(_phase(locked: true), previous: _phase());
      expect(a.action, PhaseTapAction.message);
      expect(a.message, 'Conclua a fase anterior para liberar esta.');
    });

    test('bloqueada por nota mínima: diz quanto precisa e onde', () {
      final previous = _phase(
        title: 'Era Vargas',
        completed: true,
        passPct: 70,
        bestPct: 50,
      );
      final a = phaseAccess(_phase(locked: true), previous: previous);
      expect(
        a.message,
        'Tire pelo menos 70% na fase "Era Vargas" para liberar esta.',
      );
    });

    test('agendada: diz quando abre', () {
      final a = phaseAccess(
        _phase(status: PhaseStatus.scheduled, opensAt: opens),
        now: now,
      );
      expect(a.action, PhaseTapAction.message);
      expect(a.message, 'Esta fase abre em 20/10 às 8h.');
    });

    test('encerrada sem resposta: avisa, não abre', () {
      final a = phaseAccess(
        _phase(status: PhaseStatus.closed, closesAt: closes),
        now: now,
      );
      expect(a.action, PhaseTapAction.message);
      expect(a.message, 'Esta fase foi encerrada em 25/10 às 18h30.');
    });

    test('encerrada e respondida: mostra a nota', () {
      final a = phaseAccess(
        _phase(status: PhaseStatus.closed, completed: true, scorePct: 80),
      );
      expect(a.action, PhaseTapAction.showResult);
    });

    test('encerrada vence o bloqueio (fase fechada não trava o aluno)', () {
      final a = phaseAccess(
        _phase(status: PhaseStatus.closed, locked: true, completed: true),
      );
      expect(a.action, PhaseTapAction.showResult);
    });
  });

  group('legenda abaixo da fase', () {
    test('encerrada, agendada, prazo e nota que falta', () {
      expect(phaseCaption(_phase(status: PhaseStatus.closed)), 'Encerrada');
      expect(
        phaseCaption(
          _phase(status: PhaseStatus.scheduled, opensAt: opens),
          now: now,
        ),
        'Abre 20/10 às 8h',
      );
      expect(
        phaseCaption(_phase(closesAt: closes), now: now),
        'Até 25/10 às 18h30',
      );
      expect(
        phaseCaption(
          _phase(completed: true, passPct: 70, bestPct: 50, closesAt: closes),
          now: now,
        ),
        'Precisa de 70%',
      );
      expect(phaseCaption(_phase()), isNull);
      expect(
        phaseCaption(_phase(inProgress: true, closesAt: closes), now: now),
        'Em andamento',
      );
    });
  });

  test('lê do servidor os ajustes e o estado do aluno', () {
    final phase = ClassroomPhaseModel.fromMap(
      const {
        'id': 'f1',
        'classroom_id': 'c1',
        'title': 'F1',
        'sort_order': 1,
        'opens_at': '2026-10-20T11:00:00+00:00',
        'closes_at': null,
        'pass_pct': 70.00,
        'timer_enabled': true,
        'timer_level': 'short',
        'status': 'scheduled',
        'locked': false,
        'completed': true,
        'score_pct': '50.00',
        'best_pct': 100,
        'stars': 3,
        'in_progress': true,
      },
      const [],
    );
    expect(phase.opensAt, DateTime.utc(2026, 10, 20, 11));
    expect(phase.closesAt, isNull);
    expect(phase.passPct, 70);
    expect(phase.timerEnabled, isTrue);
    expect(phase.timerLevel, 'short');
    expect(phase.status, PhaseStatus.scheduled);
    expect(phase.completed, isTrue);
    expect(phase.scorePct, 50);
    expect(phase.bestPct, 100);
    expect(phase.stars, 3);
    expect(phase.inProgress, isTrue);
    expect(
      phase.rules,
      PhaseRules(
        opensAt: DateTime.utc(2026, 10, 20, 11),
        passPct: 70,
        timerEnabled: true,
        timerLevel: 'short',
      ),
    );
  });

  test('fase do professor (sem estado do aluno) usa os padrões', () {
    final phase = ClassroomPhaseModel.fromMap(
      const {'id': 'f1', 'title': 'F1'},
      const [],
    );
    expect(phase.status, PhaseStatus.open);
    expect(phase.locked, isFalse);
    expect(phase.rules.isEmpty, isTrue);
    expect(phase.timerLevel, 'normal');
  });
}
