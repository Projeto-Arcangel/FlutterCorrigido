-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Notas por fase + pesos por fase (média ponderada)                  ║
-- ║                                                                    ║
-- ║ Antes: classroom_results = 1 linha por (turma, aluno), phase_id    ║
-- ║ nunca preenchido. Agora: 1 linha por (turma, aluno, FASE), com     ║
-- ║ peso configurável por fase para a média ponderada da trilha.       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1 · Peso da fase ───────────────────────────────────────────────────
-- Multiplicador (padrão 1 = todas as fases com o mesmo peso).
alter table public.classroom_phases
  add column if not exists weight numeric(6,2) not null default 1 check (weight > 0);

-- ── 2 · Resultado por fase ─────────────────────────────────────────────
-- Troca o unique (turma, aluno) por (turma, aluno, fase) e faz o phase_id
-- apagar em cascata (sem linhas órfãs ao remover a fase). Linhas legadas
-- com phase_id NULL permanecem mas são ignoradas pelas RPCs abaixo.
alter table public.classroom_results
  drop constraint if exists classroom_results_classroom_id_student_id_key;

alter table public.classroom_results
  add constraint classroom_results_classroom_student_phase_key
  unique (classroom_id, student_id, phase_id);

alter table public.classroom_results
  drop constraint if exists classroom_results_phase_id_fkey;

alter table public.classroom_results
  add constraint classroom_results_phase_id_fkey
  foreign key (phase_id) references public.classroom_phases (id) on delete cascade;

-- ── 3 · submit_result agora grava a fase ───────────────────────────────
-- Assinatura muda (ganha p_phase) → drop + recria. Mantém o "1ª tentativa
-- prevalece", agora POR FASE (on conflict por turma+aluno+fase do nothing).
drop function if exists public.submit_result(uuid, int, int, text);

create or replace function public.submit_result(
  p_classroom   uuid,
  p_total       int,
  p_correct     int,
  p_phase       uuid,
  p_phase_title text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if not public.is_member(p_classroom) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;
  if p_correct < 0 or p_total < 0 or p_correct > p_total then
    raise exception 'Resultado inválido' using errcode = '22023';
  end if;

  insert into public.classroom_results
    (classroom_id, student_id, phase_id, total_questions, correct_answers)
  values (p_classroom, auth.uid(), p_phase, p_total, p_correct)
  on conflict (classroom_id, student_id, phase_id) do nothing;

  select display_name into v_name from public.profiles where id = auth.uid();

  insert into public.classroom_activities (classroom_id, type, description)
  values (
    p_classroom, 'student_completed',
    coalesce(v_name, 'Um aluno') || ' concluiu'
      || coalesce(' a fase "' || p_phase_title || '"', '')
  );
end;
$$;

-- ── 4 · get_classroom_results: agrega por aluno (pooled) ───────────────
-- Mantém o formato 1-linha-por-aluno (ranking do aluno / classroomResults),
-- agora somando todas as fases do aluno. Ignora linhas legadas (phase NULL).
create or replace function public.get_classroom_results(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(agg.row), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'student_id',      r.student_id,
      'student_name',    coalesce(max(p.display_name), ''),
      'registration',    coalesce(max(p.student_id), ''),
      'total_questions', sum(r.total_questions),
      'correct_answers', sum(r.correct_answers),
      'completed_at',    max(r.completed_at)
    ) as row
    from public.classroom_results r
    left join public.profiles p on p.id = r.student_id
    where r.classroom_id = p_classroom
      and r.phase_id is not null
      and (public.owns_classroom(p_classroom) or public.is_member(p_classroom))
    group by r.student_id
  ) agg;
$$;

-- ── 5 · get_classroom_phase_results: linhas POR FASE ───────────────────
-- Usado pelo dashboard do professor (filtro de fase + média ponderada).
create or replace function public.get_classroom_phase_results(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'student_id',      r.student_id,
    'student_name',    coalesce(p.display_name, ''),
    'registration',    coalesce(p.student_id, ''),
    'phase_id',        r.phase_id,
    'total_questions', r.total_questions,
    'correct_answers', r.correct_answers,
    'completed_at',    r.completed_at
  )), '[]'::jsonb)
  from public.classroom_results r
  left join public.profiles p on p.id = r.student_id
  where r.classroom_id = p_classroom
    and r.phase_id is not null
    and (public.owns_classroom(p_classroom) or public.is_member(p_classroom));
$$;

-- ── 6 · Grants (RPCs só para autenticados) ─────────────────────────────
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.submit_result(uuid, int, int, uuid, text)',
    'public.get_classroom_phase_results(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end;
$$;
