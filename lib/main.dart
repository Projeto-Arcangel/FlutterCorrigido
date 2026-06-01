import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/infrastructure/supabase_providers.dart';
import 'core/providers/core_providers.dart';
import 'firebase_options.dart'; // gere via `flutterfire configure`

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicializa o Supabase ao lado do Firebase durante a migração.
  // Config via core/infrastructure/supabase_providers.dart (override por --dart-define).
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ArcangelApp(),
    ),
  );
}