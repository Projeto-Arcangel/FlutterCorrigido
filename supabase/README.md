# Supabase — backend do Arcangel

Tudo o que roda no servidor: o schema do banco, as regras de acesso (RLS), as funções que corrigem respostas e dão XP, moedas e conquistas, e as Edge Functions da IA, do cadastro e do pagamento. A visão geral do app, os comandos do dia a dia e o deploy estão no [README da raiz](../README.md).

- **Projeto em produção:** `vowloulfqfvgvqzazuea` (`https://vowloulfqfvgvqzazuea.supabase.co`)
- **Stack local:** `npx supabase start` (precisa do Docker aberto)

## Estrutura

```
supabase/
├── config.toml      # stack local: Auth (e-mail, Google, hook do cadastro), Storage, funções
├── migrations/      # o schema inteiro, em ordem; nunca edite uma que já foi aplicada
├── functions/       # Edge Functions (Deno)
│   └── _shared/     # código comum: OpenRouter, limites do plano, leitura de links e vídeos, Asaas
├── seed.sql         # catálogo de conquistas (roda sozinho no db reset)
└── seed_demo.sql    # turmas e alunos de demonstração (rodar à mão no SQL Editor)
```

## Banco de dados

| Tabela | O que guarda |
|---|---|
| `profiles` | Nome, e-mail, prontuário e papel (aluno ou professor) |
| `user_progress` | XP, nível e moedas do aluno |
| `classrooms`, `classroom_members` | Turmas (código de 6 caracteres, até 50 alunos) e quem está em cada uma |
| `classroom_phases` | Fases da trilha: ordem, peso, abertura e fechamento, nota mínima e relógio |
| `questions` | Questões de cada fase; `type`, `content` e `answer` (jsonb) mudam conforme o tipo |
| `phase_attempts`, `attempt_answers` | Tentativas do aluno e cada resposta, corrigidas uma a uma |
| `classroom_results` | Nota oficial por fase (a da 1ª tentativa), usada no Dashboard de Alunos |
| `classroom_activities` | "Atividade recente" do painel do professor |
| `achievements`, `user_achievements` | Conquistas: 6 por XP (calculadas) e 7 por tipo de questão (gravadas) |
| `enem_questions` | Banco do ENEM (as imagens ficam no bucket `enem-questions` do Storage) |
| `plans`, `subscriptions`, `plan_usage_holds` | Planos Free/Pro/Premium, assinatura de cada professor e reservas de uso |
| `ai_generation_logs`, `material_extractions` | Uso da IA (gerações e leituras de vídeo); base dos limites mensais |
| `billing_customers`, `billing_events` | Asaas (pronto, mas desligado) |

### Funções (RPC) que o app chama

| Área | Funções |
|---|---|
| Tentativa do aluno | `start_attempt`, `open_question`, `answer_question`, `check_answer_part` (conferir palavra na hora) |
| Trilha do aluno | `get_student_classrooms`, `join_classroom`, `get_student_phases` (sem gabarito), `advance_phase` |
| Professor | `create_classroom`, `get_teacher_classrooms`, `get_classroom_by_code`, `get_classroom_roster`, `get_classroom_results`, `get_classroom_phase_results`, `reorder_phases`, `reorder_questions`, `copy_questions_to_phase`, `delete_my_questions` |
| Perfil e progresso | `set_role`, `my_achievements`, `get_classmate_profile`, `award_xp`, `award_gold`, `my_plan`, `delete_account` |
| Operação (SQL Editor) | `admin_grant_plan` |

`finalize_attempt` (fecha a tentativa e dá os prêmios) é interna: só o `answer_question` da última questão a chama. `submit_quiz` continua no banco só para o app antigo e não é usado pelo app atual.

### Regras que valem para toda migration nova

- **Privilégios fechados por padrão.** Desde `20261008120000_privileges_hardening`, tabela ou função nova nasce sem acesso. Toda migration precisa do `GRANT` explícito (e do `REVOKE` de `public`/`anon` nas funções), senão o app recebe "permission denied".
- **O gabarito não sai do servidor antes da resposta.** O aluno lê as questões por `question_public`/`get_student_phases`; a correção e a explicação vêm de `answer_question`.
- **Nota, XP, moedas e conquistas só mudam por funções `security definer`.** O aluno não tem `update` direto em `user_progress` nem em `classroom_results`.
- **Limites dos tipos de questão iguais em três lugares:** a CHECK `questions_shape_check`, `lib/features/lesson/domain/entities/question_kinds.dart` e `functions/_shared/openrouter.ts`.
- **Catálogo de planos igual ao do app:** a tabela `plans` precisa bater com `lib/features/plans/domain/plan_catalog.dart` (um teste compara os dois).

## Edge Functions

| Função | O que faz | JWT |
|---|---|---|
| `generate-questions` | Gera questões com IA (por tema ou dos materiais), confere o plano e registra o uso | professor |
| `extract-url` | Lê o texto principal de uma página a partir do link | professor |
| `extract-video` | Lê um vídeo do YouTube com o Gemini e conta os minutos no plano | professor |
| `before-user-created` | Hook do Auth: recusa e-mail com formato inválido, temporário ou de domínio que não recebe e-mail | não (assinatura do hook) |
| `billing-checkout`, `billing-cancel` | Assinar e cancelar plano pelo Asaas (desligado: `BILLING_ENABLED`) | professor |
| `billing-webhook` | Recebe os avisos de pagamento do Asaas | não (token do header) |

A lista de modelos permitidos (`ALLOWED_MODELS` em `_shared/openrouter.ts`) precisa espelhar `IaModelOption` (`lib/features/ia_quiz/domain/entities/ia_model_option.dart`).

## Desenvolvimento local

```powershell
npx supabase start                    # sobe Postgres, Auth, Storage e Studio (http://127.0.0.1:54323)
npx supabase migration up --local     # aplica só as migrations novas
npx supabase db reset                 # recria tudo do zero + seed.sql (APAGA os dados locais)

# Edge Functions, com as chaves num arquivo fora do git
npx supabase functions serve --env-file supabase/functions/.env
```

- `supabase/functions/.env` guarda `OPENROUTER_API_KEY` e `GEMINI_API_KEY`; `supabase/.env` guarda o `BEFORE_USER_CREATED_HOOK_SECRET` do hook local. Os dois estão no `.gitignore`.
- E-mails de confirmação e de nova senha caem no Inbucket: `http://127.0.0.1:54324`.
- No Windows, o edge runtime local nem sempre recarrega a função depois de editar o código: `docker restart supabase_edge_runtime_ArcangelCorrigido`.

## Produção

```powershell
npx supabase db push                                # confira a lista de pendentes antes de confirmar
npx supabase functions deploy generate-questions    # só as funções que mudaram
```

- **Segredos** (Dashboard → Edge Functions → Secrets): `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `BEFORE_USER_CREATED_HOOK_SECRET` e, quando o pagamento for ligado, `ASAAS_API_KEY`, `ASAAS_BASE_URL` e `ASAAS_WEBHOOK_TOKEN`. `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são injetados pelo próprio Supabase.
- **Autenticação** (Google, confirmação de e-mail, SMTP, senha forte e o hook do cadastro): [`docs/auth-setup.md`](../docs/auth-setup.md).
- **Liberar um plano pago** enquanto o pagamento pelo app está desligado: `select public.admin_grant_plan('professor@escola.com', 'pro', 1);` no SQL Editor.
