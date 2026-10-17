-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Tempo escolhido por questão — Estágio 4, Etapa 1                    ║
-- ║                                                                    ║
-- ║  O professor pode definir quanto tempo cada questão tem no relógio ║
-- ║  (5 s a 10 min). Sem escolha (NULL), vale o automático da fase:    ║
-- ║  cresce com o tamanho do texto, ajustado pelo nível               ║
-- ║  (curto/normal/longo). Só vale com o relógio da fase ligado.       ║
-- ║                                                                    ║
-- ║  O tempo de cada questão é fixado quando ela abre para o aluno     ║
-- ║  (attempt_answers.limit_s): mudar depois não afeta quem já está    ║
-- ║  respondendo aquela questão.                                       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Coluna ────────────────────────────────────────────────────────
alter table public.questions
  add column time_limit_s int
    constraint questions_time_limit_check
      check (time_limit_s is null or time_limit_s between 5 and 600);

comment on column public.questions.time_limit_s is
  'Segundos para responder com o relógio da fase ligado (NULL = automático pelo tamanho do texto e nível da fase).';

-- ── 2. Tempo da questão: o escolhido, ou o automático ────────────────
create or replace function public.question_time_limit(q public.questions, p_level text)
returns int language sql immutable set search_path = '' as $$
  select coalesce(q.time_limit_s, least(300, greatest(15, (round(
    (20 + (length(q.text)
           + coalesce((select sum(length(o)) from unnest(q.options) o), 0)) / 12.0)
    * case p_level when 'short' then 0.6 when 'long' then 1.5 else 1.0 end
    / 5) * 5)::int)));
$$;

-- ── 3. Copiar do banco de questões leva o tempo junto ────────────────
create or replace function public.copy_questions_to_phase(p_phase uuid, p_question_ids uuid[])
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_classroom uuid;
  v_next      int;
  v_count     int;
begin
  -- Trava a fase: duas cópias ao mesmo tempo não repetem posições.
  select ph.classroom_id into v_classroom
    from public.classroom_phases ph
   where ph.id = p_phase
     for update;
  if v_classroom is null or not public.owns_classroom(v_classroom) then
    raise exception 'Apenas o professor da turma pode adicionar questões a esta fase.'
      using errcode = '42501';
  end if;

  if p_question_ids is null or cardinality(p_question_ids) = 0 then
    raise exception 'Escolha ao menos uma questão.' using errcode = '22023';
  end if;
  if cardinality(p_question_ids) > 100 then
    raise exception 'Copie no máximo 100 questões por vez.' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(p_question_ids) x
     where not exists (
       select 1
         from public.questions q
         join public.classroom_phases ph on ph.id = q.phase_id
         join public.classrooms c        on c.id = ph.classroom_id
        where q.id = x and c.teacher_id = auth.uid()))
  then
    raise exception 'Alguma das questões escolhidas não existe mais. Recarregue a lista e tente de novo.'
      using errcode = '22023';
  end if;

  select coalesce(max(q.sort_order), 0) into v_next
    from public.questions q where q.phase_id = p_phase;

  insert into public.questions
    (phase_id, text, options, correct_answer, explanation, type,
     image_url, image_author, image_source, ai_generated, time_limit_s, sort_order)
  select p_phase, q.text, q.options, q.correct_answer, q.explanation, q.type,
         q.image_url, q.image_author, q.image_source, q.ai_generated, q.time_limit_s,
         v_next + row_number() over (order by o.pos)
    from (select x, min(pos) as pos
            from unnest(p_question_ids) with ordinality as u(x, pos)
           group by x) o
    join public.questions q on q.id = o.x;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ── 4. Privilégios (regra da migration 20261008120000) ──────────────
-- A coluna nova entra no INSERT/UPDATE que o professor já tem em
-- questions (a RLS segue limitando ao dono). create or replace mantém os
-- privilégios das funções; reafirmados aqui.
revoke all on function public.question_time_limit(public.questions, text) from public, anon, authenticated;
grant execute on function public.question_time_limit(public.questions, text) to service_role;
revoke all on function public.copy_questions_to_phase(uuid, uuid[]) from public, anon;
grant execute on function public.copy_questions_to_phase(uuid, uuid[]) to authenticated, service_role;
