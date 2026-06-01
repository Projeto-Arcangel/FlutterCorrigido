import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuração do Supabase.
///
/// Os valores vêm de `--dart-define-from-file` (veja `env/local.json` e
/// `env/prod.json`). Rode sempre passando o arquivo do ambiente desejado:
///
/// ```
/// flutter run   -d edge --dart-define-from-file=env/local.json  # dev (local)
/// flutter build web     --dart-define-from-file=env/prod.json   # produção (cloud)
/// ```
///
/// Os defaults abaixo (stack local) são apenas um fallback caso nenhum arquivo
/// seja passado. A anon key é pública (a RLS protege os dados) — não é segredo.
///
/// ⚠️ Emulador Android: `127.0.0.1` é o próprio emulador. Use um env com
/// `SUPABASE_URL=http://10.0.2.2:54321` para alcançar o host.
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
/// `core/infrastructure` por ser uma
/// dependência de plataforma; features importam daqui em vez de tocar
/// `Supabase.instance` diretamente (facilita override em testes).
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
