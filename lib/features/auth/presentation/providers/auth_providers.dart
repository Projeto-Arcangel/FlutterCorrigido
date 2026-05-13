import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/logger_provider.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/register_user.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final googleSignInProvider = Provider<GoogleSignIn>(
  (ref) => GoogleSignIn(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
    ref.watch(loggerProvider),
  );
});

final signInWithEmailProvider = Provider<SignInWithEmail>((ref) {
  return SignInWithEmail(ref.watch(authRepositoryProvider));
});

final signInWithGoogleProvider = Provider<SignInWithGoogle>((ref) {
  return SignInWithGoogle(ref.watch(authRepositoryProvider));
});

final signOutProvider = Provider<SignOut>((ref) {
  return SignOut(ref.watch(authRepositoryProvider));
});

typedef RegisterFn = Future<Either<Failure, User>> Function({
  required String email,
  required String password,
  required String displayName,
});

typedef ResetPasswordFn = Future<Either<Failure, void>> Function({
  required String email,
});

final registerWithEmailProvider = Provider<RegisterFn>(
  (ref) => ref.watch(authRepositoryProvider).registerWithEmail,
);

final sendPasswordResetProvider = Provider<ResetPasswordFn>(
  (ref) => ref.watch(authRepositoryProvider).sendPasswordReset,
);

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    ref.watch(firestoreProvider),   // já existe em lesson_providers.dart
    ref.watch(loggerProvider),
  );
});

final registerUserProvider = Provider<RegisterUser>((ref) {
  return RegisterUser(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
  );
});