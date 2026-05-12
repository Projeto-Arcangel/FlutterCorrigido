import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/login_controller.dart';
import '../../../progress/presentation/providers/progress_providers.dart';
import '../../domain/entities/subject.dart';
import '../../domain/entities/subject_unlock_rules.dart';

/// Matéria atualmente selecionada (após o usuário tocar em uma matéria).
final selectedSubjectProvider = StateProvider<Subject?>((_) => null);

/// Lista de matérias com desbloqueio baseado no XP real do usuário.
/// Retorna AsyncValue — a page precisa tratar loading e error.
final subjectsProvider = FutureProvider.autoDispose<List<Subject>>((ref) async {
  // 1. Pega o usuário logado
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Subject.catalog; // não logado: retorna tudo bloqueado

  // 2. Busca o progresso do Firestore
  final result = await ref
      .watch(progressRepositoryProvider)
      .getProgress(user.id);

  // 3. Em caso de erro no Firestore, History sempre desbloqueada (fail-safe)
  final xp = result.fold((_) => 0.0, (progress) => progress.xp);

  // 4. Calcula quais matérias estão desbloqueadas
  final unlocked = unlockedSubjectIds(xp);

  // 5. Aplica o desbloqueio no catálogo
  return Subject.catalog
      .map((s) => s.copyWith(unlocked: unlocked.contains(s.id)))
      .toList();
});