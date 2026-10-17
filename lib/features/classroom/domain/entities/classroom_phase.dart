import 'package:equatable/equatable.dart';

import '../../../lesson/domain/entities/question.dart';
import 'phase_rules.dart';

/// Representa uma fase (phase/lesson) criada pelo professor e vinculada
/// a uma sala de aula (classroom).
///
/// Diferente das fases globais (da trilha), esta fase aparece SOMENTE
/// para os alunos que estão na sala do professor que a criou.
///
/// Armazenada em `Classrooms/{classroomId}/phases/{phaseId}`.
/// As questões ficam em `Classrooms/{classroomId}/phases/{phaseId}/questions/{qId}`.
class ClassroomPhase extends Equatable {
  final String id;
  final String classroomId;
  final String title;
  final String description;
  final int order;

  /// Peso da fase na média ponderada da trilha (multiplicador; padrão 1.0 =
  /// todas as fases com o mesmo peso). O professor ajusta ao criar/editar.
  final double weight;
  final DateTime createdAt;
  final List<Question> questions;

  // ── Ajustes do professor (ver PhaseRules) ─────────────────────────
  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Nota (%) para liberar a próxima fase (`null` = basta concluir).
  final double? passPct;

  /// Relógio por questão (tempo conforme o texto e [timerLevel]).
  final bool timerEnabled;

  /// 'short' | 'normal' | 'long'.
  final String timerLevel;

  // ── Estado para o aluno logado (só nas fases do aluno; calculado no
  // servidor por student_phase_states) ─────────────────────────────
  final PhaseStatus status;

  /// Falta cumprir uma fase anterior.
  final bool locked;

  /// O aluno já respondeu esta fase.
  final bool completed;

  /// Nota oficial (%), a da 1ª tentativa.
  final double? scorePct;

  /// Melhor nota (%) — a que libera a próxima fase.
  final double? bestPct;

  /// Estrelas da melhor nota (0 a 3: 60%, 80%, 100%).
  final int stars;

  /// Começou uma tentativa e ainda não entregou.
  final bool inProgress;

  const ClassroomPhase({
    required this.id,
    required this.classroomId,
    required this.title,
    required this.description,
    required this.order,
    this.weight = 1.0,
    required this.createdAt,
    required this.questions,
    this.opensAt,
    this.closesAt,
    this.passPct,
    this.timerEnabled = false,
    this.timerLevel = 'normal',
    this.status = PhaseStatus.open,
    this.locked = false,
    this.completed = false,
    this.scorePct,
    this.bestPct,
    this.stars = 0,
    this.inProgress = false,
  });

  int get totalQuestions => questions.length;

  PhaseRules get rules => PhaseRules(
        opensAt: opensAt,
        closesAt: closesAt,
        passPct: passPct,
        timerEnabled: timerEnabled,
        timerLevel: timerLevel,
      );

  /// Respondeu, mas a melhor nota ainda não alcança a nota mínima (e a
  /// fase segue aberta para refazer).
  bool get needsPassScore {
    final pass = passPct;
    return pass != null &&
        completed &&
        status != PhaseStatus.closed &&
        (bestPct ?? 0) < pass;
  }

  @override
  List<Object?> get props => [
        id,
        classroomId,
        title,
        description,
        order,
        weight,
        createdAt,
        questions,
        opensAt,
        closesAt,
        passPct,
        timerEnabled,
        timerLevel,
        status,
        locked,
        completed,
        scorePct,
        bestPct,
        stars,
        inProgress,
      ];
}
