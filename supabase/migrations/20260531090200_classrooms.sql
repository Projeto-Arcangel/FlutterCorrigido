-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 02 · Salas de aula (núcleo do app)                                 ║
-- ║   classrooms · classroom_members · classroom_phases ·              ║
-- ║   questions · classroom_results · classroom_activities             ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── classrooms ────────────────────────────────────────────────────────
create table public.classrooms (
  id           uuid primary key default gen_random_uuid(),
  code         text not null unique,        -- código de 6 chars (ex.: A3X9K2)
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

create trigger classrooms_set_updated_at
  before update on public.classrooms
  for each row execute function public.set_updated_at();

-- ── classroom_members (junção N:M — substitui studentIds[]) ───────────
-- SEM unique(student_id): aluno pode estar em várias salas (decisão de projeto).
create table public.classroom_members (
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  student_id   uuid not null references public.profiles (id)   on delete cascade,
  joined_at    timestamptz not null default now(),
  primary key (classroom_id, student_id)
);

create index classroom_members_student_idx on public.classroom_members (student_id);

-- ── classroom_phases ──────────────────────────────────────────────────
create table public.classroom_phases (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  title        text not null,
  description  text not null default '',
  sort_order   int  not null default 0,
  created_at   timestamptz not null default now()
);

create index phases_classroom_idx on public.classroom_phases (classroom_id, sort_order);

-- ── questions ─────────────────────────────────────────────────────────
-- Toda questão pertence a uma fase de sala (trilha global foi removida).
create table public.questions (
  id             uuid primary key default gen_random_uuid(),
  phase_id       uuid not null references public.classroom_phases (id) on delete cascade,
  text           text not null,
  options        text[] not null,                -- List<String> do Dart
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

-- ── classroom_results ─────────────────────────────────────────────────
create table public.classroom_results (
  id              uuid primary key default gen_random_uuid(),
  classroom_id    uuid not null references public.classrooms (id)      on delete cascade,
  student_id      uuid not null references public.profiles (id)        on delete cascade,
  phase_id        uuid references public.classroom_phases (id)         on delete set null,
  total_questions int not null check (total_questions >= 0),
  correct_answers int not null check (correct_answers >= 0),
  completed_at    timestamptz not null default now(),
  -- Um resultado por aluno por sala (o último sobrescreve), espelhando o
  -- comportamento original (resultado chaveado pelo uid do aluno).
  unique (classroom_id, student_id),
  constraint results_correct_lte_total check (correct_answers <= total_questions)
);

create index results_classroom_idx on public.classroom_results (classroom_id);
create index results_student_idx   on public.classroom_results (student_id);

-- ── classroom_activities ──────────────────────────────────────────────
-- Escrita exclusivamente server-side (RPCs SECURITY DEFINER).
create table public.classroom_activities (
  id           uuid primary key default gen_random_uuid(),
  classroom_id uuid not null references public.classrooms (id) on delete cascade,
  type         text not null,                  -- 'student_joined','student_completed','phase_created'
  description  text not null,
  created_at   timestamptz not null default now()
);

create index activities_classroom_idx on public.classroom_activities (classroom_id, created_at desc);
