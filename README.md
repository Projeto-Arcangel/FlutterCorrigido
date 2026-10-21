# Arcangel

Plataforma web em que o professor cria atividades em formato de jogo e os alunos respondem pelo navegador, no computador ou no celular. Cada turma tem uma **trilha de fases**: o aluno avança fase por fase, ganha estrelas, pontos e conquistas, e o professor acompanha as notas num painel. A IA ajuda a montar as questões a partir de um tema ou dos materiais do próprio professor.

- **Produção:** [arcangels.uk](https://arcangels.uk)
- **Suporte:** arcangel.admin@gmail.com
- **Funcionalidades em detalhe** (para o time e para apresentar aos professores): [`docs/Arcangel_Funcionalidades.docx`](docs/Arcangel_Funcionalidades.docx)

## O que a plataforma faz

**Professor**
- Cria turmas (até 50 alunos, entrada por código) e monta a trilha de fases, com disciplina, peso e ordem.
- Regras por fase: abertura e fechamento, nota mínima para liberar a próxima e relógio (tempo automático ou escolhido por questão).
- Seis tipos de questão: múltipla escolha, ligar colunas, ordenar, completar lacunas, cruzadinha e caça-palavras. Na cruzadinha e no caça-palavras dá para mostrar os acertos na hora ou só no fim e ocultar palavras.
- Cria questões escrevendo, com IA por tema, com IA a partir de materiais (PDF, DOCX, PPTX, links e vídeos do YouTube), pelo banco do ENEM (2009 a 2023) ou reaproveitando as próprias.
- Acompanha a turma no Dashboard de Alunos (notas por fase, média ponderada, quem não entregou, aprovação) e exporta em `.xlsx`.
- Planos Free, Pro e Premium, com limites mensais de IA e de questões guardadas.

**Aluno**
- Entra na turma pelo código e joga a trilha: uma questão por vez, com correção na hora e explicação no fim.
- Pode fechar e continuar de onde parou; pode refazer a fase para melhorar as estrelas (a nota oficial é a da 1ª tentativa).
- Ganha pontos, sequência de acertos, estrelas, XP, nível, moedas e 13 conquistas, com aviso de parabéns ao terminar a fase.
- Vê o ranking da turma e o perfil dos colegas (sem e-mail nem prontuário).

## Tecnologias

| Parte | O que usa |
|---|---|
| App | Flutter **3.38.9** (via [FVM](https://fvm.app)), só web · Riverpod · go_router · supabase_flutter |
| Backend | Supabase: Postgres com RLS e funções (RPC) `security definer`, Auth (e-mail e Google), Storage e Edge Functions em Deno |
| IA | OpenRouter (Gemini Flash, Claude Haiku e GPT Mini) para gerar questões; API do Gemini para ler vídeos do YouTube |
| Pagamentos | Asaas: integração pronta, mas **desligada** (`BILLING_ENABLED`); hoje os planos pagos são liberados manualmente |
| Hospedagem | Cloudflare Pages (o build web) e Supabase Cloud (o backend) |

## Estrutura do repositório

```
lib/
  core/            # tema, rotas (go_router), erros, providers e widgets comuns
  features/        # uma pasta por área, cada uma em data/ domain/ presentation/
    auth/          #   cadastro, login, Google, escolha de perfil, senha
    landing/       #   página inicial (visitante)
    subject/       #   tela inicial do aluno ("Pronto para estudar?")
    classroom/     #   trilha do aluno, tentativas, tabuleiros dos tipos, ranking, perfil do colega
    lesson/        #   entidade Question e regras de cada tipo (question_kinds.dart)
    teacher/       #   área do professor: turmas, fases, editores, banco de questões, dashboard
    ia_quiz/       #   geração de questões com IA (tema e materiais)
    enem/          #   banco de questões do ENEM
    plans/         #   planos e limites
    profile/       #   perfil e conquistas
    progress/      #   XP, nível e moedas
    settings/      #   conta e preferências
    generic/       #   esqueleto de exemplo para novas features
supabase/
  migrations/      # o schema inteiro, em ordem (aplicadas com db push)
  functions/       # Edge Functions (ver abaixo); _shared/ tem o código comum
test/              # testes do app (flutter test)
env/               # local.json e prod.json: para qual Supabase o app aponta
scripts/           # importador do ENEM e aplicação da senha forte e do hook de cadastro
docs/              # funcionalidades e configuração da autenticação
```

### Edge Functions

| Função | O que faz |
|---|---|
| `generate-questions` | Gera questões com IA (por tema ou materiais) e confere o limite do plano |
| `extract-url` | Lê o texto principal de uma página a partir do link |
| `extract-video` | Lê um vídeo do YouTube e conta os minutos no plano |
| `before-user-created` | Hook do Auth: recusa e-mails inválidos ou temporários no cadastro |
| `billing-checkout`, `billing-webhook`, `billing-cancel` | Assinaturas pelo Asaas (desligadas até a conta existir) |

## Rodando localmente

**Requisitos:** FVM, Docker Desktop e Node (o Supabase CLI roda com `npx supabase`).

```powershell
# 1. Dependências do app
fvm install
fvm flutter pub get

# 2. Backend local (precisa do Docker aberto; a 1ª vez aplica todas as migrations)
npx supabase start

# 3. Edge Functions locais, com as chaves num arquivo fora do git
#    supabase/functions/.env  →  OPENROUTER_API_KEY=...  GEMINI_API_KEY=...
npx supabase functions serve --env-file supabase/functions/.env

# 4. App apontando para o backend local
fvm flutter run -d edge --dart-define-from-file=env/local.json
```

- Migration nova: `npx supabase migration up --local` aplica só as pendentes. `npx supabase db reset` recria tudo do zero e **apaga os dados locais**.
- Mais sobre os ambientes: [`env/README.md`](env/README.md). Tabelas, funções e regras do backend: [`supabase/README.md`](supabase/README.md). Google, verificação de e-mail e senha: [`docs/auth-setup.md`](docs/auth-setup.md).

## Testes

```powershell
fvm flutter analyze
fvm flutter test
```

## Deploy em produção

A ordem importa: as funções e o app novos dependem das migrations.

```powershell
# 1. Banco: confira a lista de pendentes antes de confirmar
npx supabase db push

# 2. Edge Functions que mudaram
npx supabase functions deploy generate-questions

# 3. App web: suba a pasta build/web no Cloudflare Pages
fvm flutter build web --dart-define-from-file=env/prod.json
```

**Segredos das funções** (Supabase → Edge Functions → Secrets; nunca no repositório): `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `BEFORE_USER_CREATED_HOOK_SECRET` e, quando o pagamento for ligado, `ASAAS_API_KEY`, `ASAAS_BASE_URL` e `ASAAS_WEBHOOK_TOKEN`. `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são injetados pelo próprio Supabase.

## Regras do projeto

- **Privilégios fechados por padrão.** Desde a migration `20261008120000_privileges_hardening`, toda tabela ou função nova nasce sem acesso: a migration precisa ter o `GRANT` explícito, senão o app recebe "permission denied".
- **Tudo que vale nota é decidido no servidor.** Notas, XP, moedas e conquistas só mudam por funções do banco; o gabarito de uma questão só chega ao aluno depois que ele responde.
- **Limites do plano são conferidos no servidor.** O catálogo do app (`lib/features/plans/domain/plan_catalog.dart`) precisa ser igual à tabela `plans`, e um teste compara os dois.
- **Segredos fora do git.** `supabase/functions/.env` está no `.gitignore`. As chaves em `env/*.json` são públicas (anon key), e quem protege os dados é a RLS.

## Operação

- **Liberar um plano pago** (enquanto o pagamento pelo app está desligado), no SQL Editor:
  ```sql
  select public.admin_grant_plan('professor@escola.com', 'pro', 1);   -- 1 mês de Pro
  select public.admin_grant_plan('professor@escola.com', 'free');     -- encerra
  ```
- **Importar questões do ENEM:** [`scripts/enem-import/README.md`](scripts/enem-import/README.md).
