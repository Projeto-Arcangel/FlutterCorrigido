// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authStateHash() => r'132c5c557707d07a9765c35ab6e56b9b31e15981';

/// See also [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<User?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateRef = AutoDisposeStreamProviderRef<User?>;
String _$loginControllerHash() => r'd841ac72f526bc7239870bc07c1754d31ed7702c';

/// See also [LoginController].
@ProviderFor(LoginController)
final loginControllerProvider =
    AutoDisposeNotifierProvider<LoginController, AsyncValue<User?>>.internal(
  LoginController.new,
  name: r'loginControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$loginControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LoginController = AutoDisposeNotifier<AsyncValue<User?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
