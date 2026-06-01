-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 00 · Prelúdio — tipos (enums) e helper de updated_at               ║
-- ╚══════════════════════════════════════════════════════════════════╝
-- gen_random_uuid() é nativo do PostgreSQL 13+ (pg_catalog), então não
-- dependemos de nenhuma extensão para PKs uuid.

-- ── Enums ─────────────────────────────────────────────────────────────
create type public.user_role            as enum ('student', 'teacher', 'admin');
create type public.question_type        as enum ('multiple_choice', 'fill_blanks', 'true_false');
create type public.achievement_rarity   as enum ('bronze', 'silver', 'gold', 'platinum');
create type public.ai_generation_status as enum ('success', 'error', 'partial');

-- ── Helper genérico de updated_at ─────────────────────────────────────
-- Usado por triggers BEFORE UPDATE para carimbar a coluna updated_at.
-- (Substitui a extensão `moddatetime`, evitando dependência de schema.)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
