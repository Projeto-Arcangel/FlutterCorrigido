-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Ordenar: nota por posição — Estágio 4                              ║
-- ║                                                                    ║
-- ║  Antes: maior sequência de itens na ordem certa entre si.          ║
-- ║  Agora: itens na posição certa / total — cada item que está no     ║
-- ║  lugar certo vale, mesmo que os vizinhos estejam fora (pedido do   ║
-- ║  dono do produto). Ex.: certo A-B-C-D, resposta A-C-B-D = 2/4.     ║
-- ║  O resto da correção fica igual.                                   ║
-- ╚══════════════════════════════════════════════════════════════════╝

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

-- create or replace mantém os privilégios; reafirmados aqui.
revoke all on function public.grade_response(public.questions, jsonb) from public, anon, authenticated;
grant execute on function public.grade_response(public.questions, jsonb) to service_role;
