# Supabase — Arcangel

Scaffolding do backend Supabase (Fase 0–1 do plano em [`docs/plano_migracao_supabase.md`](../docs/plano_migracao_supabase.md)).

## Conteúdo

```
supabase/
├── migrations/
│   ├── 20260531090000_prelude.sql            # enums + helper set_updated_at
│   ├── 20260531090100_profiles_progress.sql  # profiles, user_progress
│   ├── 20260531090200_classrooms.sql         # salas, membros, fases, questões, resultados, atividades
│   ├── 20260531090300_achievements_ai.sql    # conquistas, user_achievements, ai_generation_logs
│   ├── 20260531090400_functions_triggers.sql # signup, blindagem de XP, join/submit, anti-escalada
│   └── 20260531090500_rls_policies.sql        # RLS deny-by-default + políticas
└── seed.sql                                   # catálogo de conquistas
```

> As migrations já refletem o **corte da trilha global** (sem tabelas `lessons`/`subjects`).
> A Edge Function `generate-questions` (OpenRouter) é a próxima fase — ainda não incluída aqui.

## 1. Instalar o Supabase CLI (Windows)

```powershell
# via Scoop (recomendado)
scoop install supabase
# OU via npm
npm install -g supabase
```

Verifique: `supabase --version`

## 2. Inicializar (gera o config.toml para a sua versão do CLI)

Na raiz do repositório:

```powershell
supabase init
```

> Isso cria `supabase/config.toml` **sem tocar** nas migrations/seed já existentes.

## 3a. Caminho LOCAL (Docker — para desenvolver/testar)

```powershell
supabase start          # sobe Postgres + Studio + Auth locais (precisa de Docker)
supabase db reset       # aplica TODAS as migrations + seed.sql do zero
```

Critério de pronto (Fase 1): `supabase db reset` recria o schema inteiro sem erro.

## 3b. Caminho CLOUD (projeto em supabase.com)

1. Crie o projeto no dashboard e copie o **Project Ref** e a senha do banco.
2. Autentique e vincule:
   ```powershell
   supabase login
   supabase link --project-ref <SEU_PROJECT_REF>
   ```
3. Aplique as migrations:
   ```powershell
   supabase db push
   ```
4. (Opcional) Rode o seed manualmente no SQL Editor ou via `psql`.

## 4. Validação rápida (Fase 2 — RLS)

Depois de aplicar, teste no SQL Editor com um JWT de aluno e um de professor:
- Aluno **não** consegue `select` numa sala de que não é membro.
- Aluno **não** consegue `update` direto em `user_progress` (XP só muda via `select award_xp(50)`).
- Professor só vê/edita as próprias salas.

## Próximos passos do plano

- **Fase 3:** Edge Function `generate-questions` + segredo `OPENROUTER_API_KEY`.
- **Fase 5:** ETL de dados do Firestore.
- **Fase 6:** trocar os datasources Flutter (`cloud_firestore` → `supabase_flutter`).
