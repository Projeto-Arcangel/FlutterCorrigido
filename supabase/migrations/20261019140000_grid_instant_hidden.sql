-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Cruzadinha e caça-palavras: acertos na hora e palavras ocultas     ║
-- ║                                                                    ║
-- ║  Pedidos do professor-dono do produto (2026-10-19):                ║
-- ║  - content.instant (bool): mostrar cada palavra certa na hora ou   ║
-- ║    só no fim. Sem a chave vale o que já era: cruzadinha no fim,    ║
-- ║    caça-palavras na hora. A conferência na hora passa pelo         ║
-- ║    servidor (check_answer_part): o gabarito nunca vai ao aluno.    ║
-- ║    Cada questão aceita até max(20, 5 × palavras) conferências.     ║
-- ║  - content.hidden (caça-palavras): índices das palavras que o      ║
-- ║    aluno não vê na lista, só a quantidade de letras (_ _ _). O     ║
-- ║    texto é tirado em question_public e volta no gabarito revelado. ║
-- ║  - Correção do caça-palavras: só as n primeiras marcações contam   ║
-- ║    (n = palavras), já que sem conferência na hora o aluno pode     ║
-- ║    marcar qualquer linha.                                          ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Conferências usadas, por questão da tentativa ────────────────
alter table public.phase_attempts
  add column part_checks jsonb not null default '{}'::jsonb;

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
     -- Com palavras de 1 letra a grade pode ter só 1 ou 2 linhas.
     or v_rows not between 1 and 15 or v_cols not between 1 and 15 then
    return false;
  end if;
  if jsonb_typeof(p_content -> 'entries') <> 'array'
     or jsonb_typeof(p_answer -> 'words') <> 'array' then
    return false;
  end if;
  -- Mostrar os acertos na hora (opcional; sem a chave, só no fim).
  if p_content ? 'instant' and jsonb_typeof(p_content -> 'instant') <> 'boolean' then
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
    if w is null or w !~ '^[A-Z]{1,15}$' or length(w) <> len
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
                 where jsonb_typeof(x) <> 'string' or (x #>> '{}') !~ '^[A-Z]{1,15}$')
     or (select count(distinct x) from jsonb_array_elements_text(p_content -> 'words') x) <> n then
    return false;
  end if;
  -- Mostrar os acertos na hora (opcional; sem a chave, na hora).
  if p_content ? 'instant' and jsonb_typeof(p_content -> 'instant') <> 'boolean' then
    return false;
  end if;
  -- Palavras ocultas (opcional): índices distintos de 0 a n - 1.
  if p_content ? 'hidden' then
    if jsonb_typeof(p_content -> 'hidden') <> 'array'
       or exists (select 1 from jsonb_array_elements(p_content -> 'hidden') h
                   where jsonb_typeof(h) <> 'number'
                      or (h #>> '{}') !~ '^[0-9]+$'
                      or (h #>> '{}')::int >= n)
       or (select count(distinct h) from jsonb_array_elements(p_content -> 'hidden') h)
          <> jsonb_array_length(p_content -> 'hidden') then
      return false;
    end if;
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

-- ── 3. O que o aluno vê: palavras ocultas viram só o tamanho ─────────
create or replace function public.question_public(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'id',           q.id,
    'phase_id',     q.phase_id,
    'text',         q.text,
    'options',      q.options,
    'type',         q.type,
    'content',      case
                      when q.type::text = 'word_search'
                       and jsonb_typeof(q.content -> 'hidden') = 'array'
                       and jsonb_array_length(q.content -> 'hidden') > 0 then
                        q.content || jsonb_build_object(
                          'words', (select jsonb_agg(
                                             case when q.content -> 'hidden' @> to_jsonb((t.o - 1)::int)
                                                  then to_jsonb(''::text) else t.w end
                                             order by t.o)
                                      from jsonb_array_elements(q.content -> 'words')
                                           with ordinality t(w, o)),
                          'lens',  (select jsonb_agg(length(t.w #>> '{}') order by t.o)
                                      from jsonb_array_elements(q.content -> 'words')
                                           with ordinality t(w, o)))
                      else q.content
                    end,
    'image_url',    q.image_url,
    'image_author', q.image_author,
    'image_source', q.image_source,
    'sort_order',   q.sort_order
  );
$$;

-- ── 4. Gabarito revelado: o caça-palavras traz as palavras (ocultas) ─
create or replace function public.question_reveal(q public.questions)
returns jsonb language sql immutable set search_path = '' as $$
  select case q.type::text
    when 'match_columns' then jsonb_build_object('match', q.answer -> 'match')
    when 'ordering'      then jsonb_build_object('order', q.answer -> 'order')
    when 'fill_blanks'   then jsonb_build_object('blanks', q.answer -> 'blanks')
    when 'crossword'     then jsonb_build_object('words', q.answer -> 'words')
    when 'word_search'   then jsonb_build_object('positions', q.answer -> 'positions',
                                                 'words',     q.content -> 'words')
    else jsonb_build_object('correct_answer', q.correct_answer)
  end;
$$;

-- ── 5. Correção ──────────────────────────────────────────────────────
create or replace function public.grade_response(q public.questions, p_response jsonb)
returns numeric language plpgsql immutable set search_path = '' as $$
declare
  n    int;
  v_ok int;
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
      -- Itens na posição certa / total: cada item vale sozinho, sem
      -- depender dos vizinhos (decisão do professor-dono do produto).
      n := jsonb_array_length(q.answer -> 'order');
      if not public.jsonb_permutation_ok(p_response -> 'order', n) then
        return 0;
      end if;
      select count(*) into v_ok
        from generate_series(0, n - 1) i
       where (p_response -> 'order' ->> i) = (q.answer -> 'order' ->> i);
      return round(v_ok::numeric / n, 3);

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
      -- para frente também vale). Só as n primeiras marcações contam (uma
      -- por palavra): marcar linhas a esmo não rende ponto.
      if jsonb_typeof(p_response -> 'found') is distinct from 'array'
         or jsonb_array_length(p_response -> 'found') > 40 then
        return 0;
      end if;
      n := jsonb_array_length(q.content -> 'words');
      select count(*) into v_ok
        from jsonb_array_elements_text(q.content -> 'words') w
       where exists (
         select 1 from jsonb_array_elements(p_response -> 'found') with ordinality s(x, o)
          where s.o <= n
            and public.grid_line(q.content -> 'grid', s.x) in (w, reverse(w)));
      return round(v_ok::numeric / n, 3);

    else
      raise exception 'Tipo de questão ainda não suportado: %', q.type
        using errcode = '0A000';
  end case;
end;
$$;

-- ── 6. Conferir uma palavra na hora ──────────────────────────────────
-- Só a questão aberta da tentativa, com a opção ligada e dentro do tempo.
-- Cruzadinha: p_part {"index": i, "word": "BRASILIA"} → {"index", "correct"}.
-- Caça-palavras: p_part {"sel": [r1, c1, r2, c2]} → {"index", "word"}
-- (index/word nulos se a linha não forma palavra da lista).
create or replace function public.check_answer_part(
  p_attempt  uuid,
  p_question uuid,
  p_part     jsonb
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_att  public.phase_attempts%rowtype;
  v_q    public.questions%rowtype;
  v_row  public.attempt_answers%rowtype;
  v_n    int;
  v_used int;
  v_idx  int;
  v_word text;
  v_line text;
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
  perform public.attempt_expire(p_attempt);
  if (public.attempt_next_question(p_attempt)).question_id is distinct from p_question then
    raise exception 'Esta questão não está aberta.' using errcode = '22023';
  end if;

  select * into v_q from public.questions where id = p_question;
  if v_q.type::text = 'crossword'
     and coalesce((v_q.content ->> 'instant')::boolean, false) then
    v_n := jsonb_array_length(v_q.answer -> 'words');
  elsif v_q.type::text = 'word_search'
     and coalesce((v_q.content ->> 'instant')::boolean, true) then
    v_n := jsonb_array_length(v_q.content -> 'words');
  else
    raise exception 'Nesta questão os acertos aparecem só no fim.' using errcode = '22023';
  end if;

  if v_att.timer_enabled then
    select * into v_row from public.attempt_answers
     where attempt_id = p_attempt and question_id = p_question;
    if v_row.presented_at is null then
      raise exception 'Abra a questão antes de conferir.' using errcode = '22023';
    end if;
    if now() > v_row.presented_at + make_interval(secs => v_row.limit_s + 3) then
      raise exception 'O tempo desta questão acabou.' using errcode = '22023';
    end if;
  end if;

  -- Limite de conferências: adivinhar à força não compensa.
  v_used := coalesce((v_att.part_checks ->> p_question::text)::int, 0);
  if v_used >= greatest(20, 5 * v_n) then
    raise exception 'Você já conferiu muitas vezes nesta questão. Termine e confirme.'
      using errcode = '22023';
  end if;
  update public.phase_attempts
     set part_checks = jsonb_set(part_checks, array[p_question::text], to_jsonb(v_used + 1))
   where id = p_attempt;

  if v_q.type::text = 'crossword' then
    if jsonb_typeof(p_part -> 'index') is distinct from 'number'
       or jsonb_typeof(p_part -> 'word') is distinct from 'string' then
      raise exception 'Conferência inválida.' using errcode = '22023';
    end if;
    v_idx := (p_part ->> 'index')::int;
    v_word := upper(p_part ->> 'word');
    if v_idx < 0 or v_idx >= v_n or length(v_word) > 20 then
      raise exception 'Conferência inválida.' using errcode = '22023';
    end if;
    return jsonb_build_object('index', v_idx,
                              'correct', v_word = (v_q.answer -> 'words' ->> v_idx));
  end if;

  v_line := public.grid_line(v_q.content -> 'grid', p_part -> 'sel');
  if v_line is null then
    return jsonb_build_object('index', null, 'word', null);
  end if;
  select (t.o - 1)::int, t.w into v_idx, v_word
    from jsonb_array_elements_text(v_q.content -> 'words') with ordinality t(w, o)
   where t.w in (v_line, reverse(v_line))
   order by t.o
   limit 1;
  return jsonb_build_object('index', v_idx, 'word', v_word);
end;
$$;

-- ── 7. Privilégios (regra da migration 20261008120000) ──────────────
-- Conferências das grades rodam na CHECK de questions (professor).
revoke all on function
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
from public, anon;
grant execute on function
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
to authenticated, service_role;

-- Peças internas: só o servidor.
revoke all on function
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb)
from public, anon, authenticated;
grant execute on function
  public.question_public(public.questions),
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb)
to service_role;

-- RPC do app (confere dono da tentativa, membro da turma e tempo).
revoke all on function public.check_answer_part(uuid, uuid, jsonb) from public, anon;
grant execute on function public.check_answer_part(uuid, uuid, jsonb) to authenticated, service_role;
