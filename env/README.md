# Ambientes (Supabase)

Cada arquivo aqui define para qual backend o app aponta, via
`--dart-define-from-file`. Eles substituem os defaults de
`lib/core/infrastructure/supabase_providers.dart`.

| Arquivo | Aponta para | Quando usar |
|---|---|---|
| `local.json` | Stack local (`npx supabase start`, `127.0.0.1:54321`) | Desenvolvimento |
| `prod.json` | Projeto cloud (`vowloulfqfvgvqzazuea.supabase.co`) | Build de produção |

## Como usar

```bash
# Desenvolvimento (precisa do stack local rodando: npx supabase start)
flutter run -d edge --dart-define-from-file=env/local.json

# Produção (build web)
flutter build web --dart-define-from-file=env/prod.json
```

## Notas

- A `SUPABASE_ANON_KEY` é **pública** (vai embutida em qualquer app cliente; a
  RLS é quem protege os dados). Por isso estes arquivos podem ir para o git.
  Se preferir não versioná-los, adicione `env/` ao `.gitignore`.
- **Emulador Android**: `127.0.0.1` é o próprio emulador. Para alcançar o host,
  crie um `env/local_android.json` com `"SUPABASE_URL": "http://10.0.2.2:54321"`.
- Para apontar a um **novo** projeto cloud, troque `SUPABASE_URL` e
  `SUPABASE_ANON_KEY` (pegue em: Dashboard → Project Settings → API).
