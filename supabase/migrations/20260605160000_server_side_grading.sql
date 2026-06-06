-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Correção de nota NO SERVIDOR + prêmios atrelados ao resultado      ║
-- ║                                                                    ║
-- ║ Fase 1: submit_quiz recebe as RESPOSTAS, compara com o gabarito    ║
-- ║   (que nunca sai do banco) e grava a nota calculada no servidor.   ║
-- ║   O antigo submit_result (confiava na nota do cliente) é removido. ║
-- ║ Fase 3: XP/gold só sobem aqui, na 1ª conclusão (idempotente).      ║
-- ║   award_xp/award_gold deixam de ser chamáveis pelo cliente.        ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.submit_quiz(
  p_classroom uuid,
  p_phase     uuid,
  p_answers   jsonb default '{}'::jsonb   -- { "<question_id>": <índice escolhido>, ... }
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_total   int;
  v_correct int;
  v_title   text;
  v_name    text;
  v_first   boolean := false;
begin
  if not public.is_member(p_classroom) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;

  -- A fase precisa pertencer à sala (impede misturar fase de outra turma).
  select title into v_title
    from public.classroom_phases
   where id = p_phase and classroom_id = p_classroom;
  if v_title is null then
    raise exception 'Fase não pertence a esta sala' using errcode = '22023';
  end if;

  -- Total = nº de questões da fase (verdade do servidor; o aluno não escolhe).
  select count(*) into v_total
    from public.questions where phase_id = p_phase;

  -- Acertos = respostas cujo índice bate com o gabarito do banco.
  -- Chave ausente / valor não-numérico = errado.
  select count(*) into v_correct
    from public.questions q
   where q.phase_id = p_phase
     and (p_answers ->> q.id::text) ~ '^\d+$'
     and (p_answers ->> q.id::text)::int = q.correct_answer;

  -- Grava só na 1ª tentativa (keep-first por fase).
  with ins as (
    insert into public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers)
    values (p_classroom, auth.uid(), p_phase, v_total, v_correct)
    on conflict (classroom_id, student_id, phase_id) do nothing
    returning 1
  )
  select exists (select 1 from ins) into v_first;

  if v_first then
    -- Prêmios atrelados ao resultado verificado, só na 1ª vez.
    -- Escrita direta em user_progress (definer ignora a RLS); nível recalculado.
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
    -- Já havia resultado: devolve a nota GRAVADA (1ª tentativa), não a
    -- recalculada agora — mantém consistência com o "keep-first".
    select total_questions, correct_answers into v_total, v_correct
      from public.classroom_results
     where classroom_id = p_classroom
       and student_id = auth.uid()
       and phase_id = p_phase;
  end if;

  return jsonb_build_object(
    'total',         v_total,
    'correct',       v_correct,
    'first_attempt', v_first
  );
end;
$$;

revoke all     on function public.submit_quiz(uuid, uuid, jsonb) from public, anon;
grant  execute on function public.submit_quiz(uuid, uuid, jsonb) to authenticated;

-- ── Fase 1 · Aposentar o submit_result (confiava na nota do cliente) ──────
drop function if exists public.submit_result(uuid, int, int, uuid, text);

-- ── Fase 3 · XP/gold só pelo servidor — tirar award_* do alcance do cliente
-- (continuam usáveis internamente; submit_quiz nem os chama, escreve direto).
revoke execute on function public.award_xp(numeric)   from authenticated;
revoke execute on function public.award_gold(integer) from authenticated;
