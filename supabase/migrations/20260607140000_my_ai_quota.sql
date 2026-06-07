-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Cota de IA do próprio professor (para exibir na tela de criação)   ║
-- ║                                                                    ║
-- ║  `ai_questions_today` recebe um teacher_id e é só do service_role   ║
-- ║  (não expõe uso alheio). Aqui há uma versão "self": usa auth.uid()  ║
-- ║  e pode ser chamada pelo cliente — cada professor vê só o PRÓPRIO   ║
-- ║  consumo do dia, para mostrar "X de N questões".                    ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.my_ai_quota()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'used',      u,
    'limit',     20,   -- MANTER igual a DAILY_QUESTION_LIMIT (Edge generate-questions)
    'remaining', greatest(0, 20 - u)
  )
  from (select public.ai_questions_today(auth.uid()) as u) t;
$$;

revoke all     on function public.my_ai_quota() from public, anon;
grant  execute on function public.my_ai_quota() to authenticated;
