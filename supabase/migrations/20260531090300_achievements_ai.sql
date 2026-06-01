-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 03 · Conquistas e auditoria de IA                                  ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── achievements (catálogo) ───────────────────────────────────────────
create table public.achievements (
  id          text primary key,            -- 'first_step', 'scholar', ...
  title       text not null,
  description text not null,
  rarity      public.achievement_rarity not null,
  xp_required numeric(12,2) not null,
  icon        text                         -- token de ícone (mapeado no cliente)
);

-- ── user_achievements ─────────────────────────────────────────────────
create table public.user_achievements (
  user_id        uuid not null references public.profiles (id)     on delete cascade,
  achievement_id text not null references public.achievements (id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- ── ai_generation_logs (auditoria + base p/ rate-limiting) ────────────
create table public.ai_generation_logs (
  id              uuid primary key default gen_random_uuid(),
  teacher_id      uuid not null references public.profiles (id) on delete cascade,
  subject         text,                    -- rótulo livre (ex.: 'História do Brasil')
  topic           text not null,
  difficulty      text,
  quantity        int,
  model_requested text,
  model_used      text,
  status          public.ai_generation_status not null,
  attempts        jsonb,                   -- histórico de tentativas/fallback
  error_message   text,
  created_at      timestamptz not null default now()
);

create index ai_logs_teacher_idx on public.ai_generation_logs (teacher_id, created_at desc);
