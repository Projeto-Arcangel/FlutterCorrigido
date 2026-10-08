-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Endurecimento de privilégios (auditoria de 2026-10-08)              ║
-- ║                                                                    ║
-- ║  O projeto ainda tinha os privilégios padrão antigos do Supabase:  ║
-- ║  toda tabela/função nova do schema public nascia com TODOS os      ║
-- ║  privilégios para anon e authenticated (inclusive TRUNCATE), e só  ║
-- ║  a RLS protegia. A migration 20260531090600_grants pressupunha o   ║
-- ║  contrário, e o resultado era igual no local e em produção.        ║
-- ║                                                                    ║
-- ║  Aqui: (1) objetos novos nascem fechados; (2) tabelas e funções    ║
-- ║  existentes ficam só com o que o app usa (inventário do código em  ║
-- ║  lib/ e supabase/functions/); (3) correções pontuais da auditoria. ║
-- ║                                                                    ║
-- ║  REGRA a partir daqui: toda tabela/função nova precisa de GRANT    ║
-- ║  explícito na própria migration — sem ele, o app não a enxerga.    ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Objetos novos nascem fechados ─────────────────────────────────
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;
-- EXECUTE para PUBLIC é padrão global do Postgres (não vale por schema):
-- sem isto, anon executaria toda função nova por ser membro de PUBLIC.
alter default privileges for role postgres
  revoke execute on functions from public;

-- ── 2. Tabelas: só o que o app usa ───────────────────────────────────
-- anon: nada (o app exige login). As RPCs SECURITY DEFINER escrevem
-- como dono e não dependem destes grants.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- Professor gerencia fases e questões (a RLS restringe ao dono da turma).
grant select, insert, update, delete on public.classroom_phases to authenticated;
grant select, insert, update, delete on public.questions        to authenticated;

-- Turma: criada pela RPC create_classroom; o app só edita nome/descrição
-- e apaga. (SELECT é necessário também para os filtros do UPDATE/DELETE.)
grant select, delete              on public.classrooms to authenticated;
grant update (name, description)  on public.classrooms to authenticated;

-- Membros: entrar só pela RPC join_classroom (que checa turma ativa e
-- vagas); sair/remover aluno pelo DELETE (RLS: o próprio aluno ou o dono).
grant select, delete on public.classroom_members to authenticated;
-- A policy permitia a qualquer usuário se inserir em QUALQUER turma pela
-- API, pulando as checagens da RPC. Sem o GRANT ela já seria inócua; sai
-- para não voltar a valer por acidente.
drop policy if exists members_insert_self on public.classroom_members;

-- Perfil: leitura do próprio e edição só das colunas que o app altera.
-- Papel (role), e-mail e — no Estágio 2 — o plano ficam fora do alcance
-- do cliente mesmo que uma policy falhe.
grant select on public.profiles to authenticated;
grant update (display_name, student_id, grade_approve_pct, grade_recovery_pct)
  on public.profiles to authenticated;

-- Somente leitura (a RLS filtra as linhas).
grant select on
  public.classroom_results,
  public.classroom_activities,
  public.user_progress,
  public.achievements,
  public.user_achievements,
  public.enem_questions,
  public.ai_generation_logs
to authenticated;

-- Edge Functions (service_role) continuam com acesso total.
grant all on all tables in schema public to service_role;

-- ── 3. Funções: só as RPCs do app e os helpers da RLS ────────────────
revoke execute on all functions in schema public from public, anon, authenticated;
grant  execute on all functions in schema public to service_role;

-- Usadas dentro das policies (avaliadas com o papel de quem consulta).
grant execute on function
  public.is_teacher(),
  public.owns_classroom(uuid),
  public.is_member(uuid)
to authenticated;

-- RPCs chamadas pelo app.
grant execute on function
  public.create_classroom(text, text),
  public.delete_account(),
  public.get_classroom_by_code(text),
  public.get_classroom_phase_results(uuid),
  public.get_classroom_results(uuid),
  public.get_student_classrooms(),
  public.get_student_phases(uuid),
  public.get_teacher_classrooms(),
  public.join_classroom(uuid),
  public.my_ai_quota(),
  public.set_role(public.user_role),
  public.submit_quiz(uuid, uuid, jsonb)
to authenticated;

-- Ficam só para o servidor (sem uso no app ou só internas):
--   classroom_to_json  devolvia código de entrada e alunos de QUALQUER
--                      turma a quem tivesse o ID, até sem login;
--   award_gold, award_xp, advance_phase, register_login  sem uso no app;
--                      award_gold/advance_phase permitiam ganhar ouro e
--                      pular fases à vontade;
--   handle_new_user, on_phase_created, lock_student_id,
--   prevent_role_escalation, set_updated_at  funções de gatilho (o
--                      gatilho dispara sem precisar de EXECUTE);
--   gen_classroom_code, level_for_xp  usadas dentro de outras funções;
--   ai_questions_today, videos_read_today  cota das Edge Functions.

-- ── 4. Cadastro: o papel vindo do metadata só pode ser aluno/professor ─
-- Antes, um cadastro feito direto na API de Auth com role "admin" no
-- metadata virava admin, contornando a set_role (que só aceita
-- student/teacher). Qualquer outro valor vira NULL e o app pede o papel.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, photo_url, role, student_id)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'display_name',
    new.raw_user_meta_data ->> 'photo_url',
    case
      when new.raw_user_meta_data ->> 'role' in ('student', 'teacher')
        then (new.raw_user_meta_data ->> 'role')::public.user_role
    end,
    -- prontuário (opcional); string vazia vira NULL.
    nullif(new.raw_user_meta_data ->> 'student_id', '')
  );
  insert into public.user_progress (user_id) values (new.id);
  return new;
end;
$$;

-- ── 5. search_path fixo (linter 0011) ────────────────────────────────
-- Sem ele, quem chama poderia mudar o search_path e trocar o que as
-- funções resolvem. Todas usam só pg_catalog ou nomes qualificados.
alter function public.level_for_xp(numeric)      set search_path = '';
alter function public.gen_classroom_code()       set search_path = '';
alter function public.set_updated_at()           set search_path = '';
alter function public.prevent_role_escalation()  set search_path = '';
alter function public.lock_student_id()          set search_path = '';

comment on table public.material_extractions is
  'Leituras de materiais (vídeos) feitas no servidor. Só o service_role acessa: RLS ligada e sem policies de propósito.';
