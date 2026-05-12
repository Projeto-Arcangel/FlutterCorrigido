// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$quizControllerHash() => r'7cd1e77107303eb507b1a4494453c4a032fea513';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$QuizController
    extends BuildlessAutoDisposeNotifier<QuizState> {
  late final List<Question> questions;

  QuizState build(
    List<Question> questions,
  );
}

/// See also [QuizController].
@ProviderFor(QuizController)
const quizControllerProvider = QuizControllerFamily();

/// See also [QuizController].
class QuizControllerFamily extends Family<QuizState> {
  /// See also [QuizController].
  const QuizControllerFamily();

  /// See also [QuizController].
  QuizControllerProvider call(
    List<Question> questions,
  ) {
    return QuizControllerProvider(
      questions,
    );
  }

  @override
  QuizControllerProvider getProviderOverride(
    covariant QuizControllerProvider provider,
  ) {
    return call(
      provider.questions,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'quizControllerProvider';
}

/// See also [QuizController].
class QuizControllerProvider
    extends AutoDisposeNotifierProviderImpl<QuizController, QuizState> {
  /// See also [QuizController].
  QuizControllerProvider(
    List<Question> questions,
  ) : this._internal(
          () => QuizController()..questions = questions,
          from: quizControllerProvider,
          name: r'quizControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$quizControllerHash,
          dependencies: QuizControllerFamily._dependencies,
          allTransitiveDependencies:
              QuizControllerFamily._allTransitiveDependencies,
          questions: questions,
        );

  QuizControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.questions,
  }) : super.internal();

  final List<Question> questions;

  @override
  QuizState runNotifierBuild(
    covariant QuizController notifier,
  ) {
    return notifier.build(
      questions,
    );
  }

  @override
  Override overrideWith(QuizController Function() create) {
    return ProviderOverride(
      origin: this,
      override: QuizControllerProvider._internal(
        () => create()..questions = questions,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        questions: questions,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<QuizController, QuizState>
      createElement() {
    return _QuizControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is QuizControllerProvider && other.questions == questions;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, questions.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin QuizControllerRef on AutoDisposeNotifierProviderRef<QuizState> {
  /// The parameter `questions` of this provider.
  List<Question> get questions;
}

class _QuizControllerProviderElement
    extends AutoDisposeNotifierProviderElement<QuizController, QuizState>
    with QuizControllerRef {
  _QuizControllerProviderElement(super.provider);

  @override
  List<Question> get questions => (origin as QuizControllerProvider).questions;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
