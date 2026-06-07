-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Fase 2 · Esconder o gabarito do cliente (anti-cola)                ║
-- ║                                                                    ║
-- ║  Antes: o aluno baixava a tabela `questions` inteira (incl.        ║
-- ║  correct_answer/explanation) para dar feedback instantâneo local.  ║
-- ║  Um aluno técnico lia o gabarito no payload e gabaritava.          ║
-- ║                                                                    ║
-- ║  Agora:                                                            ║
-- ║   1. RLS de `questions` em SELECT vira SOMENTE do dono (professor).║
-- ║      O aluno não lê mais a tabela direto (nem por PostgREST).      ║
-- ║   2. `get_student_phases` (DEFINER, membro) devolve as fases +     ║
-- ║      questões SEM correct_answer/explanation — é por aqui que o    ║
-- ║      app do aluno carrega a trilha.                                ║
-- ║   3. `submit_quiz` passa a devolver a correção POR QUESTÃO         ║
-- ║      (gabarito + acertou/errou + explicação) — revelada só DEPOIS  ║
-- ║      do envio, quando a nota já está travada (keep-first).         ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1 · RLS: questões só são lidas diretamente pelo dono da sala ──────────
-- O aluno (membro) deixa de ter SELECT na tabela `questions`. Ele obtém as
-- questões (sem gabarito) pela RPC get_student_phases abaixo.
drop policy if exists questions_read on public.questions;
create policy questions_read on public.questions
  for select to authenticated using (
    exists (
      select 1 from public.classroom_phases ph
      where ph.id = questions.phase_id
        and public.owns_classroom(ph.classroom_id)
    )
  );

-- ── 2 · Fases + questões do aluno, SEM o gabarito ────────────────────────
-- SECURITY DEFINER: ignora a RLS de `questions` (que agora é só do dono) e
-- devolve um JSON no MESMO formato do antigo `select('*, questions(*)')`,
-- mas omitindo correct_answer e explanation. Gate explícito por is_member.
create or replace function public.get_student_phases(p_classroom uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(
    jsonb_agg(
      to_jsonb(ph) || jsonb_build_object(
        'questions',
        coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id',           q.id,
              'phase_id',     q.phase_id,
              'text',         q.text,
              'options',      q.options,
              'type',         q.type,
              'image_url',    q.image_url,
              'image_author', q.image_author,
              'image_source', q.image_source,
              'sort_order',   q.sort_order
            )
            order by q.sort_order
          )
          from public.questions q
          where q.phase_id = ph.id
        ), '[]'::jsonb)
      )
      order by ph.sort_order
    ),
    '[]'::jsonb
  )
  from public.classroom_phases ph
  where ph.classroom_id = p_classroom
    and public.is_member(p_classroom);
$$;

revoke all     on function public.get_student_phases(uuid) from public, anon;
grant  execute on function public.get_student_phases(uuid) to authenticated;

-- ── 3 · submit_quiz devolve a correção por questão ───────────────────────
-- Mantém tudo da versão anterior (nota no servidor, keep-first, prêmios na 1ª
-- vez) e ADICIONA `questions`: o gabarito + acertou/errou + explicação de cada
-- questão. Seguro porque só sai DEPOIS do envio, com a nota já gravada. O
-- breakdown reflete as respostas RECÉM enviadas (em reenvio, a nota continua
-- sendo a da 1ª tentativa; o breakdown mostra o que o aluno acabou de marcar).
create or replace function public.submit_quiz(
  p_classroom uuid,
  p_phase     uuid,
  p_answers   jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_total   int;
  v_correct int;
  v_title   text;
  v_name    text;
  v_first   boolean := false;
  v_review  jsonb;
begin
  if not public.is_member(p_classroom) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;

  select title into v_title
    from public.classroom_phases
   where id = p_phase and classroom_id = p_classroom;
  if v_title is null then
    raise exception 'Fase não pertence a esta sala' using errcode = '22023';
  end if;

  select count(*) into v_total
    from public.questions where phase_id = p_phase;

  select count(*) into v_correct
    from public.questions q
   where q.phase_id = p_phase
     and (p_answers ->> q.id::text) ~ '^\d+$'
     and (p_answers ->> q.id::text)::int = q.correct_answer;

  with ins as (
    insert into public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers)
    values (p_classroom, auth.uid(), p_phase, v_total, v_correct)
    on conflict (classroom_id, student_id, phase_id) do nothing
    returning 1
  )
  select exists (select 1 from ins) into v_first;

  if v_first then
    update public.user_progress
       set xp    = xp + 15,
           gold  = gold + 5,
           level = greatest(level, public.level_for_xp(xp + 15))
     where user_id = auth.uid();

    select display_name into v_name from public.profiles where id = auth.uid();
    insert into public.classroom_activities (classroom_id, type, description)
    values (p_classroom, 'student_completed',
      coalesce(v_name, 'Um aluno') || ' concluiu a fase "' || v_title || '"');
  else
    select total_questions, correct_answers into v_total, v_correct
      from public.classroom_results
     where classroom_id = p_classroom
       and student_id = auth.uid()
       and phase_id = p_phase;
  end if;

  -- Correção por questão (revelada só agora, pós-envio).
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id',             q.id,
      'correct_answer', q.correct_answer,
      'chosen',         case when (p_answers ->> q.id::text) ~ '^\d+$'
                             then (p_answers ->> q.id::text)::int end,
      'is_correct',     (p_answers ->> q.id::text) ~ '^\d+$'
                          and (p_answers ->> q.id::text)::int = q.correct_answer,
      'explanation',    coalesce(q.explanation, '')
    )
    order by q.sort_order
  ), '[]'::jsonb) into v_review
  from public.questions q
  where q.phase_id = p_phase;

  return jsonb_build_object(
    'total',         v_total,
    'correct',       v_correct,
    'first_attempt', v_first,
    'questions',     v_review
  );
end;
$$;