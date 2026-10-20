-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Aviso de conquista ao terminar a fase                              ║
-- ║                                                                    ║
-- ║  Pedido do professor-dono do produto (2026-10-20): ao terminar a   ║
-- ║  fase, o aluno é parabenizado pelas conquistas alcançadas. O       ║
-- ║  resultado já trazia as conquistas por tipo; agora traz também as  ║
-- ║  de XP que a entrega fez alcançar (sem moedas, sem registro: elas  ║
-- ║  continuam valendo pelo XP, como antes).                           ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.finalize_attempt(p_attempt uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_att         public.phase_attempts%rowtype;
  v_total       int;
  v_score       numeric;
  v_pct         numeric;
  v_points      int;
  v_best_streak int;
  v_first       boolean;
  v_old_best    numeric;
  v_new_best    numeric;
  v_xp          int := 0;
  v_gold        int := 0;
  v_title       text;
  v_name        text;
  v_new         jsonb;
  v_xp_new      jsonb := '[]'::jsonb;
begin
  select * into v_att from public.phase_attempts where id = p_attempt for update;
  if not found then
    return null;
  end if;
  if v_att.finished_at is not null then
    return public.attempt_result(p_attempt);
  end if;

  -- Questões apagadas no meio do caminho saem da conta; as que ficaram
  -- sem resposta valem 0.
  select count(*) into v_total
    from unnest(v_att.question_ids) as t(qid)
   where exists (select 1 from public.questions q where q.id = t.qid);

  select coalesce(sum(x.score), 0), coalesce(sum(x.points), 0), coalesce(max(x.streak), 0)
    into v_score, v_points, v_best_streak
    from public.attempt_answers x
   where x.attempt_id = p_attempt and x.answered_at is not null;

  v_pct := case when v_total > 0 then round(v_score * 100 / v_total, 2) else 100 end;

  with ins as (
    insert into public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers, best_pct)
    values (v_att.classroom_id, v_att.student_id, v_att.phase_id, v_total, v_score, v_pct)
    on conflict (classroom_id, student_id, phase_id) do nothing
    returning 1
  )
  select exists (select 1 from ins) into v_first;

  if v_first then
    v_xp   := 5 + round(v_points / 5.0)::int;
    v_gold := 5 * public.phase_stars(v_pct);

    select title into v_title from public.classroom_phases where id = v_att.phase_id;
    select display_name into v_name from public.profiles where id = v_att.student_id;
    insert into public.classroom_activities (classroom_id, type, description)
    values (v_att.classroom_id, 'student_completed',
      coalesce(v_name, 'Um aluno') || ' concluiu a fase "' || coalesce(v_title, '') || '"');
  else
    -- Refazer: as respostas só são aceitas com a fase aberta, então a
    -- melhor nota pode subir. Moedas só por estrela nova.
    select coalesce(best_pct,
                    case when total_questions > 0
                         then round(correct_answers * 100.0 / total_questions, 2)
                         else 100 end)
      into v_old_best
      from public.classroom_results
     where classroom_id = v_att.classroom_id and student_id = v_att.student_id
       and phase_id = v_att.phase_id
       for update;
    v_new_best := greatest(v_old_best, v_pct);
    update public.classroom_results
       set best_pct = v_new_best
     where classroom_id = v_att.classroom_id and student_id = v_att.student_id
       and phase_id = v_att.phase_id;
    v_gold := 5 * greatest(0, public.phase_stars(v_new_best) - public.phase_stars(v_old_best));
  end if;

  if v_xp > 0 or v_gold > 0 then
    update public.user_progress
       set xp    = xp + v_xp,
           gold  = gold + v_gold,
           level = greatest(level, public.level_for_xp(xp + v_xp))
     where user_id = v_att.student_id;
  end if;

  -- Conquistas de XP que ESTA entrega fez alcançar (o XP de antes não
  -- chegava, o de agora chega). Não têm registro nem moedas: valem pelo XP,
  -- mas entram no aviso de conquista do resultado.
  if v_xp > 0 then
    select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title', a.title, 'gold', 0)
                              order by a.sort_order), '[]'::jsonb)
      into v_xp_new
      from public.achievements a
      join public.user_progress up on up.user_id = v_att.student_id
     where a.criterion = 'xp'
       and a.xp_required > up.xp - v_xp
       and a.xp_required <= up.xp;
  end if;

  -- Conquistas por tipo que esta entrega completou (moedas creditadas
  -- dentro de award_achievements), depois as de XP.
  v_new := public.award_achievements(v_att.student_id) || v_xp_new;

  update public.phase_attempts
     set achievements = v_new,
         finished_at  = now(),
         total        = v_total,
         score        = v_score,
         pct          = v_pct,
         points       = v_points,
         best_streak  = v_best_streak,
         official     = v_first,
         xp_awarded   = v_xp,
         gold_awarded = v_gold
   where id = p_attempt;

  return public.attempt_result(p_attempt);
end;
$$;

-- ── Privilégios (regra da migration 20261008120000) ─────────────────
-- create or replace mantém os privilégios; reafirmados aqui: só o servidor.
revoke all on function public.finalize_attempt(uuid) from public, anon, authenticated;
grant execute on function public.finalize_attempt(uuid) to service_role;
