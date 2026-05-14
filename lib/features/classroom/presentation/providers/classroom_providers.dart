import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/firebase_providers.dart';
import '../../../auth/presentation/providers/login_controller.dart';
import '../../data/repositories/classroom_repository_impl.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/repositories/classroom_repository.dart';

final classroomRepositoryProvider = Provider<ClassroomRepository>((ref) {
  return ClassroomRepositoryImpl(ref.watch(firestoreProvider));
});

/// Turmas do usuário logado
final userClassroomsProvider =
    FutureProvider.autoDispose<List<Classroom>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final result = await ref
      .watch(classroomRepositoryProvider)
      .getUserClassrooms(user.id);

  return result.fold((_) => [], (list) => list);
});

/// Estado do formulário de código
class JoinClassroomNotifier extends StateNotifier<AsyncValue<void>> {
  JoinClassroomNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<String?> join(String code) async {
    state = const AsyncLoading();

    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      state = const AsyncData(null);
      return 'Usuário não autenticado.';
    }

    final result = await _ref.read(classroomRepositoryProvider).joinByCode(
          code: code,
          userId: user.id,
        );

    return result.fold(
      (failure) {
        state = const AsyncData(null);
        return failure.message;
      },
      (_) {
        // Invalida cache para recarregar a lista
        _ref.invalidate(userClassroomsProvider);
        state = const AsyncData(null);
        return null; // null = sucesso
      },
    );
  }
}

final joinClassroomProvider =
    StateNotifierProvider.autoDispose<JoinClassroomNotifier, AsyncValue<void>>(
  (ref) => JoinClassroomNotifier(ref),
);