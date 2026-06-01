-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 01 · Identidade e gamificação                                      ║
-- ║   profiles      (1:1 com auth.users)                               ║
-- ║   user_progress (1:1 com profiles — XP/level/gold/streak)          ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── profiles ──────────────────────────────────────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  email        text not null,
  display_name text,
  photo_url    text,
  role         public.user_role,        -- null = ainda não escolheu (gate da RoleSelectionPage)
  student_id   text,                    -- prontuário (ex.: SP123456), opcional
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index profiles_role_idx on public.profiles (role);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ── user_progress ─────────────────────────────────────────────────────
-- XP/gold/level NÃO são escritos pelo cliente (ver RLS + RPCs award_*).
create table public.user_progress (
  user_id         uuid primary key references public.profiles (id) on delete cascade,
  xp              numeric(12,2) not null default 0  check (xp >= 0),
  level           int           not null default 1  check (level >= 1),
  gold            int           not null default 0  check (gold >= 0),
  current_phase   int           not null default 1  check (current_phase >= 1),
  streak          int           not null default 0  check (streak >= 0),
  last_login_date date,
  updated_at      timestamptz   not null default now()
);

create trigger user_progress_set_updated_at
  before update on public.user_progress
  for each row execute function public.set_updated_at();
