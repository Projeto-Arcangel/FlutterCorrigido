-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Reordenação atômica de fases e questões                            ║
-- ║                                                                    ║
-- ║  O app gravava a nova ordem com um UPDATE por item, em sequência.  ║
-- ║  Se a rede caísse no meio, metade dos itens ficava com a posição   ║
-- ║  nova e metade com a antiga — posições repetidas e uma ordem que   ║
-- ║  não era nem a antiga nem a nova (testado: [1,1,2,2,3,3]). Duas    ║
-- ║  gravações seguidas também podiam se intercalar.                   ║
-- ║                                                                    ║
-- ║  Agora a ordem inteira é gravada num único UPDATE: ou todos os     ║
-- ║  itens mudam, ou nenhum. A lista enviada precisa ter exatamente os ║
-- ║  itens da turma/fase, cada um uma vez — nada fica sem posição.     ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.reorder_phases(p_classroom uuid, p_phase_ids uuid[])
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.owns_classroom(p_classroom) then
    raise exception 'Apenas o professor da turma pode reordenar as fases.'
      using errcode = '42501';
  end if;

  if p_phase_ids is null
     or cardinality(p_phase_ids) <> (
       select count(*) from public.classroom_phases where classroom_id = p_classroom)
     or cardinality(p_phase_ids) <> (select count(distinct x) from unnest(p_phase_ids) x)
     or exists (
       select 1 from unnest(p_phase_ids) x
        where not exists (
          select 1 from public.classroom_phases p
           where p.id = x and p.classroom_id = p_classroom))
  then
    raise exception 'A lista de fases mudou. Recarregue a página e tente de novo.'
      using errcode = '22023';
  end if;

  update public.classroom_phases p
     set sort_order = o.pos
    from unnest(p_phase_ids) with ordinality as o(id, pos)
   where p.id = o.id;
end;
$$;

create or replace function public.reorder_questions(p_phase uuid, p_question_ids uuid[])
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not exists (
    select 1 from public.classroom_phases ph
     where ph.id = p_phase and public.owns_classroom(ph.classroom_id))
  then
    raise exception 'Apenas o professor da turma pode reordenar as questões.'
      using errcode = '42501';
  end if;

  if p_question_ids is null
     or cardinality(p_question_ids) <> (
       select count(*) from public.questions where phase_id = p_phase)
     or cardinality(p_question_ids) <> (select count(distinct x) from unnest(p_question_ids) x)
     or exists (
       select 1 from unnest(p_question_ids) x
        where not exists (
          select 1 from public.questions q
           where q.id = x and q.phase_id = p_phase))
  then
    raise exception 'A lista de questões mudou. Recarregue a página e tente de novo.'
      using errcode = '22023';
  end if;

  update public.questions q
     set sort_order = o.pos
    from unnest(p_question_ids) with ordinality as o(id, pos)
   where q.id = o.id;
end;
$$;

-- Regra da migration 20261008120000: GRANT explícito para o app.
revoke all on function public.reorder_phases(uuid, uuid[])    from public, anon, authenticated;
revoke all on function public.reorder_questions(uuid, uuid[]) from public, anon, authenticated;
grant execute on function public.reorder_phases(uuid, uuid[])    to authenticated, service_role;
grant execute on function public.reorder_questions(uuid, uuid[]) to authenticated, service_role;
