import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuração do Supabase.
///
/// Os defaults apontam para o stack LOCAL (`npx supabase start`). Para apontar
/// para outro ambiente (ex.: projeto cloud), passe `--dart-define` no build/run:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://SEU-PROJ.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// ⚠️ Emulador Android: `127.0.0.1` aponta para o próprio emulador. Use
/// `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` para alcançar o host.
/// A anon key default abaixo é a chave pública padrão do Supabase local
/// (idêntica em qualquer instalação local) — não é segredo.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
);

/// Cliente Supabase global.
///
/// Disponível após `Supabase.initialize(...)` no `main()`. Fica em
/// `core/infrastructure` pelo mesmo motivo do [firestoreProvider]: é uma
/// dependência de plataforma; features importam daqui em vez de tocar
/// `Supabase.instance` diretamente (facilita override em testes).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
