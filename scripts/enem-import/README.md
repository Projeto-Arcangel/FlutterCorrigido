# Importador de questões do ENEM (enem.dev → Supabase)

Sobe as imagens para o bucket `enem-questions` (Storage) e popula a tabela
`enem_questions`. Idempotente (pode rodar de novo sem duplicar).

## Pré-requisitos
- Dataset enem.dev em disco (default: `D:\DownloadsHD\questoes`).
- Migration `enem_questions` aplicada no destino (tabela + bucket).
- `npm install` aqui dentro: `npm install --prefix scripts/enem-import`

## Variáveis de ambiente
| Var | Obrigatória | Descrição |
|---|---|---|
| `SUPABASE_URL` | sim | `http://127.0.0.1:54321` (local) ou `https://<ref>.supabase.co` (cloud) |
| `SUPABASE_SERVICE_ROLE_KEY` | sim | chave **service_role** (ignora RLS). Local = JWT demo; cloud = Dashboard → Settings → API |
| `ENEM_DIR` | não | caminho do dataset (default `D:\DownloadsHD\questoes`) |
| `ENEM_YEARS` | não | filtra anos, ex.: `2022,2023` (default: todos) |
| `ENEM_SKIP_IMAGES` | não | `1` = não sobe imagens (só dados) |
| `ENEM_DRY_RUN` | não | `1` = só conta/parseia, não envia nada |

## Exemplos (PowerShell)

```powershell
# LOCAL — todos os anos
$env:SUPABASE_URL='http://127.0.0.1:54321'
$env:SUPABASE_SERVICE_ROLE_KEY='<service_role local>'
node scripts/enem-import/import.mjs

# CLOUD — todos os anos
$env:SUPABASE_URL='https://vowloulfqfvgvqzazuea.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY='<service_role do dashboard>'
node scripts/enem-import/import.mjs
```
