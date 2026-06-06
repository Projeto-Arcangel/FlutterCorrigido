-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Endurecimento de segurança (correções rápidas da auditoria)        ║
-- ║                                                                    ║
-- ║  1.2 · Fechar escrita direta em classroom_results (forja de nota)  ║
-- ║  Alto · Prontuário (PII) deixa de vazar entre alunos               ║
-- ║   3  · Teto em award_gold                                          ║
-- ║   4  · Remover a view public_profiles (exposição sem uso)          ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1.2 · classroom_results: só o submit_result (SECURITY DEFINER) grava ──
-- O cliente NÃO precisa de insert/update direto (o submit_result roda como
-- dono e ignora RLS/grant). Remover o grant + as policies elimina o vetor de
-- forjar/sobrescrever a própria nota via PostgREST. SELECT continua liberado
-- (aluno vê a própria linha; professor vê as da turma via owns_classroom).
revoke insert, update on public.classroom_results from authenticated;
drop policy if exists results_insert      on public.classroom_results;
drop policy if exists results_update_own  on public.classroom_results;

-- ── Alto · get_classroom_phase_results passa a ser SOMENTE do dono ────────
-- Notas por fase + prontuário são dados do professor. Antes qualquer membro
-- (aluno) podia chamar e colher nome+prontuário+nota de todos os colegas.
create or replace function public.get_classroom_phase_results(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'student_id',      r.student_id,
    'student_name',    coalesce(p.display_name, ''),
    'registration',    coalesce(p.student_id, ''),
    'phase_id',        r.phase_id,
    'total_questions', r.total_questions,
    'correct_answers', r.correct_answers,
    'completed_at',    r.completed_at
  )), '[]'::jsonb)
  from public.classroom_results r
  left join public.profiles p on p.id = r.student_id
  where r.classroom_id = p_classroom
    and r.phase_id is not null
    and public.owns_classroom(p_classroom);   -- só o professor dono
$$;

-- ── Alto · get_classroom_results (ranking do aluno) sem prontuário ────────
-- O ranking precisa só de nome + acertos. Remover 'registration' impede que
-- um aluno membro leia o prontuário (PII) dos colegas por esta RPC.
create or replace function public.get_classroom_results(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(agg.row), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'student_id',      r.student_id,
      'student_name',    coalesce(max(p.display_name), ''),
      'total_questions', sum(r.total_questions),
      'correct_answers', sum(r.correct_answers),
      'completed_at',    max(r.completed_at)
    ) as row
    from public.classroom_results r
    left join public.profiles p on p.id = r.student_id
    where r.classroom_id = p_classroom
      and r.phase_id is not null
      and (public.owns_classroom(p_classroom) or public.is_member(p_classroom))
    group by r.student_id
  ) agg;
$$;

-- ── 3 · Teto em award_gold (mitiga inflação por chamada) ──────────────────
-- Mitigação: continua chamável pelo cliente, mas com limite por chamada
-- (a app concede 5/quiz). A correção estrutural — premiar dentro do
-- submit_result validado — fica no plano à parte.
create or replace function public.award_gold(p_amount int)
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress;
begin
  if p_amount is null or p_amount <= 0 or p_amount > 100 then
    raise exception 'Gold inválido' using errcode = '22023';
  end if;
  update public.user_progress set gold = gold + p_amount
   where user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

-- ── 4 · Remover a view public_profiles (exposição ampla e sem uso) ────────
-- Expunha nome/foto/role/id de TODOS os usuários a qualquer autenticado
-- (security_invoker=false ignora RLS). O app resolve nomes pelas RPCs
-- definer (classroom_to_json etc.), então a view é só superfície de ataque.
drop view if exists public.public_profiles;
