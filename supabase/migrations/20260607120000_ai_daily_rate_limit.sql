-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Rate-limit de geração por IA (controle de custo no OpenRouter)     ║
-- ║                                                                    ║
-- ║  Teto de 20 questões geradas por professor por dia (fuso de SP).   ║
-- ║  A contagem é feita sobre ai_generation_logs (status='success'),   ║
-- ║  somando a coluna `quantity` (questões pedidas em cada geração).   ║
-- ║                                                                    ║
-- ║  A Edge Function generate-questions consulta esta função (via      ║
-- ║  service_role) ANTES de chamar o OpenRouter e recusa com HTTP 429  ║
-- ║  quando o pedido estouraria o teto. A constante do teto vive na    ║
-- ║  Edge Function (DAILY_QUESTION_LIMIT) — aqui só contamos o uso.    ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- Soma das questões geradas com sucesso HOJE (00:00–23:59 America/Sao_Paulo)
-- pelo professor informado. SECURITY DEFINER: roda como dono e ignora a RLS
-- de ai_generation_logs (a Edge Function passa o teacher_id já autenticado).
create or replace function public.ai_questions_today(p_teacher uuid)
returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(coalesce(quantity, 0)), 0)::int
  from public.ai_generation_logs
  where teacher_id = p_teacher
    and status = 'success'
    and (created_at at time zone 'America/Sao_Paulo')::date
      = (now()       at time zone 'America/Sao_Paulo')::date;
$$;

-- Só o servidor (Edge Function via service_role) consulta o uso. NÃO exposta
-- ao cliente: o parâmetro é um teacher_id arbitrário, então liberar para
-- `authenticated` permitiria espiar o uso de IA de qualquer outro professor.
revoke all on function public.ai_questions_today(uuid) from public, anon, authenticated;
grant execute on function public.ai_questions_today(uuid) to service_role;