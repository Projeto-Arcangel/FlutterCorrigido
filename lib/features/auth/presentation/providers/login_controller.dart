import 'package:arcangel_o_oficial/core/errors/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/user.dart';

import 'auth_providers.dart';

part 'login_controller.g.dart';

@riverpod
class LoginController extends _$LoginController {
  @override
  AsyncValue<User?> build() => const AsyncData(null);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    final useCase = ref.read(signInWithEmailProvider);

    // Tipo real, sem cast, sem ?:
    final Either<Failure, User> result =
        await useCase(email: email, password: password);

    state = result.fold(
      (failure) => AsyncError<User?>(failure.message, StackTrace.current),
      (user) => AsyncData<User?>(user), // User vira User? aqui (upcast seguro)
    );
  }

  Future<void> signOut() async {
    final useCase = ref.read(signOutProvider);
    await useCase();
    state = const AsyncData(null);
  }
}

@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}