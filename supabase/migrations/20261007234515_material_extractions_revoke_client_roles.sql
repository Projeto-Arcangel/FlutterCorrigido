-- Em produção o projeto ainda tem os privilégios padrão antigos do Supabase:
-- toda tabela nova do schema public recebe TODOS os privilégios para anon e
-- authenticated. A RLS (sem policies) já esconde as linhas, mas TRUNCATE não
-- passa pela RLS — e esta tabela é só do servidor (service_role).
revoke all on public.material_extractions from anon, authenticated;
