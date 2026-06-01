# Plano de Refatoração de Banco de Dados — Migração Firebase → Supabase

> Projeto: **Arcangel** (app educacional gamificado, Flutter + Clean Architecture)
> Autor do plano: revisão de arquitetura sênior
> Data: 2026-05-31
> Backend atual: Firebase Auth + Cloud Firestore + Cloud Functions (OpenRouter)
> Backend alvo: Supabase (Postgres + Auth + RLS + Edge Functions + Storage)

---

## 1. Por que migrar e o que muda conceitualmente

O Firestore é um banco **NoSQL orientado a documentos**. O modelo atual já está "lutando contra a ferramenta":

- **Arrays de relacionamento** (`Classrooms.studentIds[]`) que deveriam ser uma tabela de junção — limitam queries, não escalam e dificultam contagem/paginação.
- **Subcoleções aninhadas em 3 níveis** (`Classrooms/{id}/phases/{pid}/questions/{qid}`) que exigem N+1 reads (veja `fetchClassroomPhases` e `fetchTeacherClassrooms` fazendo um `get()` por documento dentro de loops).
- **Delete em cascata manual** (`deleteClassroom` coleta refs e particiona em batches de 500) — no Postgres isso é `ON DELETE CASCADE`, grátis e atômico.
- **Integridade referencial inexistente** — nada impede um `result` apontar para um aluno que saiu da sala.
- **Regras de pontuação no cliente** (`ProgressRepositoryImpl.addXp` faz `FieldValue.increment` direto) — **trapaceável**: qualquer usuário com o app forja XP/gold.

O Postgres do Supabase resolve tudo isso com **chaves estrangeiras, constraints, transações e RLS declarativa**. Decisões tomadas para este plano:

| Decisão | Escolha |
|---|---|
| Integridade de XP/gold | **Blindada via RPC `SECURITY DEFINER`** — cliente não escreve nessas colunas |
| Salas por aluno | **Múltiplas** (tabela de junção sem `UNIQUE(student_id)`) |
| Trilha global / matérias | **Cortadas do schema** — legado do MVP de "História do Brasil", desconectado do fluxo do aluno (ver §2.1) |
| OpenRouter | Migra de Cloud Function para **Edge Function** (Deno/TS), segredo no Vault |

---

## 2. Mapeamento Firestore → Postgres

| Firestore (atual) | Postgres (alvo) | Observação |
|---|---|---|
| `Users/{uid}` (auth + perfil + progresso misturados) | `auth.users` + `public.profiles` (1:1) + `public.user_progress` (1:1) | Separa identidade, perfil e gamificação |
| `Users.studentId` (prontuário) | `profiles.student_id` | — |
| `Users.{xp,level,gold,faseAtual,streak,lastLoginDate}` | `user_progress.*` | Só mutável via RPC |
| `Classrooms/{id}` | `classrooms` | `studentIds[]` → tabela de junção |
| `Classrooms.studentIds[]` | `classroom_members` (junção) | Permite múltiplas salas, contagem e capacidade |
| `Classrooms/{id}/phases/{pid}` | `classroom_phases` | FK direta para `classrooms` |
| `.../phases/{pid}/questions/{qid}` | `questions` | FK direta `phase_id` (NOT NULL) |
| `Classrooms/{id}/results/{uid}` | `classroom_results` | FK para sala, aluno e fase |
| `Classrooms/{id}/activities/{id}` | `classroom_activities` | Escrita por trigger/RPC server-side |
| Catálogo `achievementCatalog` (cliente) | `achievements` + `user_achievements` | Persistência opcional, desbloqueio por RPC |
| Cloud Function `generateQuestionsAI` | Edge Function `generate-questions` | + tabela de auditoria `ai_generation_logs` |
| ~~`Phase` + `Questions` (trilha global)~~ | **— (removido)** | Legado do MVP; ver §2.1 |
| ~~`Subject.catalog` + `subjectXpRequirements`~~ | **— (removido)** | `subject` vira só rótulo `text`; ver §2.1 |

### 2.1. Corte da trilha global (legado do MVP de "História do Brasil")

A trilha global de matérias **não está conectada ao fluxo do aluno** e foi cortada do schema. Evidências no código atual:

- A landing do aluno (`SubjectChoicePage`) renderiza **apenas** o botão "Entrar em Turma" (`_EnterClassroomButton`) — sem grid de matérias nem link para a trilha.
- A rota `/trail` (`personalTrail`) **não tem nenhuma navegação de entrada**; `/lessons` só é alcançada de dentro de um quiz global (circular).
- O fluxo de turma evita a trilha de propósito — comentário em `classroom_lesson_page.dart`: *"Usa sua própria tela de resultado em vez do `QuizResultView` global, que manda para a trilha de história."*

**Consequências no plano:**
- Sem tabelas `lessons` e `subjects`.
- `questions` pertence sempre a uma `classroom_phase` → `phase_id NOT NULL`, sem CHECK polimórfico.
- RLS de `questions` tem um caminho só (dono/membro da sala).
- A **gamificação permanece** (`user_progress`: XP/level/gold/streak) — o XP é concedido ao concluir **fases de turma** (`classroom_lesson_page` usa `progress_providers`), não pela trilha.
- `subject` continua existindo como **rótulo de texto** (default "História do Brasil") na geração por IA — vive em `ai_generation_logs.subject`, não numa tabela de catálogo.

---

## 3. Diagrama de Relações (ER)

```
                    auth.users (Supabase Auth)
                         │ 1:1
                         ▼
                     profiles ───────────────────────────┐
                         │ 1:1                            │ 1:N (teacher_id)
                         ▼                                ▼
                  user_progress                       classrooms ───────────────┐
                                                          │ 1:N                 │ 1:N
                          ┌───────────────────────────────┼──────────────┐      │
                          ▼                               ▼              ▼      ▼
                 classroom_members              classroom_phases  classroom_results
                   (N:M aluno↔sala)                    │ 1:N      classroom_activities
                                                       ▼
                                                   questions

      ai_generation_logs ──► profiles (teacher)      user_achievements ──► achievements
```

Cardinalidades-chave:
- `profiles 1—1 user_progress`
- `profiles 1—N classrooms` (como professor)
- `classrooms N—M profiles` via `classroom_members` (como aluno)
- `classrooms 1—N classroom_phases 1—N questions`
- `questions` pertence sempre a **uma** `classroom_phase` (`phase_id NOT NULL`).

---

## 4. Schema SQL completo

> Convenção: snake_case, `uuid` como PK (compatível com `auth.users`), `timestamptz` para datas, `created_at`/`updated_at` em tudo. Rode na ordem abaixo (respeita dependências de FK).

### 4.1. Extensões e tipos

```sql
-- Extensões
create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "moddatetime";   -- trigger updated_at

-- Papéis de usuário
create type public.user_role as enum ('student', 'teacher', 'admin');

-- Tipo de questão — espelha QuestionType do Dart (0,1,2)
create type public.question_type as enum ('multiple_choice', 'fill_blanks', 'true_false');

-- Raridade de conquista — espelha AchievementRarity
create type public.achievement_rarity as enum ('bronze', 'silver', 'gold', 'platinum');

-- Status de geração por IA
create type public.ai_generation_status as enum ('success', 'error', 'partial');
```

### 4.2. `profiles` (perfil 1:1 com auth.users)

```sql
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null,
  display_name text,
  photo_url    text,
  role         public.user_role not null default 'student',
  student_id   text,                    -- prontuário (ex.: SP123456), opcional
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function moddatetime (updated_at);

create index profiles_role_idx on public.profiles (role);
```

### 4.3. `user_progress` (gamificação 1:1)

```sql
create table public.user_progress (
  user_id        uuid primary key references public.profiles (id) on delete cascade,
  xp             numeric(12,2) not null default 0  check (xp >= 0),
  level          int          not null default 1   check (level >= 1),
  gold           int          not null default 0   check (gold >= 0),
  current_phase  int          not null default 1   check (current_phase >= 1),
  streak         int          not null default 0   check (streak >= 0),
  last_login_date date,
  updated_at     timestamptz  not null default now()
);

create trigger user_progress_updated_at
  before update on public.user_progress
  for each row execute function moddatetime (updated_at);
```

### 4.4. `classrooms`

> Tabelas `subjects` e `lessons` foram **removidas** do schema (trilha global legada — ver §2.1). `subject` permanece como rótulo `text` em `ai_generation_logs`.

```sql
create table public.classrooms (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,        -- código de 6 chars (A3X9K2)
  name         text not null,
  description  text not null default '',
  teacher_id   uuid not null references public.profiles (id) on delete cascade,
  is_active    boolean not null default true,
  max_students int not null default 50 check (max_students > 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index classrooms_teacher_idx on public.classrooms (teacher_id);
create index classrooms_code_idx    on public.classrooms (code);

create trigger classrooms_updated_at
  before update on public.classrooms
  for each row execute function moddatetime (updated_at);
```

> **Nota sobre `teacher_name`:** o Firestore desnormalizava `teacherName` em cada sala (e tinha `updateTeacherName` para sincronizar). No Postgres isso some — o nome vem por `JOIN profiles`. Menos um ponto de inconsistência.

### 4.5. `classroom_members` (junção N:M — substitui `studentIds[]`)

```sql
create table public.classroom_members (
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  student_id   uuid not null references public.profiles (id)   on delete cascade,
  joined_at    timestamptz not null default now(),
  primary key (classroom_id, student_id)
  -- Decisão: SEM unique(student_id) → aluno pode estar em várias salas.
);

create index classroom_members_student_idx on public.classroom_members (student_id);
```

### 4.6. `classroom_phases` e `questions`

```sql
create table public.classroom_phases (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  title        text not null,
  description  text not null default '',
  sort_order   int  not null default 0,
  created_at   timestamptz not null default now()
);

create index phases_classroom_idx on public.classroom_phases (classroom_id, sort_order);

-- Questão pertence sempre a uma fase de sala (trilha global foi cortada — §2.1).
create table public.questions (
  id             uuid primary key default gen_random_uuid(),
  phase_id       uuid not null references public.classroom_phases (id) on delete cascade,
  text           text not null,
  options        text[] not null,                  -- List<String> do Dart
  correct_answer smallint not null check (correct_answer >= 0),
  explanation    text not null default '',
  type           public.question_type not null default 'multiple_choice',
  image_url      text,
  image_author   text,
  image_source   text,
  ai_generated   boolean not null default false,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),

  -- correctAnswer precisa indexar dentro de options.
  constraint questions_answer_in_range check (correct_answer < array_length(options, 1))
);

create index questions_phase_idx on public.questions (phase_id, sort_order);
```

### 4.7. `classroom_results` e `classroom_activities`

```sql
create table public.classroom_results (
  id              uuid primary key default gen_random_uuid(),
  classroom_id    uuid not null references public.classrooms (id)       on delete cascade,
  student_id      uuid not null references public.profiles (id)         on delete cascade,
  phase_id        uuid references public.classroom_phases (id)          on delete set null,
  total_questions int not null check (total_questions >= 0),
  correct_answers int not null check (correct_answers >= 0),
  completed_at    timestamptz not null default now(),
  -- Um resultado por (aluno, fase) dentro da sala.
  unique (classroom_id, student_id, phase_id),
  constraint results_correct_lte_total check (correct_answers <= total_questions)
);

create index results_classroom_idx on public.classroom_results (classroom_id);
create index results_student_idx   on public.classroom_results (student_id);

create table public.classroom_activities (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  type         text not null,                  -- 'student_joined','student_completed','phase_created'
  description  text not null,
  created_at   timestamptz not null default now()
);

create index activities_classroom_idx on public.classroom_activities (classroom_id, created_at desc);
```

### 4.8. Conquistas e auditoria de IA

```sql
create table public.achievements (
  id          text primary key,            -- 'first_step', 'scholar', ...
  title       text not null,
  description text not null,
  rarity      public.achievement_rarity not null,
  xp_required numeric(12,2) not null,
  icon        text                         -- nome do ícone (mapeado no cliente)
);

create table public.user_achievements (
  user_id        uuid not null references public.profiles (id)     on delete cascade,
  achievement_id text not null references public.achievements (id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- Auditoria + base para rate-limiting da geração por IA.
create table public.ai_generation_logs (
  id               uuid primary key default gen_random_uuid(),
  teacher_id       uuid not null references public.profiles (id) on delete cascade,
  subject          text,
  topic            text not null,
  difficulty       text,
  quantity         int,
  model_requested  text,
  model_used       text,
  status           public.ai_generation_status not null,
  attempts         jsonb,                  -- histórico de tentativas/fallback
  error_message    text,
  created_at       timestamptz not null default now()
);

create index ai_logs_teacher_idx on public.ai_generation_logs (teacher_id, created_at desc);
```

---

## 5. Funções de apoio e gatilhos

### 5.1. Criação automática de perfil no signup

Substitui a lógica de "criar doc em `Users/` após registro". No Firebase havia `onUserDeleted`; aqui o `ON DELETE CASCADE` já cuida da remoção, e um trigger cuida da criação:

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, photo_url, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'display_name',
    new.raw_user_meta_data ->> 'photo_url',
    coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'student')
  );
  insert into public.user_progress (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

### 5.2. Funções helper para RLS (evitam recursão)

Políticas que consultam a própria tabela (ex.: `classroom_members` checando se você é membro) causam **recursão infinita** de RLS. A solução padrão Supabase é encapsular a checagem em funções `SECURITY DEFINER` (que ignoram RLS internamente):

```sql
-- O usuário atual é professor?
create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('teacher','admin')
  );
$$;

-- O usuário atual é dono desta sala?
create or replace function public.owns_classroom(p_classroom uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.classrooms
    where id = p_classroom and teacher_id = auth.uid()
  );
$$;

-- O usuário atual é membro (aluno) desta sala?
create or replace function public.is_member(p_classroom uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.classroom_members
    where classroom_id = p_classroom and student_id = auth.uid()
  );
$$;
```

### 5.3. Blindagem de XP/Gold — mutação só via RPC

Esta é a correção de segurança mais importante. O cliente **não recebe permissão de UPDATE** em `user_progress` (ver RLS §6). Toda pontuação passa por funções validadas no servidor:

```sql
-- Concede XP, recalcula nível com a curva polinomial e devolve o progresso.
create or replace function public.award_xp(p_amount numeric)
returns public.user_progress
language plpgsql security definer set search_path = public
as $$
declare
  v_row public.user_progress;
  v_new_level int;
begin
  if p_amount is null or p_amount <= 0 or p_amount > 1000 then
    raise exception 'XP inválido: %', p_amount using errcode = '22023';
  end if;

  update public.user_progress
     set xp = xp + p_amount
   where user_id = auth.uid()
  returning * into v_row;

  -- Curva polinomial: base 80, expoente 1.5 (espelha level_utils.dart).
  -- Implementada como função auxiliar level_for_xp(numeric) — ver abaixo.
  v_new_level := public.level_for_xp(v_row.xp);
  if v_new_level > v_row.level then
    update public.user_progress set level = v_new_level
     where user_id = auth.uid() returning * into v_row;
  end if;

  return v_row;
end;
$$;

-- Reproduz levelForXp() de level_utils.dart no banco (fonte única de verdade no servidor).
create or replace function public.level_for_xp(p_xp numeric)
returns int language plpgsql immutable as $$
declare lvl int := 1; total numeric := 0;
begin
  loop
    total := total + floor(80 * power(lvl, 1.5));
    exit when p_xp < total;
    lvl := lvl + 1;
  end loop;
  return lvl;
end;
$$;

-- Concede gold (validado server-side).
create or replace function public.award_gold(p_amount int)
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Gold inválido';
  end if;
  update public.user_progress set gold = gold + p_amount
   where user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

-- Atualiza streak de login (RF02.4) de forma idempotente no servidor.
create or replace function public.register_login()
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress; v_last date;
begin
  select last_login_date into v_last from public.user_progress where user_id = auth.uid();
  update public.user_progress
     set streak = case
           when v_last = current_date then streak                 -- já logou hoje
           when v_last = current_date - 1 then streak + 1          -- dia consecutivo
           else 1                                                  -- quebrou ou primeiro
         end,
         last_login_date = current_date
   where user_id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;
```

### 5.4. Entrar em sala por código (resolve o chicken-and-egg da RLS)

Para entrar numa sala o aluno precisa achá-la pelo `code` — mas ainda não é membro, então a RLS de SELECT o bloquearia. Uma RPC `SECURITY DEFINER` faz a busca + inserção validada (capacidade, sala ativa):

```sql
create or replace function public.join_classroom(p_code text)
returns public.classrooms
language plpgsql security definer set search_path = public as $$
declare v_room public.classrooms; v_count int;
begin
  select * into v_room from public.classrooms
   where upper(code) = upper(p_code) and is_active = true;
  if v_room.id is null then
    raise exception 'Sala não encontrada ou inativa' using errcode = 'P0002';
  end if;

  select count(*) into v_count from public.classroom_members where classroom_id = v_room.id;
  if v_count >= v_room.max_students then
    raise exception 'Sala lotada' using errcode = 'P0001';
  end if;

  insert into public.classroom_members (classroom_id, student_id)
  values (v_room.id, auth.uid())
  on conflict do nothing;

  -- Registra atividade (server-side, fiel ao _writeActivity).
  insert into public.classroom_activities (classroom_id, type, description)
  select v_room.id, 'student_joined',
         coalesce((select display_name from public.profiles where id = auth.uid()), 'Um aluno') || ' entrou na turma';

  return v_room;
end;
$$;
```

> Aplique o mesmo padrão para `submit_result(...)` (insere em `classroom_results` + grava activity), mantendo a escrita de `classroom_activities` exclusivamente server-side.

---

## 6. Row Level Security (RLS) — políticas robustas

**Princípio:** habilitar RLS em **todas** as tabelas (deny-by-default) e conceder o mínimo necessário. `service_role` (Edge Functions) ignora RLS.

```sql
-- Habilita RLS em tudo
alter table public.profiles            enable row level security;
alter table public.user_progress       enable row level security;
alter table public.questions           enable row level security;
alter table public.classrooms          enable row level security;
alter table public.classroom_members   enable row level security;
alter table public.classroom_phases    enable row level security;
alter table public.classroom_results   enable row level security;
alter table public.classroom_activities enable row level security;
alter table public.achievements        enable row level security;
alter table public.user_achievements   enable row level security;
alter table public.ai_generation_logs  enable row level security;
```

### 6.1. `profiles`

```sql
-- Ler o próprio perfil
create policy profiles_select_own on public.profiles
  for select using (id = auth.uid());

-- Atualizar o próprio perfil (mas NÃO o role — ver trigger abaixo)
create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
-- INSERT é feito pelo trigger handle_new_user (security definer); sem policy de insert para o cliente.
```

Para nomes/fotos de outros usuários (professor vê nome do aluno nos resultados; aluno vê nome do professor), exponha uma **view pública restrita** em vez de abrir a tabela inteira:

```sql
create view public.public_profiles
  with (security_invoker = false) as
  select id, display_name, photo_url, role from public.profiles;
grant select on public.public_profiles to authenticated;
```

Bloqueie escalada de privilégio (aluno virar professor sozinho) com um trigger:

```sql
create or replace function public.prevent_role_escalation()
returns trigger language plpgsql as $$
begin
  if new.role is distinct from old.role then
    raise exception 'Alteração de role não permitida pelo cliente';
  end if;
  return new;
end;
$$;
create trigger profiles_lock_role
  before update on public.profiles
  for each row execute function public.prevent_role_escalation();
-- Mudança de role legítima (RoleSelectionPage) passa por RPC security definer dedicada.
```

> A `RoleSelectionPage` deixa de fazer `update` direto e passa a chamar uma RPC `set_role(p_role)` que valida (ex.: só permite definir role uma vez, ou exige verificação de professor).

### 6.2. `user_progress` — leitura própria, **escrita só por RPC**

```sql
create policy progress_select_own on public.user_progress
  for select using (user_id = auth.uid());
-- SEM policy de UPDATE/INSERT/DELETE para o cliente.
-- award_xp / award_gold / register_login (security definer) são a única via de escrita.
```

### 6.3. `questions`

Toda questão pertence a uma fase de sala — leitura para dono ou membro; escrita só para o professor dono. (Sem caminho de "lição global": a trilha foi cortada — §2.1.)

```sql
-- Leitura: dono OU membro da sala à qual a fase pertence
create policy questions_read on public.questions for select using (
  exists (
    select 1 from public.classroom_phases ph
    where ph.id = questions.phase_id
      and (public.owns_classroom(ph.classroom_id) or public.is_member(ph.classroom_id))
  )
);

-- Escrita: só o professor dono da sala
create policy questions_write on public.questions for all using (
  exists (
    select 1 from public.classroom_phases ph
    where ph.id = questions.phase_id and public.owns_classroom(ph.classroom_id)
  )
) with check (
  exists (
    select 1 from public.classroom_phases ph
    where ph.id = questions.phase_id and public.owns_classroom(ph.classroom_id)
  )
);
```

### 6.4. `classrooms`

```sql
-- Ver sala: dono OU membro
create policy classrooms_select on public.classrooms for select
  using (teacher_id = auth.uid() or public.is_member(id));

-- Criar sala: só professor, e teacher_id tem de ser ele mesmo
create policy classrooms_insert on public.classrooms for insert
  with check (public.is_teacher() and teacher_id = auth.uid());

-- Editar/excluir: só o dono
create policy classrooms_update on public.classrooms for update
  using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy classrooms_delete on public.classrooms for delete
  using (teacher_id = auth.uid());
```

### 6.5. `classroom_members`

```sql
-- Ver membros: o dono da sala OU o próprio aluno
create policy members_select on public.classroom_members for select
  using (public.owns_classroom(classroom_id) or student_id = auth.uid());

-- Entrar: via RPC join_classroom (security definer). Opcionalmente, policy direta:
create policy members_insert_self on public.classroom_members for insert
  with check (student_id = auth.uid());

-- Sair (aluno) ou remover aluno (professor dono)
create policy members_delete on public.classroom_members for delete
  using (student_id = auth.uid() or public.owns_classroom(classroom_id));
```

### 6.6. `classroom_phases`

```sql
create policy phases_select on public.classroom_phases for select
  using (public.owns_classroom(classroom_id) or public.is_member(classroom_id));
create policy phases_write on public.classroom_phases for all
  using (public.owns_classroom(classroom_id))
  with check (public.owns_classroom(classroom_id));
```

### 6.7. `classroom_results`

```sql
-- Ver resultados: dono da sala (dashboard) OU o próprio aluno
create policy results_select on public.classroom_results for select
  using (public.owns_classroom(classroom_id) or student_id = auth.uid());

-- Aluno grava o próprio resultado, e só se for membro da sala
create policy results_upsert on public.classroom_results for insert
  with check (student_id = auth.uid() and public.is_member(classroom_id));
create policy results_update_own on public.classroom_results for update
  using (student_id = auth.uid()) with check (student_id = auth.uid());
```

### 6.8. `classroom_activities`, conquistas e logs de IA

```sql
-- Atividades: só o dono lê; escrita só server-side (RPCs/triggers security definer)
create policy activities_select on public.classroom_activities for select
  using (public.owns_classroom(classroom_id));

-- Conquistas (catálogo): leitura autenticada
create policy achievements_read on public.achievements for select
  using (auth.role() = 'authenticated');

-- Conquistas do usuário: lê as próprias; desbloqueio por RPC security definer
create policy user_achievements_select on public.user_achievements for select
  using (user_id = auth.uid());

-- Logs de IA: professor vê os próprios; escrita só pela Edge Function (service_role)
create policy ai_logs_select_own on public.ai_generation_logs for select
  using (teacher_id = auth.uid());
```

---

## 7. Integração OpenRouter → Edge Function

A Cloud Function `generateQuestionsAI` (`firebase/functions/index.js` + `openrouter.js`) migra para uma **Supabase Edge Function** (Deno/TypeScript). A lógica de negócio é praticamente um port 1:1 — o que muda é o runtime, a autenticação e onde fica o segredo.

| Aspecto | Firebase (atual) | Supabase (alvo) |
|---|---|---|
| Runtime | Node.js (`onCall` v2) | Deno (`Deno.serve`) |
| Segredo | `defineSecret("OPENROUTER_API_KEY")` | `supabase secrets set OPENROUTER_API_KEY=...` (Vault) |
| Auth | `request.auth.uid` | JWT do header `Authorization`, validado via `supabase.auth.getUser()` |
| Checagem de role | lê `Users/{uid}.role` | `select role from profiles where id = uid` |
| Whitelist de modelos + fallback | `ALLOWED_MODELS` / `FALLBACK_ORDER` | **reaproveitar idêntico** |
| Validação do JSON | `parseAndValidate` | **reaproveitar idêntico** |
| Auditoria | `logger.info` | inserir em `ai_generation_logs` |

Esqueleto (`supabase/functions/generate-questions/index.ts`):

```ts
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const ALLOWED_MODELS: Record<string, string> = {
  "gemini-flash": "google/gemini-3.1-flash-lite",
  "gpt-mini": "openai/gpt-5.4-mini",
  "claude-haiku": "~anthropic/claude-haiku-latest",
};
const FALLBACK_ORDER = ["gemini-flash", "gpt-mini", "claude-haiku"];

Deno.serve(async (req) => {
  // 1. Autenticação: valida o JWT do usuário
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json(401, { error: "Não autenticado." });

  // 2. Só professores
  const { data: profile } = await supabase
    .from("profiles").select("role").eq("id", user.id).single();
  if (profile?.role !== "teacher") {
    return json(403, { error: "Apenas professores podem gerar questões." });
  }

  // 3. Valida input + 4. chama OpenRouter com fallback (port de openrouter.js)
  const body = await req.json();
  const apiKey = Deno.env.get("OPENROUTER_API_KEY")!;
  const result = await generateWithFallback(body, apiKey); // mesma lógica do openrouter.js

  // 5. Auditoria (service_role bypassa RLS)
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await admin.from("ai_generation_logs").insert({
    teacher_id: user.id, subject: body.subject, topic: body.topic,
    difficulty: body.difficulty, quantity: body.quantity,
    model_requested: body.modelKey, model_used: result.modelUsed,
    status: "success", attempts: result.attempts,
  });

  return json(200, result);
});
```

> A função `generateQuestionsWithFallback`, `buildPrompt`, `parseAndValidate`, `ALLOWED_MODELS` e `FALLBACK_ORDER` saem de `openrouter.js` quase sem alteração — copie para `supabase/functions/_shared/openrouter.ts`. A whitelist deve continuar espelhando `IaModelOption` (`lib/features/ia_quiz/domain/entities/ia_model_option.dart`).

Deploy e segredo:

```bash
supabase functions deploy generate-questions
supabase secrets set OPENROUTER_API_KEY=sk-or-...
```

No Flutter, `FirebaseFunctionsIaDatasource.generateQuestions` vira:

```dart
final res = await supabase.functions.invoke('generate-questions', body: {
  'subject': subject, 'topic': topic, 'difficulty': difficulty,
  'quantity': quantity, 'description': description, 'modelKey': modelKey,
});
return Map<String, dynamic>.from(res.data as Map);
```

---

## 8. Refatoração da camada Flutter

A Clean Architecture do projeto **isola muito bem** o impacto: domain (`entities`, `usecases`, `repositories`) e presentation (`providers`, `pages`) **não mudam**. A troca é cirúrgica em `data/datasources` e `data/repositories`.

### 8.1. Dependências (`pubspec.yaml`)

```yaml
# Adicionar
supabase_flutter: ^2.8.0

# Remover (após migração concluída e validada)
# cloud_firestore, firebase_auth, cloud_functions, firebase_storage,
# firebase_core (e os *_web/*_platform_interface correlatos)
```

### 8.2. Arquivos a reescrever (datasources/repositories)

| Arquivo | Mudança |
|---|---|
| `lib/core/infrastructure/firebase_providers.dart` | Vira `supabase_providers.dart` — expõe `SupabaseClient` |
| `lib/firebase_options.dart` | Removido; `Supabase.initialize(url, anonKey)` no `main` |
| `auth/data/repositories/auth_repository_impl.dart` | `supabase.auth.signInWithPassword`, `signInWithOAuth(Google)`, `signOut` |
| `auth/data/repositories/user_repository_impl.dart` | `from('profiles')` em vez de `Users/` |
| `progress/data/repositories/progress_repository_impl.dart` | **`addXp`/`addGold`/`advancePhase` chamam RPC** (`rpc('award_xp', {...})`) — fim da escrita direta |
| `lesson/data/datasources/firebase/lesson_firestore_datasource.dart` | **Removido** junto com a trilha global (ver §8.5) |
| `classroom/data/datasources/firebase/classroom_firestore_datasource.dart` | Maior arquivo afetado — ver abaixo |
| `ia_quiz/data/datasources/firebase_functions_ia_datasource.dart` | `supabase.functions.invoke('generate-questions')` |

### 8.3. Ganhos concretos no `classroom` datasource

- `deleteClassroom` (60+ linhas de coleta de refs + batches de 500) → **`delete().eq('id', id)`**; o `ON DELETE CASCADE` apaga phases, questions, results, members e activities atomicamente.
- `fetchTeacherClassrooms` (loop com N reads de questions) → **uma query com join aninhado**: `from('classrooms').select('*, classroom_members(count), classroom_phases(*, questions(*))').eq('teacher_id', id)`.
- `joinClassroom` / `fetchByCode` → **RPC `join_classroom(code)`** (valida capacidade e sala ativa no servidor).
- `_generateUniqueCode` → pode virar `default` no banco (função `gen_classroom_code()`), eliminando o loop de verificação de colisão no cliente.
- `submitResult` + `_writeActivity` → **RPC `submit_result(...)`** (resultado + activity numa transação).

### 8.4. Mapeamento de tipos

- `Timestamp` (Firestore) → `String` ISO 8601 / `timestamptz` → `DateTime.parse(...)`. Atualizar `fromSnapshot`/`fromJson` dos models (`*_model.dart`).
- `correct_answer` já é `int`; `options` já é `List<String>` → `text[]` mapeia direto.
- `type` (int 0/1/2) → enum `question_type`; manter `QuestionType.fromInt` ou criar `fromString`.
- `faseAtual` (campo legado em pt) → `current_phase`.

### 8.5. Remoção da trilha global — o que deletar vs. o que é compartilhado

A trilha global sai junto com a migração. **Cuidado:** parte da feature `lesson/` é reutilizada pelo fluxo de turma — deletar errado quebra o quiz das salas.

**Seguro remover** (só a trilha global usa):
- `lesson/presentation/pages/lesson_list_page.dart`, `lesson_page.dart`
- `lesson/presentation/widgets/quiz_view.dart`, `quiz_result_view.dart` (a tela de resultado que manda para `/lessons`)
- `lesson/data/datasources/firebase/lesson_firestore_datasource.dart`, `lesson_repository_impl.dart`, usecases `get_all_lessons.dart` / `get_lesson_by_id.dart`, `lesson_providers.dart`
- Rotas `AppRoutes.lessons`, `AppRoutes.lesson`, `AppRoutes.personalTrail` no `app_router.dart`
- `subject/` como **catálogo de desbloqueio**: `subject_unlock_rules.dart`, `subject_providers.dart`, `subject_button.dart` e o grid (a `SubjectChoicePage` já só tem o botão "Entrar em Turma")
- Coleções Firestore `Phase` e `Questions` (não migrar no ETL)

**NÃO remover — compartilhado com o fluxo de turma** (`classroom_lesson_page.dart` importa):
- `lesson/presentation/providers/quiz_controller.dart` (controla o quiz das fases de turma)
- `lesson/presentation/widgets/option_tile.dart`
- `lesson/domain/entities/question.dart` + `data/models/question_model.dart` (entidade base usada em todo lugar)

> Recomendação: faça essa limpeza numa **branch dedicada, após** o cutover do Supabase estar validado, rodando o app e completando uma fase de turma para confirmar que o quiz continua funcionando.

---

## 9. Estratégia de migração de dados (Firestore → Postgres)

1. **Exportar** o Firestore: `gcloud firestore export gs://<bucket>` ou um script Admin SDK que percorre as coleções e gera JSON/NDJSON.
2. **Transformar** (script Node/Dart ETL):
   - `Users` → `profiles` + `user_progress` (split de campos).
   - `Classrooms.studentIds[]` → linhas em `classroom_members`.
   - Achatar `phases/{}/questions/{}` → `questions` com `phase_id`.
   - Converter `Timestamp` → ISO 8601; `type` int → enum.
   - Preservar IDs onde possível (gerar um mapa `firestoreId → uuid` para manter FKs).
   - Os UIDs do Firebase Auth precisam virar usuários no Supabase Auth: usar `supabase.auth.admin.createUser` (com `id` preservado) **antes** de inserir profiles, já que `profiles.id` referencia `auth.users`.
3. **Carregar** com `service_role` (bypassa RLS), respeitando ordem de FK: profiles → user_progress → classrooms → members → phases → questions → results → activities. (As coleções `Phase`/`Questions` da trilha global **não** são migradas — §8.5.)
4. **Validar**: contagens por tabela vs. Firestore; amostragem de salas com membros e questões; testar RLS com um JWT de aluno e um de professor.
5. **Seed** estático: `achievements` (de `achievementCatalog`).

---

## 10. Roadmap de execução (faseado, reversível)

| Fase | Entrega | Critério de pronto |
|---|---|---|
| **0. Setup** | Projeto Supabase, `supabase init`, migrations versionadas em `supabase/migrations/` | `supabase db reset` recria o schema do zero |
| **1. Schema** | §4 e §5 aplicados | Tabelas, FKs, constraints e triggers criados |
| **2. RLS** | §6 aplicado + testes | Testes automatizados de policy (aluno não lê sala alheia, etc.) |
| **3. Edge Function** | §7 — `generate-questions` no ar com segredo | Professor gera questões; aluno recebe 403 |
| **4. Seed** | `achievements` populados | Catálogo carregado |
| **5. ETL** | §9 — dados migrados para staging | Validação de contagens e RLS passa |
| **6. Flutter** | §8 — datasources/repositories reescritos atrás das mesmas interfaces | App roda 100% no Supabase em staging |
| **7. Cutover** | Deploy produção, freeze de escrita no Firestore, ETL final, switch | App em produção; rollback documentado |
| **8. Limpeza** | Remover deps Firebase, `firebase/functions/`, `firebase_options.dart` | Build sem Firebase |

**Reversibilidade:** até a Fase 7 o Firebase continua de pé; o cutover é a única etapa de risco e tem rollback (re-apontar o app para a versão Firebase anterior).

---

## 11. Resumo dos ganhos de segurança e arquitetura

1. **XP/gold à prova de trapaça** — mutação exclusiva por RPC validada no servidor (antes: cliente incrementava livremente).
2. **Integridade referencial real** — FKs + `ON DELETE CASCADE` eliminam órfãos e os ~120 linhas de delete-em-cascata manual.
3. **RLS declarativa e auditável** — autorização vive no banco, não espalhada em checagens de cliente/função.
4. **Anti-escalada de privilégio** — trigger impede aluno virar professor; mudança de role só por RPC controlada.
5. **Menos N+1** — joins do Postgres substituem loops de reads do Firestore (dashboards mais rápidos).
6. **Schema enxuto e honesto** — corte da trilha global legada (§2.1): sem `lessons`/`subjects`, `questions` com dono único, RLS mais simples.
7. **Auditoria de IA** — `ai_generation_logs` dá base para rate-limiting e controle de custo da OpenRouter.
8. **Segredo melhor isolado** — `OPENROUTER_API_KEY` no Vault do Supabase, acessível só pela Edge Function (`service_role`).
```

