-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Palavras de 1 letra na cruzadinha e no caça-palavras               ║
-- ║                                                                    ║
-- ║  Pedido do professor-dono do produto (2026-10-19): o mínimo por    ║
-- ║  palavra cai de 3 para 1 letra (ex.: símbolos químicos, notas,     ║
-- ║  vogais). O máximo continua 15 no banco (12 no app). Na            ║
-- ║  cruzadinha, a palavra de 1 letra ocupa uma casa (de outra palavra ║
-- ║  ou solta) e a grade pode ter 1 ou 2 linhas (antes, mínimo 3). No  ║
-- ║  caça-palavras, o aluno marca a letra tocando nela duas vezes, e   ║
-- ║  grid_line já lê uma casa só.                                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

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

-- ── Privilégios (regra da migration 20261008120000) ─────────────────
-- Rodam dentro da CHECK de questions (INSERT/UPDATE do professor).
revoke all on function
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
from public, anon;
grant execute on function
  public.crossword_ok(jsonb, jsonb),
  public.word_search_ok(jsonb, jsonb)
to authenticated, service_role;
