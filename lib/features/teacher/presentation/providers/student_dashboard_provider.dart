import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../../classroom/domain/entities/classroom.dart';
import '../../../classroom/domain/entities/classroom_result.dart';
import '../../../classroom/presentation/providers/classroom_providers.dart';

/// Todas as turmas do professor logado.
final teacherAllClassroomsProvider =
    FutureProvider.autoDispose<List<Classroom>>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return [];
  final repo = ref.read(classroomRepositoryProvider);
  final result = await repo.getTeacherClassrooms(user.id);
  return result.fold((_) => [], (list) => list);
});

/// Resultados dos alunos de uma turma específica.
final classroomStudentResultsProvider =
    FutureProvider.autoDispose.family<List<ClassroomResult>, String>(
  (ref, classroomId) async {
    if (classroomId.isEmpty) return [];
    final repo = ref.read(classroomRepositoryProvider);
    final result = await repo.getResults(classroomId);
    return result.fold((_) => [], (list) => list);
  },
);

// ─── Critérios de aprovação (global do professor) ──────────────────────────

/// Limites de aprovação como frações 0..1 (ex.: approve 0.70, recovery 0.50).
typedef GradeCriteria = ({double approve, double recovery});

/// Padrão histórico do app (≥70% aprovado, ≥50% recuperação).
const GradeCriteria kDefaultGradeCriteria = (approve: 0.70, recovery: 0.50);

/// Critérios do professor logado, lidos de `profiles.grade_*_pct`.
/// São globais: o mesmo conjunto vale para todas as turmas do professor.
final teacherGradeCriteriaProvider =
    FutureProvider.autoDispose<GradeCriteria>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return kDefaultGradeCriteria;
  try {
    final row = await client
        .from('profiles')
        .select('grade_approve_pct, grade_recovery_pct')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return kDefaultGradeCriteria;
    final a = (row['grade_approve_pct'] as num?)?.toDouble() ?? 70;
    final r = (row['grade_recovery_pct'] as num?)?.toDouble() ?? 50;
    return (approve: a / 100.0, recovery: r / 100.0);
  } catch (_) {
    return kDefaultGradeCriteria;
  }
});

/// Salva os critérios (percentuais 0..100) no profile do professor e
/// invalida o provider para a UI recarregar.
Future<void> saveTeacherGradeCriteria(
  WidgetRef ref, {
  required double approvePct,
  required double recoveryPct,
}) async {
  final client = ref.read(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return;
  await client.from('profiles').update({
    'grade_approve_pct': approvePct,
    'grade_recovery_pct': recoveryPct,
  }).eq('id', user.id);
  ref.invalidate(teacherGradeCriteriaProvider);
}
