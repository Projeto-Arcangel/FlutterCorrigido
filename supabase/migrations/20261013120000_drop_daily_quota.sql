-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Remove a cota diária antiga                                        ║
-- ║                                                                    ║
-- ║  Os limites agora são os dos planos (migration 20261012120000):    ║
-- ║  plan_reserve nas Edge Functions e my_plan no app. As funções da   ║
-- ║  cota diária (20 questões e 10 vídeos por dia) não são mais        ║
-- ║  chamadas por nenhum código. Uma versão antiga do app que ainda    ║
-- ║  chame my_ai_quota só deixa de mostrar o indicador diário.         ║
-- ╚══════════════════════════════════════════════════════════════════╝

drop function if exists public.my_ai_quota();
drop function if exists public.ai_questions_today(uuid);
drop function if exists public.videos_read_today(uuid);
