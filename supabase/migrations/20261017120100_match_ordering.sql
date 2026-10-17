-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Ligar colunas e ordenar — Estágio 4, Etapa 2                        ║
-- ║                                                                    ║
-- ║  questions ganha:                                                  ║
-- ║   - content: o que o aluno vê (sem a resposta);                    ║
-- ║   - answer: o gabarito (nunca sai para o aluno antes de travar).   ║
-- ║  Múltipla escolha continua em options/correct_answer (content e    ║
-- ║  answer NULL). Nos tipos novos, options = '{}' e correct_answer = 0.║
-- ║                                                                    ║
-- ║  Ligar colunas (match_columns), 3 a 6 pares:                       ║
-- ║    content {"left": [...], "right": [...]}  (direita embaralhada)  ║
-- ║    answer  {"match": [2, 0, 1]}  esquerda i ↔ direita match[i]     ║
-- ║    resposta {"match": [...]}; nota = pares certos / total.         ║
-- ║                                                                    ║
-- ║  Ordenar (ordering), 3 a 8 itens:                                  ║
-- ║    content {"items": [...]}  (embaralhados)                        ║
-- ║    answer  {"order": [1, 3, 0, 2]}  items[order[k]] é o k-ésimo     ║
-- ║    resposta {"order": [...]}; nota = (maior sequência de itens na  ║
-- ║    ordem certa - 1) / (n - 1): invertido = 0, um item fora do      ║
-- ║    lugar ou dois trocados não zeram a questão.                     ║
-- ║                                                                    ║
-- ║  O formato é conferido no banco (questions_shape_check): a         ║
-- ║  correção depende dele. Itens repetidos na mesma lista não valem   ║
-- ║  (a correção ficaria ambígua).                                     ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Colunas ───────────────────────────────────────────────────────
alter table public.questions
  add column content jsonb,
  add column answer  jsonb;

comment on column public.questions.content is
  'Tipos novos: o que o aluno vê (sem a resposta). NULL na múltipla escolha.';
comment on column public.questions.answer is
  'Tipos novos: o gabarito. Nunca vai ao aluno antes de a resposta travar. NULL na múltipla escolha.';

-- ── 2. Formato conferido no banco ────────────────────────────────────
-- Lista de 3..max textos não vazios (até 200 caracteres), sem repetir.
create or replace function public.jsonb_text_list_ok(p jsonb, p_min int, p_max int)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when p is null or jsonb_typeof(p) <> 'array' then false
    when jsonb_array_length(p) not between p_min and p_max then false
    when exists (select 1 from jsonb_array_elements(p) e
                  where jsonb_typeof(e) <> 'string'
                     or length(btrim(e #>> '{}')) = 0
                     or length(e #>> '{}') > 200) then false
    else (select count(distinct lower(btrim(e))) from jsonb_array_elements_text(p) e)
         = jsonb_array_length(p)
  end;
$$;

-- Os números 0..n-1, cada um uma vez.
create or replace function public.jsonb_permutation_ok(p jsonb, n int)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when p is null or jsonb_typeof(p) <> 'array' then false
    when jsonb_array_length(p) <> n then false
    when exists (select 1 from jsonb_array_elements(p) e
                  where jsonb_typeof(e) <> 'number'
                     or (e #>> '{}') !~ '^\d{1,2}$') then false
    else (select array_agg((e #>> '{}')::int order by (e #>> '{}')::int)
            from jsonb_array_elements(p) e)
         = (select array_agg(g order by g) from generate_series(0, n - 1) g)
  end;
$$;

create or replace function public.question_shape_ok(
  p_type    text,
  p_options text[],
  p_correct int,
  p_content jsonb,
  p_answer  jsonb
)
returns boolean language sql immutable set search_path = '' as $$
  -- CASE encadeado: no SQL o AND não garante a ordem, e um content fora do
  -- formato quebraria o jsonb_array_length antes de ser recusado.
  select case p_type
    when 'match_columns' then
      case
        when p_content is null or p_answer is null then false
        when not public.jsonb_text_list_ok(p_content -> 'left', 3, 6) then false
        when not public.jsonb_text_list_ok(p_content -> 'right', 3, 6) then false
        when jsonb_array_length(p_content -> 'left')
             <> jsonb_array_length(p_content -> 'right') then false
        else public.jsonb_permutation_ok(p_answer -> 'match',
                                         jsonb_array_length(p_content -> 'left'))
      end
    when 'ordering' then
      case
        when p_content is null or p_answer is null then false
        when not public.jsonb_text_list_ok(p_content -> 'items', 3, 8) then false
        else public.jsonb_permutation_ok(p_answer -> 'order',
                                         jsonb_array_length(p_content -> 'items'))
      end
    else
      -- Múltipla escolha (e verdadeiro/falso): a regra de antes.
      p_content is null and p_answer is null
      and p_correct >= 0
      and (array_length(p_options, 1) is null
           or p_correct < array_length(p_options, 1))
  end;
$$;

alter table public.questions
  drop constraint questions_answer_in_range,
  add constraint questions_shape_check
    check (public.question_shape_ok(type::text, options, correct_answer, content, answer));

-- ── 3. O que o aluno vê ──────────────────────────────────────────────
create or replace function public.question_public(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'id',           q.id,
    'phase_id',     q.phase_id,
    'text',         q.text,
    'options',      q.options,
    'type',         q.type,
    'content',      q.content,
    'image_url',    q.image_url,
    'image_author', q.image_author,
    'image_source', q.image_source,
    'sort_order',   q.sort_order
  );
$$;

-- ── 4. Gabarito revelado depois que a resposta trava ─────────────────
create or replace function public.question_reveal(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select case q.type::text
    when 'match_columns' then jsonb_build_object('match', q.answer -> 'match')
    when 'ordering'      then jsonb_build_object('order', q.answer -> 'order')
    else jsonb_build_object('correct_answer', q.correct_answer)
  end;
$$;

-- ── 5. Correção (0 a 1) ──────────────────────────────────────────────
create or replace function public.grade_response(q public.questions, p_response jsonb)
returns numeric language plpgsql immutable set search_path = '' as $$
declare
  n     int;
  v_ok  int;
  v_pos int[];   -- posição certa de cada item, na ordem que o aluno deixou
  v_len int[];   -- maior sequência crescente que termina em cada item
begin
  if p_response is null or jsonb_typeof(p_response) <> 'object' then
    return 0;
  end if;
  case q.type::text
    when 'multiple_choice', 'true_false' then
      return case when (p_response ->> 'choice') ~ '^\d{1,3}$'
                   and (p_response ->> 'choice')::int = q.correct_answer
                  then 1 else 0 end;

    when 'match_columns' then
      -- Pares certos / total (fio solto conta como errado).
      if jsonb_typeof(p_response -> 'match') is distinct from 'array' then
        return 0;
      end if;
      n := jsonb_array_length(q.answer -> 'match');
      select count(*) into v_ok
        from generate_series(0, n - 1) i
       where (p_response -> 'match' ->> i) = (q.answer -> 'match' ->> i);
      return round(v_ok::numeric / n, 3);

    when 'ordering' then
      -- Maior sequência de itens na ordem certa entre si (não precisam
      -- estar colados): (maior - 1) / (n - 1). Tudo certo = 1, invertido
      -- = 0; dois itens trocados ou um item fora do lugar não zeram.
      n := jsonb_array_length(q.answer -> 'order');
      if not public.jsonb_permutation_ok(p_response -> 'order', n) then
        return 0;
      end if;
      select array_agg(a.pos order by r.idx) into v_pos
        from (select (e #>> '{}')::int as item, o as idx
                from jsonb_array_elements(p_response -> 'order') with ordinality t(e, o)) r
        join (select (e #>> '{}')::int as item, o as pos
                from jsonb_array_elements(q.answer -> 'order') with ordinality t(e, o)) a
          on a.item = r.item;
      v_len := array_fill(1, array[n]);
      for i in 2 .. n loop
        for j in 1 .. i - 1 loop
          if v_pos[j] < v_pos[i] and v_len[j] + 1 > v_len[i] then
            v_len[i] := v_len[j] + 1;
          end if;
        end loop;
      end loop;
      select max(x) into v_ok from unnest(v_len) x;
      return round((v_ok - 1)::numeric / (n - 1), 3);

    else
      raise exception 'Tipo de questão ainda não suportado: %', q.type
        using errcode = '0A000';
  end case;
end;
$$;

-- ── 6. Tempo automático conta os itens e a interação ─────────────────
-- ~20 s + 1 s a cada 12 caracteres (enunciado, alternativas e itens) +
-- 3 s por par/item para ligar ou arrastar; nível ajusta; múltiplos de 5,
-- entre 15 s e 5 min. Tempo escolhido pelo professor vem antes.
create or replace function public.question_time_limit(q public.questions, p_level text)
returns int language sql immutable set search_path = '' as $$
  select coalesce(q.time_limit_s, least(300, greatest(15, (round(
    (20
     + (length(q.text)
        + coalesce((select sum(length(o)) from unnest(q.options) o), 0)
        + coalesce((select sum(length(j #>> '{}'))
                      from jsonb_path_query(coalesce(q.content, '{}'::jsonb), 'lax $.*[*]') j
                     where jsonb_typeof(j) = 'string'), 0)) / 12.0
     + 3 * case q.type::text
             when 'match_columns' then jsonb_array_length(q.content -> 'left')
             when 'ordering'      then jsonb_array_length(q.content -> 'items')
             else 0
           end)
    * case p_level when 'short' then 0.6 when 'long' then 1.5 else 1.0 end
    / 5) * 5)::int)));
$$;

-- ── 7. Copiar do banco de questões leva conteúdo e gabarito ──────────
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
    (phase_id, text, options, correct_answer, explanation, type, content, answer,
     image_url, image_author, image_source, ai_generated, time_limit_s, sort_order)
  select p_phase, q.text, q.options, q.correct_answer, q.explanation, q.type,
         q.content, q.answer,
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

-- ── 8. submit_quiz (app antigo) não corrige os tipos novos ───────────
-- O app antigo só sabe múltipla escolha: com tipo novo na fase, nem
-- entrega nem refaz por ele (corrigiria errado).
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

  if exists (select 1 from public.questions
              where phase_id = p_phase
                and type::text not in ('multiple_choice', 'true_false')) then
    raise exception 'Esta fase tem tipos novos de questão. Atualize a página para responder.'
      using errcode = '22023';
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
-- As funções de formato rodam dentro da CHECK de questions, que vale para
-- o INSERT/UPDATE do professor (authenticated): ele precisa executá-las.
revoke all on function
  public.jsonb_text_list_ok(jsonb, int, int),
  public.jsonb_permutation_ok(jsonb, int),
  public.question_shape_ok(text, text[], int, jsonb, jsonb)
from public, anon;
grant execute on function
  public.jsonb_text_list_ok(jsonb, int, int),
  public.jsonb_permutation_ok(jsonb, int),
  public.question_shape_ok(text, text[], int, jsonb, jsonb)
to authenticated, service_role;

-- create or replace mantém os privilégios; reafirmados aqui.
revoke all on function
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text)
from public, anon, authenticated;
grant execute on function
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text)
to service_role;
revoke all on function public.copy_questions_to_phase(uuid, uuid[]) from public, anon;
grant execute on function public.copy_questions_to_phase(uuid, uuid[]) to authenticated, service_role;
revoke all on function public.submit_quiz(uuid, uuid, jsonb) from public, anon;
grant execute on function public.submit_quiz(uuid, uuid, jsonb) to authenticated, service_role;
