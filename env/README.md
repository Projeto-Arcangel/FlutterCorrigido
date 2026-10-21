# Ambientes (Supabase)

Cada arquivo aqui define para qual backend o app aponta, via
`--dart-define-from-file`. Eles substituem os defaults de
`lib/core/infrastructure/supabase_providers.dart`.

| Arquivo | Aponta para | Quando usar |
|---|---|---|
| `local.json` | Stack local (`supabase start`, `127.0.0.1:54321`) | Desenvolvimento |
| `prod.json` | Projeto cloud (`vowloulfqfvgvqzazuea.supabase.co`) | Build de produção |

## Como usar

```bash
# Desenvolvimento (precisa do stack local rodando: npx supabase start)
fvm flutter run -d edge --dart-define-from-file=env/local.json

# Produção (build web)
fvm flutter build web --dart-define-from-file=env/prod.json
```

## Notas

- A `SUPABASE_ANON_KEY` é **pública** (vai embutida em qualquer app cliente; a
  RLS é quem protege os dados). Por isso estes arquivos podem ir para o git.
  Se preferir não versioná-los, adicione `env/` ao `.gitignore`.
- **Nada secreto entra aqui.** As chaves das Edge Functions (OpenRouter, Gemini,
  Asaas) ficam em `supabase/functions/.env` no local e nas Secrets do Dashboard
  em produção.
- Para apontar a um **novo** projeto cloud, troque `SUPABASE_URL` e
  `SUPABASE_ANON_KEY` (pegue em: Dashboard → Project Settings → API).
- Para ligar o pagamento pelo app quando a conta do Asaas existir, o build leva
  também `--dart-define=BILLING_ENABLED=true`.
