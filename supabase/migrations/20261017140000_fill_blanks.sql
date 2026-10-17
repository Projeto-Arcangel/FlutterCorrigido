-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Completar lacunas — Estágio 4, Etapa 3                              ║
-- ║                                                                    ║
-- ║  Usa o tipo fill_blanks (já existia no enum, nunca foi usado).     ║
-- ║  O aluno completa tocando em palavras de um banco (com             ║
-- ║  distratores) — sem digitar, a correção não depende de erro de     ║
-- ║  digitação nem de sinônimo.                                        ║
-- ║                                                                    ║
-- ║    content {"parts": ["O Brasil foi descoberto em ", " por ", "."],║
-- ║             "bank":  ["Cabral", "1822", "1500", "Vasco da Gama"]}  ║
-- ║      → lacuna k fica entre parts[k] e parts[k+1] (1 a 8 lacunas);  ║
-- ║        banco embaralhado, com até 6 palavras a mais (distratores). ║
-- ║    answer  {"blanks": [2, 0]}  lacuna k ↔ bank[blanks[k]]          ║
-- ║    resposta {"blanks": [...]}; nota = lacunas certas / total,      ║
-- ║    comparando o TEXTO da palavra (o banco pode repetir palavra).   ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Nenhuma lacuna antiga fora do formato ─────────────────────────
-- O app nunca criou fill_blanks; se houver alguma linha assim (dado
-- antigo, sem conteúdo), ela vira múltipla escolha antes da regra nova.
update public.questions
   set type = 'multiple_choice'
 where type = 'fill_blanks' and content is null;

-- ── 2. Peças da conferência de formato ───────────────────────────────
-- Lista de textos com tamanho e limite de caracteres; vazios só se
-- p_allow_empty (os trechos entre lacunas podem ser vazios).
create or replace function public.jsonb_strings_ok(
  p jsonb, p_min int, p_max int, p_max_chars int, p_allow_empty boolean
)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when p is null or jsonb_typeof(p) <> 'array' then false
    when jsonb_array_length(p) not between p_min and p_max then false
    else not exists (
      select 1 from jsonb_array_elements(p) e
       where jsonb_typeof(e) <> 'string'
          or length(e #>> '{}') > p_max_chars
          or (not p_allow_empty and length(btrim(e #>> '{}')) = 0))
  end;
$$;

-- n números distintos, cada um de 0 a p_max - 1.
create or replace function public.jsonb_distinct_indexes_ok(p jsonb, n int, p_max int)
returns boolean language sql immutable set search_path = '' as $$
  select case
    when p is null or jsonb_typeof(p) <> 'array' then false
    when jsonb_array_length(p) <> n then false
    when exists (select 1 from jsonb_array_elements(p) e
                  where jsonb_typeof(e) <> 'number'
                     or (e #>> '{}') !~ '^\d{1,2}$'
                     or (e #>> '{}')::int >= p_max) then false
    else (select count(distinct e #>> '{}') from jsonb_array_elements(p) e) = n
  end;
$$;

-- ── 3. Formato de cada tipo (agora com lacunas) ──────────────────────
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

    else
      raise exception 'Tipo de questão ainda não suportado: %', q.type
        using errcode = '0A000';
  end case;
end;
$$;

-- ── 6. Tempo automático: +3 s por lacuna ─────────────────────────────
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
             when 'fill_blanks'   then jsonb_array_length(q.content -> 'parts') - 1
             else 0
           end)
    * case p_level when 'short' then 0.6 when 'long' then 1.5 else 1.0 end
    / 5) * 5)::int)));
$$;

-- ── 7. Privilégios (regra da migration 20261008120000) ──────────────
-- Rodam dentro da CHECK de questions (INSERT/UPDATE do professor).
revoke all on function
  public.jsonb_strings_ok(jsonb, int, int, int, boolean),
  public.jsonb_distinct_indexes_ok(jsonb, int, int)
from public, anon;
grant execute on function
  public.jsonb_strings_ok(jsonb, int, int, int, boolean),
  public.jsonb_distinct_indexes_ok(jsonb, int, int)
to authenticated, service_role;

-- create or replace mantém os privilégios; reafirmados aqui.
revoke all on function public.question_shape_ok(text, text[], int, jsonb, jsonb) from public, anon;
grant execute on function public.question_shape_ok(text, text[], int, jsonb, jsonb) to authenticated, service_role;
revoke all on function
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text)
from public, anon, authenticated;
grant execute on function
  public.question_reveal(public.questions),
  public.grade_response(public.questions, jsonb),
  public.question_time_limit(public.questions, text)
to service_role;
