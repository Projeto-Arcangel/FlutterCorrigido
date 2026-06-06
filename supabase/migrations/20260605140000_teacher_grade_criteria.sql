-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Critérios de aprovação configuráveis pelo professor (global)       ║
-- ║                                                                    ║
-- ║ Antes: limites fixos no app (≥70% aprovado, ≥50% recuperação).     ║
-- ║ Agora: o professor define os seus limites; valem p/ TODAS as       ║
-- ║ turmas dele. Guardados no próprio profile (1 linha por usuário).   ║
-- ╚══════════════════════════════════════════════════════════════════╝

alter table public.profiles
  add column if not exists grade_approve_pct  numeric(5,2) not null default 70
    check (grade_approve_pct between 0 and 100),
  add column if not exists grade_recovery_pct numeric(5,2) not null default 50
    check (grade_recovery_pct between 0 and 100);

-- Aprovado nunca pode ser menor que recuperação.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_grade_thresholds_chk'
  ) then
    alter table public.profiles
      add constraint profiles_grade_thresholds_chk
      check (grade_approve_pct >= grade_recovery_pct);
  end if;
end;
$$;
