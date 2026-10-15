import '../../../lesson/data/models/question_model.dart';
import '../../domain/entities/classroom_phase.dart';
import '../../domain/entities/phase_rules.dart';

/// Model que converte uma fase (tabela `classroom_phases`) para [ClassroomPhase].
class ClassroomPhaseModel extends ClassroomPhase {
  const ClassroomPhaseModel({
    required super.id,
    required super.classroomId,
    required super.title,
    required super.description,
    required super.order,
    super.weight,
    required super.createdAt,
    required super.questions,
    super.opensAt,
    super.closesAt,
    super.passPct,
    super.timerEnabled,
    super.timerLevel,
    super.status,
    super.locked,
    super.completed,
    super.scorePct,
    super.bestPct,
  });

  factory ClassroomPhaseModel.fromMap(
    Map<String, dynamic> map,
    List<QuestionModel> questions,
  ) {
    final rawWeight = map['weight'];
    return ClassroomPhaseModel(
      id: map['id'].toString(),
      classroomId: (map['classroom_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      order: (map['sort_order'] as num?)?.toInt() ?? 0,
      weight: rawWeight is num
          ? rawWeight.toDouble()
          : double.tryParse('${rawWeight ?? ''}') ?? 1.0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      questions: questions,
      opensAt: _date(map['opens_at']),
      closesAt: _date(map['closes_at']),
      passPct: _number(map['pass_pct']),
      timerEnabled: (map['timer_enabled'] as bool?) ?? false,
      timerLevel: (map['timer_level'] as String?) ?? 'normal',
      status: PhaseStatus.fromDb(map['status']),
      locked: (map['locked'] as bool?) ?? false,
      completed: (map['completed'] as bool?) ?? false,
      scorePct: _number(map['score_pct']),
      bestPct: _number(map['best_pct']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  /// numeric do Postgres chega como número ou texto, conforme o caminho.
  static double? _number(Object? value) => value is num
      ? value.toDouble()
      : (value == null ? null : double.tryParse(value.toString()));
}
