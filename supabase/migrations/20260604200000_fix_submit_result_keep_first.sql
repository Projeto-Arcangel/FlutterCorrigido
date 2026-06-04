-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Fix: submit_result — Priorizar a primeira tentativa             ║
-- ║                                                                  ║
-- ║ Antes: ON CONFLICT … DO UPDATE (sobrescrevia o resultado).       ║
-- ║ Agora: ON CONFLICT … DO NOTHING (mantém o resultado original).  ║
-- ║ A atividade de conclusão continua sendo registrada normalmente.  ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.submit_result(
  p_classroom   uuid,
  p_total       int,
  p_correct     int,
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

  -- Insere apenas na primeira tentativa; tentativas subsequentes são
  -- ignoradas (DO NOTHING), priorizando o resultado original do aluno.
  insert into public.classroom_results
    (classroom_id, student_id, total_questions, correct_answers)
  values (p_classroom, auth.uid(), p_total, p_correct)
  on conflict (classroom_id, student_id) do nothing;

  select display_name into v_name from public.profiles where id = auth.uid();

  insert into public.classroom_activities (classroom_id, type, description)
  values (
    p_classroom, 'student_completed',
    coalesce(v_name, 'Um aluno') || ' concluiu'
      || coalesce(' a fase "' || p_phase_title || '"', '')
  );
end;
$$;
