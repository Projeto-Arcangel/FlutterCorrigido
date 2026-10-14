-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Excluir questões pelo banco "Reutilizar minhas questões"            ║
-- ║                                                                    ║
-- ║  O professor exclui questões de qualquer turma dele direto pelo    ║
-- ║  banco: elas somem da fase em que estão e as fases afetadas são    ║
-- ║  renumeradas (1, 2, 3...). Tudo numa transação: ou todas saem e    ║
-- ║  as posições ficam certas, ou nada muda. Devolve quantas saíram.   ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.delete_my_questions(p_question_ids uuid[])
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_phases uuid[];
  v_count  int;
begin
  if p_question_ids is null or cardinality(p_question_ids) = 0 then
    raise exception 'Escolha ao menos uma questão.' using errcode = '22023';
  end if;
  if cardinality(p_question_ids) > 200 then
    raise exception 'Exclua no máximo 200 questões por vez.' using errcode = '22023';
  end if;

  -- Só questões das turmas do professor logado.
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

  -- Trava as fases afetadas, em ordem fixa: uma cópia ou outra exclusão ao
  -- mesmo tempo espera, em vez de embaralhar as posições.
  select array_agg(distinct q.phase_id order by q.phase_id) into v_phases
    from public.questions q
   where q.id = any (p_question_ids);
  perform 1 from public.classroom_phases ph
   where ph.id = any (v_phases)
   order by ph.id
     for update;

  delete from public.questions where id = any (p_question_ids);
  get diagnostics v_count = row_count;

  -- Renumera o que sobrou em cada fase afetada, mantendo a ordem.
  update public.questions q
     set sort_order = r.pos
    from (select id,
                 row_number() over (partition by phase_id
                                    order by sort_order, created_at, id) as pos
            from public.questions
           where phase_id = any (v_phases)) r
   where q.id = r.id and q.sort_order is distinct from r.pos;

  return v_count;
end;
$$;

-- Regra da migration 20261008120000: GRANT explícito para o app.
revoke all on function public.delete_my_questions(uuid[]) from public, anon, authenticated;
grant execute on function public.delete_my_questions(uuid[]) to authenticated, service_role;
