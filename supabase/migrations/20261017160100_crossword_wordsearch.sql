-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Cruzadinha e caça-palavras — Estágio 4, Etapa 4                     ║
-- ║                                                                    ║
-- ║  A grade é montada no app do professor (o mesmo código serve a     ║
-- ║  criação manual e a IA) e conferida aqui antes de gravar.          ║
-- ║  Palavras só com A–Z (sem acento nem espaço, como em cruzadinha).  ║
-- ║                                                                    ║
-- ║  Cruzadinha (crossword), 3 a 12 palavras, grade até 15×15:         ║
-- ║    content {"rows": R, "cols": C, "entries": [{"num": 1, "row": 0, ║
-- ║             "col": 2, "dir": "across"|"down", "len": 8,            ║
-- ║             "clue": "Capital do Brasil"}, ...]}  (sem as letras)   ║
-- ║    answer  {"words": ["BRASILIA", ...]}  na ordem de entries       ║
-- ║    resposta {"words": [...]}; nota = palavras certas / total.      ║
-- ║                                                                    ║
-- ║  Caça-palavras (word_search), 3 a 12 palavras, grade 6×6 a 15×15:  ║
-- ║    content {"rows": R, "cols": C, "grid": ["ABCD...", ...],        ║
-- ║             "words": ["BRASILIA", ...]}  (lista visível ao aluno)  ║
-- ║    answer  {"positions": [[r1, c1, r2, c2], ...]}  onde está cada  ║
-- ║    resposta {"found": [[r1, c1, r2, c2], ...]}; cada marcação é    ║
-- ║    relida na grade (de trás para frente também vale); nota =       ║
-- ║    palavras achadas / total.                                       ║
-- ║                                                                    ║
-- ║  Limite do plano (decisão 6): cada cruzadinha gerada pela IA conta ║
-- ║  3 questões. ai_generation_logs ganha charged (quanto contou) e    ║
-- ║  question_type; plan_used soma charged (ou quantity, nos antigos). ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Leitura de uma linha da grade ─────────────────────────────────
-- Letras de (r1, c1) até (r2, c2) em linha reta (horizontal, vertical
-- ou diagonal). NULL se não for reta, sair da grade ou vier fora do
-- formato (resposta adulterada não quebra a correção).
create or replace function public.grid_line(p_grid jsonb, p_sel jsonb)
returns text language plpgsql immutable set search_path = '' as $$
declare
  r1 int; c1 int; r2 int; c2 int;
  dr int; dc int; n int;
  v_rows int; v_cols int;
  v_out text := '';
begin
  if p_grid is null or jsonb_typeof(p_grid) <> 'array'
     or p_sel is null or jsonb_typeof(p_sel) <> 'array'
     or jsonb_array_length(p_sel) <> 4 then
    return null;
  end if;
  r1 := (p_sel ->> 0)::int; c1 := (p_sel ->> 1)::int;
  r2 := (p_sel ->> 2)::int; c2 := (p_sel ->> 3)::int;
  v_rows := jsonb_array_length(p_grid);
  v_cols := length(p_grid ->> 0);
  if least(r1, c1, r2, c2) < 0 or greatest(r1, r2) >= v_rows
     or greatest(c1, c2) >= v_cols then
    return null;
  end if;
  if not (r1 = r2 or c1 = c2 or abs(r2 - r1) = abs(c2 - c1)) then
    return null;
  end if;
  dr := sign(r2 - r1);
  dc := sign(c2 - c1);
  n := greatest(abs(r2 - r1), abs(c2 - c1));
  for k in 0 .. n loop
    v_out := v_out || substr(p_grid ->> (r1 + k * dr), c1 + k * dc + 1, 1);
  end loop;
  return v_out;
exception when others then
  return null;
end;
$$;

-- ── 2. Conferência das grades ────────────────────────────────────────
create or replace function public.crossword_ok(p_content jsonb, p_answer jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  v_rows int;
  v_cols int;
  n      int;
  e      jsonb;
  w      text;
  r      int;
  c      int;
  len    int;
  i      int := 0;
begin
  if p_content is null or p_answer is null then
    return false;
  end if;
  v_rows := (p_content ->> 'rows')::int;
  v_cols := (p_content ->> 'cols')::int;
  if v_rows is null or v_cols is null
     or v_rows not between 3 and 15 or v_cols not between 3 and 15 then
    return false;
  end if;
  if jsonb_typeof(p_content -> 'entries') <> 'array'
     or jsonb_typeof(p_answer -> 'words') <> 'array' then
    return false;
  end if;
  n := jsonb_array_length(p_content -> 'entries');
  if n not between 3 and 12 or jsonb_array_length(p_answer -> 'words') <> n then
    return false;
  end if;
  for e in select x from jsonb_array_elements(p_content -> 'entries') x loop
    w := p_answer -> 'words' ->> i;
    r := (e ->> 'row')::int;
    c := (e ->> 'col')::int;
    len := (e ->> 'len')::int;
    if w is null or w !~ '^[A-Z]{3,15}$' or length(w) <> len
       or r < 0 or c < 0 or (e ->> 'num')::int < 1
       or coalesce(length(btrim(e ->> 'clue')), 0) = 0
       or length(e ->> 'clue') > 200 then
      return false;
    end if;
    if e ->> 'dir' = 'across' then
      if r >= v_rows or c + len > v_cols then return false; end if;
    elsif e ->> 'dir' = 'down' then
      if c >= v_cols or r + len > v_rows then return false; end if;
    else
      return false;
    end if;
    i := i + 1;
  end loop;
  -- Onde duas palavras se cruzam, a letra é a mesma.
  return not exists (
    select 1
      from jsonb_array_elements(p_content -> 'entries') with ordinality t(x, o)
      cross join lateral generate_series(0, (x ->> 'len')::int - 1) k
     group by (x ->> 'row')::int + case when x ->> 'dir' = 'down' then k else 0 end,
              (x ->> 'col')::int + case when x ->> 'dir' = 'across' then k else 0 end
    having count(distinct substr(p_answer -> 'words' ->> (o - 1)::int, k + 1, 1)) > 1);
exception when others then
  return false;
end;
$$;

create or replace function public.word_search_ok(p_content jsonb, p_answer jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  v_rows int;
  v_cols int;
  n      int;
  p      jsonb;
  i      int := 0;
begin
  if p_content is null or p_answer is null then
    return false;
  end if;
  v_rows := (p_content ->> 'rows')::int;
  v_cols := (p_content ->> 'cols')::int;
  if v_rows is null or v_cols is null
     or v_rows not between 6 and 15 or v_cols not between 6 and 15 then
    return false;
  end if;
  if jsonb_typeof(p_content -> 'grid') <> 'array'
     or jsonb_array_length(p_content -> 'grid') <> v_rows
     or exists (select 1 from jsonb_array_elements(p_content -> 'grid') g
                 where jsonb_typeof(g) <> 'string'
                    or (g #>> '{}') !~ ('^[A-Z]{' || v_cols || '}$')) then
    return false;
  end if;
  if jsonb_typeof(p_content -> 'words') <> 'array' then
    return false;
  end if;
  n := jsonb_array_length(p_content -> 'words');
  if n not between 3 and 12
     or exists (select 1 from jsonb_array_elements(p_content -> 'words') x
                 where jsonb_typeof(x) <> 'string' or (x #>> '{}') !~ '^[A-Z]{3,15}$')
     or (select count(distinct x) from jsonb_array_elements_text(p_content -> 'words') x) <> n then
    return false;
  end if;
  if jsonb_typeof(p_answer -> 'positions') <> 'array'
     or jsonb_array_length(p_answer -> 'positions') <> n then
    return false;
  end if;
  -- Cada palavra está mesmo onde o gabarito diz.
  for p in select x from jsonb_array_elements(p_answer -> 'positions') x loop
    if public.grid_line(p_content -> 'grid', p)
       is distinct from (p_content -> 'words' ->> i) then
      return false;
    end if;
    i := i + 1;
  end loop;
  return true;
exception when others then
  return false;
end;
$$;

-- ── 3. Formato de cada tipo ──────────────────────────────────────────
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
    when 'fill_blanks' then
      case
        when p_content is null or p_answer is null then false
        -- 1 a 8 lacunas: 2 a 9 trechos (podem ser vazios), até 500 cada.
        when not public.jsonb_strings_ok(p_content -> 'parts', 2, 9, 500, true) then false
        when (select coalesce(sum(length(e)), 0)
                from jsonb_array_elements_text(p_content -> 'parts') e) > 1500 then false
        -- Banco: uma palavra por lacuna + até 6 distratores, até 80 cada.
        when not public.jsonb_strings_ok(p_content -> 'bank', 1, 14, 80, false) then false
        when jsonb_array_length(p_content -> 'bank')
             not between jsonb_array_length(p_content -> 'parts') - 1
                     and jsonb_array_length(p_content -> 'parts') + 5 then false
        else public.jsonb_distinct_indexes_ok(
               p_answer -> 'blanks',
               jsonb_array_length(p_content -> 'parts') - 1,
               jsonb_array_length(p_content -> 'bank'))
      end
    when 'crossword'   then public.crossword_ok(p_content, p_answer)
    when 'word_search' then public.word_search_ok(p_content, p_answer)
    else
      -- Múltipla escolha (e verdadeiro/falso): a regra de antes.
      p_content is null and p_answer is null
      and p_correct >= 0
      and (array_length(p_options, 1) is null
           or p_correct < array_length(p_options, 1))
  end;
$$;

-- Reconfere todas as linhas com a regra nova.
alter table public.questions
  drop constraint questions_shape_check,
  add constraint questions_shape_check
    check (public.question_shape_ok(type::text, options, correct_answer, content, answer));

-- ── 4. Gabarito revelado ─────────────────────────────────────────────
create or replace function public.question_reveal(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select case q.type::text
    when 'match_columns' then jsonb_build_object('match', q.answer -> 'match')
    when 'ordering'      then jsonb_build_object('order', q.answer -> 'order')
    when 'fill_blanks'   then jsonb_build_object('blanks', q.answer -> 'blanks')
    when 'crossword'     then jsonb_build_object('words', q.answer -> 'words')
    when 'word_search'   then jsonb_build_object('positions', q.answer -> 'positions')
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

    when 'fill_blanks' then
      -- Lacunas certas / total, pelo texto da palavra escolhida (o banco
      -- pode ter a mesma palavra duas vezes). Lacuna vazia = errada.
      if jsonb_typeof(p_response -> 'blanks') is distinct from 'array' then
        return 0;
      end if;
      n := jsonb_array_length(q.answer -> 'blanks');
      -- CASE: só converte para número o que é número (AND não garante ordem).
      select count(*) into v_ok
        from generate_series(0, n - 1) k
       where case
               when (p_response -> 'blanks' ->> k) ~ '^\d{1,2}$' then
                 lower(btrim(q.content -> 'bank' ->> (p_response -> 'blanks' ->> k)::int))
                 = lower(btrim(q.content -> 'bank' ->> (q.answer -> 'blanks' ->> k)::int))
               else false
             end;
      return round(v_ok::numeric / n, 3);

    when 'crossword' then
      -- Palavras certas / total (casa vazia = palavra errada).
      if jsonb_typeof(p_response -> 'words') is distinct from 'array' then
        return 0;
      end if;
      n := jsonb_array_length(q.answer -> 'words');
      select count(*) into v_ok
        from generate_series(0, n - 1) i
       where upper(btrim(coalesce(p_response -> 'words' ->> i, '')))
             = q.answer -> 'words' ->> i;
      return round(v_ok::numeric / n, 3);

    when 'word_search' then
      -- Palavras achadas / total: cada marcação é relida na grade (de trás
      -- para frente também vale). Até 40 marcações.
      if jsonb_typeof(p_response -> 'found') is distinct from 'array'
         or jsonb_array_length(p_response -> 'found') > 40 then
        return 0;
      end if;
      n := jsonb_array_length(q.content -> 'words');
      select count(*) into v_ok
        from jsonb_array_elements_text(q.content -> 'words') w
       where exists (
         select 1 from jsonb_array_elements(p_response -> 'found') s
          where public.grid_line(q.content -> 'grid', s) in (w, reverse(w)));
      return round(v_ok::numeric / n, 3);

    else
      raise exception 'Tipo de questão ainda não suportado: %', q.type
        using errcode = '0A000';
  end case;
end;
$$;

-- ── 6. Tempo automático ──────────────────────────────────────────────
-- Leitura (enunciado, alternativas, itens e dicas da cruzadinha) + tempo
-- de mexer: 3 s por par/item/lacuna, 10 s por palavra da cruzadinha,
-- 6 s por palavra do caça-palavras.
create or replace function public.question_time_limit(q public.questions, p_level text)
returns int language sql immutable set search_path = '' as $$
  select coalesce(q.time_limit_s, least(300, greatest(15, (round(
    (20
     + (length(q.text)
        + coalesce((select sum(length(o)) from unnest(q.options) o), 0)
        + coalesce((select sum(length(j #>> '{}'))
                      from jsonb_path_query(coalesce(q.content, '{}'::jsonb), 'lax $.*[*]') j
                     where jsonb_typeof(j) = 'string'), 0)
        + case when q.type::text = 'crossword'
               then coalesce((select sum(length(e ->> 'clue'))
                                from jsonb_array_elements(q.content -> 'entries') e), 0)
               else 0 end) / 12.0
     + case q.type::text
         when 'match_columns' then 3 * jsonb_array_length(q.content -> 'left')
         when 'ordering'      then 3 * jsonb_array_length(q.content -> 'items')
         when 'fill_blanks'   then 3 * (jsonb_array_length(q.content -> 'parts') - 1)
         when 'crossword'     then 10 * jsonb_array_length(q.content -> 'entries')
         when 'word_search'   then 6 * jsonb_array_length(q.content -> 'words')
         else 0
       end)
    * case p_level when 'short' then 0.6 when 'long' then 1.5 else 1.0 end
    / 5) * 5)::int)));
$$;

-- ── 7. Limite do plano: cruzadinha conta 3 ───────────────────────────
alter table public.ai_generation_logs
  add column question_type text,
  add column charged int check (charged is null or charged >= 0);

comment on column public.ai_generation_logs.charged is
  'Quanto a geração contou no limite do plano (cruzadinha = 3 por questão). NULL nos registros antigos: vale quantity.';

create or replace function public.plan_used(p_teacher uuid, p_resource text)
returns int
language plpgsql stable security definer set search_path = public as $$
declare
  v_start timestamptz := (select period_start from public.plan_period(p_teacher));
  v_used  int;
begin
  case p_resource
    when 'topic', 'materials' then
      -- Cruzadinha conta 3 por questão (charged); antigos: quantity.
      select coalesce(sum(coalesce(l.charged, l.quantity, 0)), 0) into v_used
        from public.ai_generation_logs l
       where l.teacher_id = p_teacher and l.status = 'success'
         and l.source = p_resource and l.created_at >= v_start;
    when 'video_minutes' then
      -- Minutos lidos de cada vídeo, arredondados para cima (inclui leitura
      -- parcial: os trechos lidos foram cobrados).
      select coalesce(sum(ceil(e.seconds / 60.0)), 0) into v_used
        from public.material_extractions e
       where e.teacher_id = p_teacher and e.kind = 'video'
         and e.status in ('success', 'partial') and e.seconds > 0
         and e.created_at >= v_start;
    when 'stored' then
      select count(*) into v_used
        from public.questions q
        join public.classroom_phases ph on ph.id = q.phase_id
        join public.classrooms c        on c.id = ph.classroom_id
       where c.teacher_id = p_teacher;
    else
      raise exception 'Recurso de plano desconhecido: %', p_resource
        using errcode = '22023';
  end case;
  return v_used;
end;
$$;

-- ── 8. Privilégios (regra da migration 20261008120000) ──────────────
-- Conferências rodam dentro da CHECK de questions (INSERT/UPDATE do
-- professor): authenticated executa. grid_line também serve à correção.
revoke all on function
  public.grid_line(jsonb, jsonb),
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
from public, anon;
grant execute on function
  public.grid_line(jsonb, jsonb),
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
to authenticated, service_role;

-- create or replace mantém os privilégios; reafirmados aqui.
revoke all on function public.question_shape_ok(text, text[], int, jsonb, jsonb) from public, anon;
grant execute on function public.question_shape_ok(text, text[], int, jsonb, jsonb) to authenticated, service_role;
revoke all on function
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text),
  public.plan_used(uuid, text)
from public, anon, authenticated;
grant execute on function
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text),
  public.plan_used(uuid, text)
to service_role;
