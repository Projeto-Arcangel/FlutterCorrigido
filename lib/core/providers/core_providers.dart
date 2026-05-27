import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider de acesso ao SharedPreferences.
///
/// Deve ser sobrescrito via [ProviderScope] override em main.dart
/// com a instância já inicializada, garantindo leitura síncrona em
/// todo o app sem await dentro dos notifiers.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider não inicializado. '
    'Sobrescreva-o em ProviderScope antes de runApp.',
  );
});
