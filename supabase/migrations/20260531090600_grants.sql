-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 06 · GRANTs explícitos para os papéis da Data API                  ║
-- ╚══════════════════════════════════════════════════════════════════╝
-- A partir de 2026-05-30 o Supabase NÃO concede privilégios automáticos
-- a anon/authenticated/service_role em objetos novos do schema `public`
-- (auto_expose_new_tables = false). RLS controla LINHAS, mas o papel
-- ainda precisa de GRANT na tabela e EXECUTE nas funções usadas pela RLS.
-- `anon` permanece SEM acesso (o app exige autenticação).

grant usage on schema public to authenticated, service_role;

-- ── Privilégios de tabela para `authenticated` (RLS filtra as linhas) ──
grant select, update                  on public.profiles             to authenticated;
grant select                          on public.user_progress        to authenticated;
grant select, insert, update, delete  on public.classrooms           to authenticated;
grant select, insert, delete          on public.classroom_members    to authenticated;
grant select, insert, update, delete  on public.classroom_phases     to authenticated;
grant select, insert, update, delete  on public.questions            to authenticated;
grant select, insert, update          on public.classroom_results    to authenticated;
grant select                          on public.classroom_activities to authenticated;
grant select                          on public.achievements         to authenticated;
grant select                          on public.user_achievements    to authenticated;
grant select                          on public.ai_generation_logs   to authenticated;

-- ── service_role (Edge Functions) — acesso total; ignora RLS ──────────
grant all on all tables in schema public to service_role;

-- ── EXECUTE nas funções helper usadas dentro das políticas RLS ────────
-- (sem isso, qualquer query com RLS que chama esses helpers falha com
--  "permission denied for function ...").
grant execute on function public.is_teacher()             to authenticated;
grant execute on function public.owns_classroom(uuid)     to authenticated;
grant execute on function public.is_member(uuid)          to authenticated;
