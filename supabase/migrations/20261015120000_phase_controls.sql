-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Controles do professor por fase — base do Estágio 4                 ║
-- ║ (novos tipos de questão + gamificação)                              ║
-- ║                                                                    ║
-- ║  classroom_phases ganha:                                           ║
-- ║   - opens_at / closes_at: janela em que a fase aceita respostas    ║
-- ║     (ambas opcionais);                                             ║
-- ║   - timer_enabled / timer_level: relógio por questão (o efeito     ║
-- ║     entra com o fluxo de tentativas; aqui fica só o ajuste);       ║
-- ║   - pass_pct: nota mínima (%) para liberar a próxima fase.         ║
-- ║                                                                    ║
-- ║  classroom_results ganha best_pct: a melhor nota do aluno na fase. ║
-- ║  A nota oficial continua a da 1ª tentativa (correct_answers); a    ║
-- ║  melhor serve para liberar a próxima fase (e, depois, estrelas).   ║
-- ║                                                                    ║
-- ║  O estado de cada fase para o aluno (agendada/aberta/encerrada e   ║
-- ║  bloqueada) é calculado num lugar só, student_phase_states, usado  ║
-- ║  pela get_student_phases (o app só exibe) e pela submit_quiz (que  ║
-- ║  recusa o que o app não deixaria fazer). Regras:                   ║
-- ║   - as fases liberam em ordem: uma fase só abre depois que todas   ║
-- ║     as anteriores estão "cumpridas";                               ║
-- ║   - cumprida = sem questões, ou respondida com a melhor nota ≥     ║
-- ║     nota mínima (se houver), ou encerrada — a fase que fecha não   ║
-- ║     trava o aluno, mesmo sem nota ou sem resposta (decisão do      ║
-- ║     professor-dono do produto).                                    ║
-- ║                                                                    ║
-- ║  Aditivo e retrocompatível: o app em produção ignora as colunas e  ║
-- ║  campos novos, e sem datas/nota mínima tudo funciona como antes.   ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Ajustes da fase ───────────────────────────────────────────────
alter table public.classroom_phases
  add column opens_at      timestamptz,
  add column closes_at     timestamptz,
  add column timer_enabled boolean not null default false,
  add column timer_level   text not null default 'normal'
    constraint classroom_phases_timer_level_check
      check (timer_level in ('short', 'normal', 'long')),
  add column pass_pct      numeric(5, 2)
    constraint classroom_phases_pass_pct_check
      check (pass_pct is null or (pass_pct > 0 and pass_pct <= 100)),
  add constraint classroom_phases_dates_order_check
    check (opens_at is null or closes_at is null or closes_at > opens_at);

comment on column public.classroom_phases.opens_at is
  'Quando a fase passa a aceitar respostas (NULL = sempre aberta).';
comment on column public.classroom_phases.closes_at is
  'Quando a fase para de aceitar respostas (NULL = sem prazo).';
comment on column public.classroom_phases.pass_pct is
  'Nota mínima (%) para liberar a próxima fase (NULL = basta concluir).';

-- ── 2. Melhor nota do aluno na fase ──────────────────────────────────
alter table public.classroom_results
  add column best_pct numeric(5, 2)
    constraint classroom_results_best_pct_check
      check (best_pct is null or (best_pct >= 0 and best_pct <= 100));

comment on column public.classroom_results.best_pct is
  'Melhor nota (%) do aluno na fase. NULL em resultados antigos = a da 1ª tentativa.';

-- ── 3. Estado de cada fase para um aluno ─────────────────────────────
-- Só para outras funções do servidor: recebe um aluno qualquer.
create or replace function public.student_phase_states(p_classroom uuid, p_student uuid)
returns table (
  phase_id  uuid,
  status    text,     -- 'scheduled' (ainda não abriu) | 'open' | 'closed'
  locked    boolean,  -- falta cumprir uma fase anterior
  completed boolean,  -- o aluno já respondeu
  score_pct numeric,  -- nota oficial (%), a da 1ª tentativa; NULL se não respondeu
  best_pct  numeric   -- melhor nota (%), NULL se ainda não respondeu
)
language plpgsql stable security definer set search_path = public as $$
declare
  r        record;
  v_ok     boolean := true;  -- todas as fases anteriores estão cumpridas
  v_passed boolean;
begin
  for r in
    select ph.id, ph.opens_at, ph.closes_at, ph.pass_pct,
           exists (select 1 from public.questions q where q.phase_id = ph.id)
             as has_questions,
           res.id is not null as done,
           case when res.total_questions > 0
                then round(res.correct_answers * 100.0 / res.total_questions, 2)
                else 100 end as first_pct,
           coalesce(
             res.best_pct,
             case when res.total_questions > 0
                  then round(res.correct_answers * 100.0 / res.total_questions, 2)
                  else 100 end
           ) as pct
      from public.classroom_phases ph
      left join public.classroom_results res
        on res.phase_id = ph.id
       and res.classroom_id = p_classroom
       and res.student_id = p_student
     where ph.classroom_id = p_classroom
     order by ph.sort_order, ph.created_at, ph.id
  loop
    phase_id  := r.id;
    status    := case
                   when r.opens_at is not null and now() < r.opens_at then 'scheduled'
                   when r.closes_at is not null and now() > r.closes_at then 'closed'
                   else 'open'
                 end;
    locked    := not v_ok;
    completed := r.done;
    score_pct := case when r.done then r.first_pct end;
    best_pct  := case when r.done then r.pct end;
    v_passed  := not r.has_questions
                 or (r.done and (r.pass_pct is null or r.pct >= r.pass_pct))
                 or status = 'closed';
    v_ok      := v_ok and v_passed;
    return next;
  end loop;
end;
$$;

-- ── 4. Fases do aluno, com o estado de cada uma ──────────────────────
-- Mesmo formato da versão anterior (fase + questões SEM gabarito), com
-- status/locked/completed/best_pct. Os ajustes da fase (datas, nota
-- mínima, relógio) já vêm em to_jsonb(ph).
create or replace function public.get_student_phases(p_classroom uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(
    jsonb_agg(
      to_jsonb(ph) || jsonb_build_object(
        'status',    s.status,
        'locked',    s.locked,
        'completed', s.completed,
        'score_pct', s.score_pct,
        'best_pct',  s.best_pct,
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
  join public.student_phase_states(p_classroom, auth.uid()) s on s.phase_id = ph.id
  where ph.classroom_id = p_classroom
    and public.is_member(p_classroom);
$$;

-- ── 5. submit_quiz respeita o estado da fase e guarda a melhor nota ──
-- Mantém tudo da versão anterior (nota no servidor, 1ª tentativa vale,
-- prêmios na 1ª vez, correção por questão revelada só no envio) e:
--   - um NOVO envio é recusado se a fase ainda não abriu, já fechou ou
--     está bloqueada (quem já respondeu continua podendo rever);
--   - refazer com a fase aberta atualiza a melhor nota (best_pct), que é
--     o que libera a próxima fase; a nota oficial não muda.
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
  v_pct     numeric;
  v_best    numeric;
  v_title   text;
  v_status  text;
  v_locked  boolean;
  v_name    text;
  v_first   boolean := false;
  v_has     boolean;
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

  select s.status, s.locked into v_status, v_locked
    from public.student_phase_states(p_classroom, auth.uid()) s
   where s.phase_id = p_phase;

  select exists (
    select 1 from public.classroom_results
     where classroom_id = p_classroom and student_id = auth.uid()
       and phase_id = p_phase
  ) into v_has;

  -- Só um NOVO envio é recusado; quem já respondeu continua revendo.
  if not v_has then
    if v_status = 'scheduled' then
      raise exception 'Esta fase ainda não abriu.' using errcode = '22023';
    end if;
    if v_status = 'closed' then
      raise exception 'Esta fase já fechou e não aceita mais respostas.'
        using errcode = '22023';
    end if;
    if v_locked then
      raise exception 'Conclua a fase anterior para liberar esta.'
        using errcode = '22023';
    end if;
  end if;

  -- Correção deste envio.
  select count(*) into v_total
    from public.questions where phase_id = p_phase;

  select count(*) into v_correct
    from public.questions q
   where q.phase_id = p_phase
     and (p_answers ->> q.id::text) ~ '^\d+$'
     and (p_answers ->> q.id::text)::int = q.correct_answer;

  v_pct := case when v_total > 0
                then round(v_correct * 100.0 / v_total, 2)
                else 100 end;

  with ins as (
    insert into public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers, best_pct)
    values (p_classroom, auth.uid(), p_phase, v_total, v_correct, v_pct)
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
    -- Refazer: com a fase aberta, a melhor nota pode subir.
    if v_status = 'open' then
      update public.classroom_results
         set best_pct = greatest(
               coalesce(best_pct,
                        case when total_questions > 0
                             then round(correct_answers * 100.0 / total_questions, 2)
                             else 100 end),
               v_pct)
       where classroom_id = p_classroom
         and student_id = auth.uid()
         and phase_id = p_phase;
    end if;

    -- A nota oficial continua a da 1ª tentativa.
    select total_questions, correct_answers into v_total, v_correct
      from public.classroom_results
     where classroom_id = p_classroom
       and student_id = auth.uid()
       and phase_id = p_phase;
  end if;

  select s.best_pct into v_best
    from public.student_phase_states(p_classroom, auth.uid()) s
   where s.phase_id = p_phase;

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
    'attempt_pct',   v_pct,
    'best_pct',      v_best,
    'questions',     v_review
  );
end;
$$;

-- ── 6. Privilégios (regra da migration 20261008120000) ──────────────
-- student_phase_states recebe um aluno qualquer: só o servidor chama.
revoke all on function public.student_phase_states(uuid, uuid) from public, anon, authenticated;
grant execute on function public.student_phase_states(uuid, uuid) to service_role;

-- create or replace mantém os privilégios; reafirmados aqui.
revoke all on function public.get_student_phases(uuid)         from public, anon;
revoke all on function public.submit_quiz(uuid, uuid, jsonb)   from public, anon;
grant execute on function public.get_student_phases(uuid)       to authenticated, service_role;
grant execute on function public.submit_quiz(uuid, uuid, jsonb) to authenticated, service_role;
