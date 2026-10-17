-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Tentativas resposta a resposta — Estágio 4, Etapa 1 (fatia 3)       ║
-- ║                                                                    ║
-- ║  Antes: o aluno mandava todas as respostas no fim (submit_quiz).   ║
-- ║  Agora a fase é jogada numa TENTATIVA guardada no servidor:        ║
-- ║   - start_attempt: abre (ou retoma) a tentativa e devolve as       ║
-- ║     questões SEM gabarito, na ordem fixada no início;              ║
-- ║   - open_question: com relógio, marca quando a questão apareceu;   ║
-- ║   - answer_question: corrige NO SERVIDOR, trava a resposta e já    ║
-- ║     diz se acertou (a explicação só vem no fim da fase). A última  ║
-- ║     resposta encerra a tentativa e devolve o resultado.            ║
-- ║                                                                    ║
-- ║  Regras do jogo (decisões confirmadas do Estágio 4):               ║
-- ║   - cada questão vale de 0 a 1 (nota parcial; múltipla escolha     ║
-- ║     é 0 ou 1, os novos tipos darão frações);                       ║
-- ║   - nota oficial = 1ª tentativa ENTREGUE; estrelas e desbloqueio   ║
-- ║     usam a melhor (best_pct);                                      ║
-- ║   - estrelas: 1 a partir de 60%, 2 a partir de 80%, 3 com 100%;    ║
-- ║   - sequência de acertos: ×1,5 a partir de 3 seguidos, ×2 a partir ║
-- ║     de 5 (só acerto inteiro continua a sequência);                 ║
-- ║   - relógio: tempo por questão conforme o tamanho do texto e o     ║
-- ║     nível da fase; o servidor confere com 3 s de folga; tempo      ║
-- ║     esgotado = questão vale 0;                                     ║
-- ║   - pontos por questão: 10 × nota × multiplicador, + até 5 pelo    ║
-- ║     tempo que sobrou (com relógio);                                ║
-- ║   - XP só na 1ª entrega: 5 + pontos/5; moedas: 5 por estrela nova  ║
-- ║     (refazer só rende moedas se ganhar estrela; nada de farm).     ║
-- ║                                                                    ║
-- ║  Tentativa pela metade não recomeça: ao voltar, o aluno continua   ║
-- ║  de onde parou (senão daria para ver o gabarito da 1ª questão e    ║
-- ║  recomeçar a tentativa oficial). Se a fase fecha antes de ele      ║
-- ║  terminar, a tentativa é entregue com o que foi respondido (o      ║
-- ║  resto vale 0) — na próxima leitura do aluno ou do professor.      ║
-- ║                                                                    ║
-- ║  Retrocompatível: o submit_quiz do app em produção continua, mas   ║
-- ║  recusa a 1ª entrega quando o aluno já começou pelo fluxo novo ou  ║
-- ║  quando a fase usa relógio (que o app antigo não conhece).         ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Nota parcial: acertos fracionários ───────────────────────────
alter table public.classroom_results
  alter column correct_answers type numeric(8, 3);

comment on column public.classroom_results.correct_answers is
  'Acertos da 1ª tentativa entregue (nota oficial). Cada questão vale de 0 a 1, então pode ser fracionário (ex.: 2,5 de 3).';

-- ── 2. Tentativas ────────────────────────────────────────────────────
create table public.phase_attempts (
  id            uuid primary key default gen_random_uuid(),
  classroom_id  uuid not null references public.classrooms (id)       on delete cascade,
  phase_id      uuid not null references public.classroom_phases (id) on delete cascade,
  student_id    uuid not null references public.profiles (id)         on delete cascade,
  attempt_no    int  not null check (attempt_no >= 1),
  -- Ordem das questões fixada no início (questões novas não entram).
  question_ids  uuid[] not null,
  -- Relógio como estava quando a tentativa começou.
  timer_enabled boolean not null,
  timer_level   text not null check (timer_level in ('short', 'normal', 'long')),
  started_at    timestamptz not null default now(),
  finished_at   timestamptz,
  -- Preenchidos ao entregar.
  total         int,
  score         numeric(8, 3),
  pct           numeric(5, 2),
  points        int,
  best_streak   int,
  official      boolean,          -- virou a nota oficial (1ª entrega)
  xp_awarded    int not null default 0,
  gold_awarded  int not null default 0,
  unique (phase_id, student_id, attempt_no)
);

-- No máximo uma tentativa em andamento por aluno e fase.
create unique index phase_attempts_one_open
  on public.phase_attempts (phase_id, student_id) where finished_at is null;
create index phase_attempts_open_by_classroom
  on public.phase_attempts (classroom_id) where finished_at is null;
create index phase_attempts_student_idx on public.phase_attempts (student_id);

comment on table public.phase_attempts is
  'Tentativas dos alunos nas fases (Estágio 4). Só o servidor lê e escreve: o app usa start_attempt/open_question/answer_question.';

create table public.attempt_answers (
  attempt_id   uuid not null references public.phase_attempts (id) on delete cascade,
  question_id  uuid not null references public.questions (id)      on delete cascade,
  seq          int  not null,           -- posição na tentativa (1..n)
  presented_at timestamptz,             -- relógio: quando a questão apareceu
  limit_s      int,                     -- relógio: segundos para responder
  answered_at  timestamptz,
  response     jsonb,                   -- o que o aluno marcou (NULL = sem resposta)
  score        numeric(4, 3) check (score between 0 and 1),
  timed_out    boolean not null default false,
  streak       int,                     -- sequência de acertos depois desta resposta
  points       int,
  primary key (attempt_id, question_id)
);

comment on table public.attempt_answers is
  'Respostas de cada tentativa, corrigidas no servidor e travadas ao confirmar.';

-- ── 3. Regras do jogo ────────────────────────────────────────────────
create or replace function public.phase_stars(p_pct numeric)
returns int language sql immutable set search_path = '' as $$
  select case
           when p_pct is null then 0
           when p_pct >= 100 then 3
           when p_pct >= 80  then 2
           when p_pct >= 60  then 1
           else 0
         end;
$$;

create or replace function public.streak_multiplier(p_streak int)
returns numeric language sql immutable set search_path = '' as $$
  select case when p_streak >= 5 then 2.0
              when p_streak >= 3 then 1.5
              else 1.0 end;
$$;

-- Tempo para responder (s): ~20 s + 1 s a cada 12 caracteres de enunciado
-- e alternativas, ajustado pelo nível (curto ×0,6, longo ×1,5), em
-- múltiplos de 5, entre 15 s e 5 min.
create or replace function public.question_time_limit(q public.questions, p_level text)
returns int language sql immutable set search_path = '' as $$
  select least(300, greatest(15, (round(
    (20 + (length(q.text)
           + coalesce((select sum(length(o)) from unnest(q.options) o), 0)) / 12.0)
    * case p_level when 'short' then 0.6 when 'long' then 1.5 else 1.0 end
    / 5) * 5)::int));
$$;

-- Nota de uma resposta, de 0 a 1. Cada tipo novo entra aqui.
create or replace function public.grade_response(q public.questions, p_response jsonb)
returns numeric language plpgsql immutable set search_path = '' as $$
begin
  if p_response is null or jsonb_typeof(p_response) <> 'object' then
    return 0;
  end if;
  case q.type
    when 'multiple_choice', 'true_false' then
      return case when (p_response ->> 'choice') ~ '^\d{1,3}$'
                   and (p_response ->> 'choice')::int = q.correct_answer
                  then 1 else 0 end;
    else
      raise exception 'Tipo de questão ainda não suportado: %', q.type
        using errcode = '0A000';
  end case;
end;
$$;

-- O que o aluno pode ver da questão (sem gabarito nem explicação).
create or replace function public.question_public(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'id',           q.id,
    'phase_id',     q.phase_id,
    'text',         q.text,
    'options',      q.options,
    'type',         q.type,
    'image_url',    q.image_url,
    'image_author', q.image_author,
    'image_source', q.image_source,
    'sort_order',   q.sort_order
  );
$$;

-- Gabarito de UMA questão, revelado depois que a resposta trava.
create or replace function public.question_reveal(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('correct_answer', q.correct_answer);
$$;

-- ── 4. Peças internas da tentativa ──────────────────────────────────
-- Próxima questão a responder: a primeira, na ordem, que ainda existe e
-- não foi respondida. (NULL, NULL) quando não falta nenhuma.
create or replace function public.attempt_next_question(
  p_attempt uuid, out question_id uuid, out seq int
)
language sql stable set search_path = '' as $$
  select t.qid, t.ord::int
    from public.phase_attempts a
    cross join lateral unnest(a.question_ids) with ordinality as t(qid, ord)
    join public.questions q on q.id = t.qid
   where a.id = p_attempt
     and not exists (
       select 1 from public.attempt_answers x
        where x.attempt_id = a.id and x.question_id = t.qid
          and x.answered_at is not null)
   order by t.ord
   limit 1;
$$;

-- Questão aberta cujo tempo (com 3 s de folga) acabou: trava valendo 0.
create or replace function public.attempt_expire(p_attempt uuid)
returns void language sql set search_path = '' as $$
  update public.attempt_answers x
     set answered_at = x.presented_at + make_interval(secs => x.limit_s),
         response    = null,
         score       = 0,
         timed_out   = true,
         streak      = 0,
         points      = 0
   where x.attempt_id = p_attempt
     and x.answered_at is null
     and x.presented_at is not null
     and now() > x.presented_at + make_interval(secs => x.limit_s + 3);
$$;

-- Retorno de uma resposta já travada.
create or replace function public.answer_feedback(p_attempt uuid, p_question uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'question_id', x.question_id,
    'score',       x.score,
    'correct',     x.score >= 1,
    'timed_out',   x.timed_out,
    'streak',      x.streak,
    'multiplier',  public.streak_multiplier(x.streak),
    'points',      x.points,
    'reveal',      public.question_reveal(q)
  )
  from public.attempt_answers x
  join public.questions q on q.id = x.question_id
  where x.attempt_id = p_attempt and x.question_id = p_question
    and x.answered_at is not null;
$$;

-- Resultado de uma tentativa ENTREGUE, com a correção completa.
create or replace function public.attempt_result(p_attempt uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'attempt_id',    a.id,
    'attempt_no',    a.attempt_no,
    'first_attempt', a.official,
    'total',         a.total,
    'score',         a.score,
    'pct',           a.pct,
    'stars',         public.phase_stars(a.pct),
    'points',        a.points,
    'best_streak',   a.best_streak,
    'xp',            a.xp_awarded,
    'gold',          a.gold_awarded,
    'official', jsonb_build_object(
      'total',   r.total_questions,
      'correct', r.correct_answers,
      'pct',     o.pct
    ),
    'best_pct',   b.best,
    'best_stars', public.phase_stars(b.best),
    'review', coalesce((
      select jsonb_agg(jsonb_build_object(
               'question_id', q.id,
               'score',       coalesce(x.score, 0),
               'correct',     coalesce(x.score, 0) >= 1,
               'answered',    x.answered_at is not null,
               'timed_out',   coalesce(x.timed_out, false),
               'response',    x.response,
               'reveal',      public.question_reveal(q),
               'explanation', coalesce(q.explanation, '')
             ) order by t.ord)
        from unnest(a.question_ids) with ordinality as t(qid, ord)
        join public.questions q on q.id = t.qid
        left join public.attempt_answers x
          on x.attempt_id = a.id and x.question_id = q.id
    ), '[]'::jsonb)
  )
  from public.phase_attempts a
  left join public.classroom_results r
    on r.classroom_id = a.classroom_id and r.student_id = a.student_id
   and r.phase_id = a.phase_id
  cross join lateral (
    select case when r.total_questions > 0
                then round(r.correct_answers * 100.0 / r.total_questions, 2)
                else 100 end as pct
  ) o
  cross join lateral (select coalesce(r.best_pct, o.pct) as best) b
  where a.id = p_attempt and a.finished_at is not null;
$$;

-- Entrega a tentativa: soma a nota, grava a oficial (1ª entrega) ou a
-- melhor, dá XP/moedas. Idempotente: entregue de novo, só devolve.
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

  update public.phase_attempts
     set finished_at  = now(),
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

-- Fase que fechou com tentativa pela metade: entrega com o que houver.
-- Chamada nas leituras (aluno: só as dele; professor: a turma toda).
create or replace function public.close_overdue_attempts(p_classroom uuid, p_student uuid default null)
returns int language plpgsql security definer set search_path = public as $$
declare
  r record;
  n int := 0;
begin
  for r in
    select a.id
      from public.phase_attempts a
      join public.classroom_phases ph on ph.id = a.phase_id
     where a.classroom_id = p_classroom
       and a.finished_at is null
       and (p_student is null or a.student_id = p_student)
       and ph.closes_at is not null and ph.closes_at < now()
     order by a.id
  loop
    perform public.finalize_attempt(r.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Estado da tentativa para o app (questões, respostas já travadas, onde
-- parou, relógio da questão aberta). Entregue: vem com o resultado.
create or replace function public.attempt_state(p_attempt uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'attempt_id',    a.id,
    'phase_id',      a.phase_id,
    'attempt_no',    a.attempt_no,
    'first_attempt', not exists (
                       select 1 from public.classroom_results r
                        where r.classroom_id = a.classroom_id
                          and r.student_id = a.student_id
                          and r.phase_id = a.phase_id),
    'timer_enabled', a.timer_enabled,
    'timer_level',   a.timer_level,
    'questions', coalesce((
      select jsonb_agg(
               public.question_public(q)
               || jsonb_build_object('limit_s',
                    case when a.timer_enabled
                         then public.question_time_limit(q, a.timer_level) end)
               order by t.ord)
        from unnest(a.question_ids) with ordinality as t(qid, ord)
        join public.questions q on q.id = t.qid
    ), '[]'::jsonb),
    'answers', coalesce((
      select jsonb_agg(public.answer_feedback(a.id, x.question_id) order by x.seq)
        from public.attempt_answers x
       where x.attempt_id = a.id and x.answered_at is not null
    ), '[]'::jsonb),
    'points', coalesce((
      select sum(x.points) from public.attempt_answers x
       where x.attempt_id = a.id and x.answered_at is not null), 0),
    'streak', coalesce((
      select x.streak from public.attempt_answers x
       where x.attempt_id = a.id and x.answered_at is not null
       order by x.seq desc limit 1), 0),
    'next_question_id', n.question_id,
    'opened', (
      select jsonb_build_object(
               'question_id', x.question_id,
               'limit_s',     x.limit_s,
               'elapsed_s',   round(extract(epoch from now() - x.presented_at)::numeric, 1))
        from public.attempt_answers x
       where x.attempt_id = a.id and x.question_id = n.question_id
         and x.answered_at is null and x.presented_at is not null),
    'finished', a.finished_at is not null,
    'result',   case when a.finished_at is not null
                     then public.attempt_result(a.id) end
  )
  from public.phase_attempts a
  cross join lateral public.attempt_next_question(a.id) n
  where a.id = p_attempt;
$$;

-- ── 5. Estado das fases para o aluno (com estrelas e "em andamento") ─
-- Mudou o formato do retorno: precisa recriar.
drop function public.student_phase_states(uuid, uuid);

create function public.student_phase_states(p_classroom uuid, p_student uuid)
returns table (
  phase_id    uuid,
  status      text,     -- 'scheduled' (ainda não abriu) | 'open' | 'closed'
  locked      boolean,  -- falta cumprir uma fase anterior
  completed   boolean,  -- o aluno já entregou
  score_pct   numeric,  -- nota oficial (%), a da 1ª entrega; NULL se não entregou
  best_pct    numeric,  -- melhor nota (%), NULL se ainda não entregou
  stars       int,      -- estrelas da melhor nota (0 a 3)
  in_progress boolean   -- tem tentativa começada e não entregue
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
           exists (select 1 from public.phase_attempts a
                    where a.phase_id = ph.id and a.student_id = p_student
                      and a.finished_at is null) as open_attempt,
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
    phase_id    := r.id;
    status      := case
                     when r.opens_at is not null and now() < r.opens_at then 'scheduled'
                     when r.closes_at is not null and now() > r.closes_at then 'closed'
                     else 'open'
                   end;
    locked      := not v_ok;
    completed   := r.done;
    score_pct   := case when r.done then r.first_pct end;
    best_pct    := case when r.done then r.pct end;
    stars       := case when r.done then public.phase_stars(r.pct) else 0 end;
    in_progress := r.open_attempt;
    v_passed    := not r.has_questions
                   or (r.done and (r.pass_pct is null or r.pct >= r.pass_pct))
                   or status = 'closed';
    v_ok        := v_ok and v_passed;
    return next;
  end loop;
end;
$$;

-- Agora entrega as tentativas vencidas antes de ler: deixa de ser stable.
create or replace function public.get_student_phases(p_classroom uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_member(p_classroom) then
    return '[]'::jsonb;
  end if;
  perform public.close_overdue_attempts(p_classroom, auth.uid());

  return (
    select coalesce(
      jsonb_agg(
        to_jsonb(ph) || jsonb_build_object(
          'status',      s.status,
          'locked',      s.locked,
          'completed',   s.completed,
          'score_pct',   s.score_pct,
          'best_pct',    s.best_pct,
          'stars',       s.stars,
          'in_progress', s.in_progress,
          'questions',
          coalesce((
            select jsonb_agg(public.question_public(q) order by q.sort_order)
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
  );
end;
$$;

-- ── 6. RPCs do aluno ─────────────────────────────────────────────────
-- Recusa responder fora da janela da fase (vale para retomar também).
create or replace function public.assert_phase_open(p_phase uuid)
returns void language plpgsql stable set search_path = '' as $$
declare
  v_opens  timestamptz;
  v_closes timestamptz;
begin
  select opens_at, closes_at into v_opens, v_closes
    from public.classroom_phases where id = p_phase;
  if v_opens is not null and now() < v_opens then
    raise exception 'Esta fase ainda não abriu.' using errcode = '22023';
  end if;
  if v_closes is not null and now() > v_closes then
    raise exception 'Esta fase já fechou e não aceita mais respostas.'
      using errcode = '22023';
  end if;
end;
$$;

-- Abre uma tentativa (ou retoma a que está pela metade).
create or replace function public.start_attempt(p_classroom uuid, p_phase uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_phase  public.classroom_phases%rowtype;
  v_state  record;
  v_id     uuid;
  v_ids    uuid[];
  v_no     int;
begin
  if auth.uid() is null or not public.is_member(p_classroom) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;

  select * into v_phase
    from public.classroom_phases
   where id = p_phase and classroom_id = p_classroom;
  if not found then
    raise exception 'Fase não pertence a esta sala' using errcode = '22023';
  end if;

  -- Uma abertura por vez para o mesmo aluno e fase.
  perform pg_advisory_xact_lock(
    hashtextextended('phase_attempt:' || p_phase::text || ':' || auth.uid()::text, 0));

  perform public.close_overdue_attempts(p_classroom, auth.uid());

  select id into v_id
    from public.phase_attempts
   where phase_id = p_phase and student_id = auth.uid() and finished_at is null;

  if v_id is not null then
    -- Retomar: fora da janela não continua; questão aberta com o tempo
    -- estourado trava valendo 0; sem questões pendentes, entrega.
    perform public.assert_phase_open(p_phase);
    perform public.attempt_expire(v_id);
    if (public.attempt_next_question(v_id)).question_id is null then
      perform public.finalize_attempt(v_id);
    end if;
    return public.attempt_state(v_id);
  end if;

  -- Nova tentativa: as mesmas regras da trilha.
  select s.status, s.locked, s.completed into v_state
    from public.student_phase_states(p_classroom, auth.uid()) s
   where s.phase_id = p_phase;
  if v_state.status = 'scheduled' then
    raise exception 'Esta fase ainda não abriu.' using errcode = '22023';
  end if;
  if v_state.status = 'closed' then
    raise exception 'Esta fase já fechou e não aceita mais respostas.'
      using errcode = '22023';
  end if;
  if v_state.locked and not v_state.completed then
    raise exception 'Conclua a fase anterior para liberar esta.'
      using errcode = '22023';
  end if;

  select array_agg(q.id order by q.sort_order, q.created_at, q.id) into v_ids
    from public.questions q where q.phase_id = p_phase;
  if v_ids is null then
    raise exception 'Esta fase ainda não tem perguntas.' using errcode = '22023';
  end if;

  select coalesce(max(attempt_no), 0) + 1 into v_no
    from public.phase_attempts
   where phase_id = p_phase and student_id = auth.uid();

  insert into public.phase_attempts
    (classroom_id, phase_id, student_id, attempt_no, question_ids, timer_enabled, timer_level)
  values
    (p_classroom, p_phase, auth.uid(), v_no, v_ids, v_phase.timer_enabled, v_phase.timer_level)
  returning id into v_id;

  return public.attempt_state(v_id);
end;
$$;

-- Com relógio: marca a hora em que a questão apareceu. Chamar de novo
-- não reinicia o tempo.
create or replace function public.open_question(p_attempt uuid, p_question uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_att  public.phase_attempts%rowtype;
  v_next record;
  v_q    public.questions%rowtype;
  v_row  public.attempt_answers%rowtype;
begin
  select * into v_att from public.phase_attempts
   where id = p_attempt and student_id = auth.uid()
     for update;
  if not found then
    raise exception 'Tentativa não encontrada.' using errcode = '22023';
  end if;
  if v_att.finished_at is not null then
    raise exception 'Esta tentativa já terminou.' using errcode = '22023';
  end if;
  if not public.is_member(v_att.classroom_id) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;
  perform public.assert_phase_open(v_att.phase_id);

  if not v_att.timer_enabled then
    return jsonb_build_object('question_id', p_question, 'limit_s', null,
                              'elapsed_s', 0, 'answered', false);
  end if;

  perform public.attempt_expire(p_attempt);
  if exists (select 1 from public.attempt_answers
              where attempt_id = p_attempt and question_id = p_question
                and answered_at is not null) then
    return jsonb_build_object('question_id', p_question, 'answered', true,
                              'feedback', public.answer_feedback(p_attempt, p_question));
  end if;

  select * into v_next from public.attempt_next_question(p_attempt);
  if v_next.question_id is distinct from p_question then
    raise exception 'Responda as questões na ordem.' using errcode = '22023';
  end if;

  select * into v_q from public.questions where id = p_question;
  insert into public.attempt_answers (attempt_id, question_id, seq, presented_at, limit_s)
  values (p_attempt, p_question, v_next.seq, now(),
          public.question_time_limit(v_q, v_att.timer_level))
  on conflict (attempt_id, question_id) do nothing;

  select * into v_row from public.attempt_answers
   where attempt_id = p_attempt and question_id = p_question;
  return jsonb_build_object(
    'question_id', p_question,
    'limit_s',     v_row.limit_s,
    'elapsed_s',   round(extract(epoch from now() - v_row.presented_at)::numeric, 1),
    'answered',    false
  );
end;
$$;

-- Corrige e trava UMA resposta. p_response da múltipla escolha:
-- {"choice": 2}; NULL = sem resposta (tempo esgotado). Reenviar a mesma
-- questão devolve o que já foi gravado (rede instável). A última
-- resposta entrega a tentativa e vem com o resultado.
create or replace function public.answer_question(
  p_attempt  uuid,
  p_question uuid,
  p_response jsonb default null
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_att     public.phase_attempts%rowtype;
  v_next    record;
  v_q       public.questions%rowtype;
  v_row     public.attempt_answers%rowtype;
  v_elapsed numeric;
  v_timed   boolean := false;
  v_score   numeric;
  v_streak  int;
  v_mult    numeric;
  v_bonus   numeric := 0;
  v_points  int;
  v_result  jsonb;
begin
  select * into v_att from public.phase_attempts
   where id = p_attempt and student_id = auth.uid()
     for update;
  if not found then
    raise exception 'Tentativa não encontrada.' using errcode = '22023';
  end if;

  if v_att.finished_at is not null then
    if exists (select 1 from public.attempt_answers
                where attempt_id = p_attempt and question_id = p_question
                  and answered_at is not null) then
      return public.answer_feedback(p_attempt, p_question)
             || jsonb_build_object('finished', true,
                                   'result', public.attempt_result(p_attempt));
    end if;
    raise exception 'Esta tentativa já terminou.' using errcode = '22023';
  end if;

  if not public.is_member(v_att.classroom_id) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;
  -- A resposta é guardada como veio: nada de JSON gigante no banco.
  if p_response is not null and octet_length(p_response::text) > 8192 then
    raise exception 'Resposta inválida.' using errcode = '22023';
  end if;
  perform public.assert_phase_open(v_att.phase_id);
  perform public.attempt_expire(p_attempt);

  -- Já respondida (reenvio, ou o tempo acabou): devolve o gravado.
  if not exists (select 1 from public.attempt_answers
                  where attempt_id = p_attempt and question_id = p_question
                    and answered_at is not null) then

    select * into v_next from public.attempt_next_question(p_attempt);
    if v_next.question_id is distinct from p_question then
      raise exception 'Responda as questões na ordem.' using errcode = '22023';
    end if;
    select * into v_q from public.questions where id = p_question;

    if v_att.timer_enabled then
      select * into v_row from public.attempt_answers
       where attempt_id = p_attempt and question_id = p_question;
      if v_row.presented_at is null then
        raise exception 'Abra a questão antes de responder.' using errcode = '22023';
      end if;
      v_elapsed := extract(epoch from now() - v_row.presented_at);
      -- Passou do tempo (com 3 s de folga para a rede): vale 0. Sem
      -- resposta perto do fim do tempo também conta como tempo esgotado.
      v_timed := v_elapsed > v_row.limit_s + 3
                 or (p_response is null and v_elapsed >= v_row.limit_s - 3);
    end if;

    v_score := case when v_timed or p_response is null then 0
                    else public.grade_response(v_q, p_response) end;

    select case when v_score >= 1 then coalesce((
             select x.streak from public.attempt_answers x
              where x.attempt_id = p_attempt and x.answered_at is not null
                and x.seq < v_next.seq
              order by x.seq desc limit 1), 0) + 1
           else 0 end
      into v_streak;
    v_mult := public.streak_multiplier(v_streak);
    if v_att.timer_enabled and v_score > 0 then
      v_bonus := 5 * v_score * greatest(0, 1 - v_elapsed / v_row.limit_s);
    end if;
    v_points := round(10 * v_score * v_mult + v_bonus)::int;

    insert into public.attempt_answers
      (attempt_id, question_id, seq, answered_at, response, score, timed_out, streak, points)
    values
      (p_attempt, p_question, v_next.seq, now(), p_response, v_score, v_timed, v_streak, v_points)
    on conflict (attempt_id, question_id) do update
      set answered_at = excluded.answered_at,
          response    = excluded.response,
          score       = excluded.score,
          timed_out   = excluded.timed_out,
          streak      = excluded.streak,
          points      = excluded.points;
  end if;

  if (public.attempt_next_question(p_attempt)).question_id is null then
    v_result := public.finalize_attempt(p_attempt);
  end if;

  return public.answer_feedback(p_attempt, p_question)
         || jsonb_build_object(
              'total_points', (select coalesce(sum(points), 0) from public.attempt_answers
                                where attempt_id = p_attempt and answered_at is not null),
              'finished',     v_result is not null,
              'result',       v_result);
end;
$$;

-- ── 7. Painel do professor ───────────────────────────────────────────
-- Notas por fase, agora com a melhor nota e as estrelas. Antes de ler,
-- entrega as tentativas de fases que já fecharam (deixa de ser stable).
create or replace function public.get_classroom_phase_results(p_classroom uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.owns_classroom(p_classroom) then   -- só o professor dono
    return '[]'::jsonb;
  end if;
  perform public.close_overdue_attempts(p_classroom, null);

  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'student_id',      r.student_id,
      'student_name',    coalesce(p.display_name, ''),
      'registration',    coalesce(p.student_id, ''),
      'phase_id',        r.phase_id,
      'total_questions', r.total_questions,
      'correct_answers', r.correct_answers,
      'completed_at',    r.completed_at,
      'best_pct',        b.best,
      'stars',           public.phase_stars(b.best)
    )), '[]'::jsonb)
    from public.classroom_results r
    left join public.profiles p on p.id = r.student_id
    cross join lateral (
      select coalesce(r.best_pct,
                      case when r.total_questions > 0
                           then round(r.correct_answers * 100.0 / r.total_questions, 2)
                           else 100 end) as best
    ) b
    where r.classroom_id = p_classroom
      and r.phase_id is not null
  );
end;
$$;

-- Alunos da turma (para "não entregou") e as fases que cada um começou
-- e ainda não entregou (só fases que não fecharam).
create or replace function public.get_classroom_roster(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'student_id',   m.student_id,
      'student_name', coalesce(p.display_name, ''),
      'registration', coalesce(p.student_id, ''),
      'joined_at',    m.joined_at,
      'in_progress',  coalesce((
        select jsonb_agg(a.phase_id order by a.phase_id)
          from public.phase_attempts a
          join public.classroom_phases ph on ph.id = a.phase_id
         where a.classroom_id = m.classroom_id
           and a.student_id = m.student_id
           and a.finished_at is null
           and (ph.closes_at is null or ph.closes_at >= now())
      ), '[]'::jsonb)
    ) order by lower(coalesce(p.display_name, ''))), '[]'::jsonb)
  from public.classroom_members m
  left join public.profiles p on p.id = m.student_id
  where m.classroom_id = p_classroom
    and public.owns_classroom(p_classroom);   -- só o professor dono
$$;

-- ── 8. submit_quiz (app antigo) ──────────────────────────────────────
-- Igual à versão anterior, com dois cuidados na 1ª entrega:
--   - quem já começou pelo fluxo novo viu o gabarito das questões que
--     respondeu: não pode entregar uma tentativa oficial "limpa" por aqui;
--   - fase com relógio só pelo fluxo novo (o app antigo não tem relógio).
-- Sai quando o app novo estiver no ar há um tempo.
create or replace function public.submit_quiz(
  p_classroom uuid,
  p_phase     uuid,
  p_answers   jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_total   int;
  v_correct numeric;
  v_pct     numeric;
  v_best    numeric;
  v_title   text;
  v_timer   boolean;
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

  select title, timer_enabled into v_title, v_timer
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
    if exists (select 1 from public.phase_attempts
                where phase_id = p_phase and student_id = auth.uid()) then
      raise exception 'Você já começou esta fase. Atualize a página para continuar de onde parou.'
        using errcode = '22023';
    end if;
    if v_timer then
      raise exception 'Esta fase usa o relógio. Atualize a página para responder.'
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

-- ── 9. Privilégios (regra da migration 20261008120000) ──────────────
-- Tabelas novas: só o servidor (as RPCs são security definer).
alter table public.phase_attempts  enable row level security;
alter table public.attempt_answers enable row level security;
revoke all on public.phase_attempts, public.attempt_answers from public, anon, authenticated;
grant all on public.phase_attempts, public.attempt_answers to service_role;

-- Peças internas: recebem ids quaisquer, então só o servidor chama.
revoke all on function
  public.phase_stars(numeric),
  public.streak_multiplier(int),
  public.question_time_limit(public.questions, text),
  public.grade_response(public.questions, jsonb),
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.attempt_next_question(uuid),
  public.attempt_expire(uuid),
  public.answer_feedback(uuid, uuid),
  public.attempt_result(uuid),
  public.finalize_attempt(uuid),
  public.close_overdue_attempts(uuid, uuid),
  public.attempt_state(uuid),
  public.assert_phase_open(uuid),
  public.student_phase_states(uuid, uuid)
from public, anon, authenticated;
grant execute on function
  public.phase_stars(numeric),
  public.streak_multiplier(int),
  public.question_time_limit(public.questions, text),
  public.grade_response(public.questions, jsonb),
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.attempt_next_question(uuid),
  public.attempt_expire(uuid),
  public.answer_feedback(uuid, uuid),
  public.attempt_result(uuid),
  public.finalize_attempt(uuid),
  public.close_overdue_attempts(uuid, uuid),
  public.attempt_state(uuid),
  public.assert_phase_open(uuid),
  public.student_phase_states(uuid, uuid)
to service_role;

-- RPCs do app (cada uma confere auth.uid(), membro ou dono).
revoke all on function
  public.start_attempt(uuid, uuid),
  public.open_question(uuid, uuid),
  public.answer_question(uuid, uuid, jsonb),
  public.get_classroom_roster(uuid),
  public.get_student_phases(uuid),
  public.get_classroom_phase_results(uuid),
  public.submit_quiz(uuid, uuid, jsonb)
from public, anon;
grant execute on function
  public.start_attempt(uuid, uuid),
  public.open_question(uuid, uuid),
  public.answer_question(uuid, uuid, jsonb),
  public.get_classroom_roster(uuid),
  public.get_student_phases(uuid),
  public.get_classroom_phase_results(uuid),
  public.submit_quiz(uuid, uuid, jsonb)
to authenticated, service_role;
