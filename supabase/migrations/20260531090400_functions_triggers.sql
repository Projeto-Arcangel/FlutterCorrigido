-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 04 · Funções, triggers e RPCs                                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ─────────────────────────────────────────────────────────────────────
-- 4.1 · Criação automática de perfil + progresso no signup
-- ─────────────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, display_name, photo_url, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'display_name',
    new.raw_user_meta_data ->> 'photo_url',
    -- role propositalmente NULL quando não vem no metadata: o app força a
    -- RoleSelectionPage e grava via RPC set_role. (não usar default aqui)
    (new.raw_user_meta_data ->> 'role')::public.user_role
  );
  insert into public.user_progress (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────
-- 4.2 · View pública de perfis (nome/foto/role — sem e-mail)
-- ─────────────────────────────────────────────────────────────────────
-- security_invoker=false → ignora a RLS de profiles, expondo apenas as
-- colunas não sensíveis a qualquer autenticado (professor vê nome do
-- aluno nos resultados; aluno vê nome do professor).
create view public.public_profiles
  with (security_invoker = false) as
  select id, display_name, photo_url, role from public.profiles;

revoke all on public.public_profiles from anon;
grant select on public.public_profiles to authenticated;

-- ─────────────────────────────────────────────────────────────────────
-- 4.3 · Anti-escalada de privilégio (lock de role)
-- ─────────────────────────────────────────────────────────────────────
-- Bloqueia QUALQUER mudança direta de role; só a RPC set_role (que ergue
-- a flag de bypass na transação) pode alterar.
create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role
     and coalesce(current_setting('app.bypass_role_guard', true), 'off') <> 'on' then
    raise exception 'Alteração de role não permitida pelo cliente';
  end if;
  return new;
end;
$$;

create trigger profiles_lock_role
  before update on public.profiles
  for each row execute function public.prevent_role_escalation();

-- Define o role do usuário atual de forma controlada (aluno ↔ professor).
create or replace function public.set_role(p_role public.user_role)
returns public.profiles
language plpgsql security definer set search_path = public
as $$
declare v_row public.profiles;
begin
  if p_role not in ('student', 'teacher') then
    raise exception 'Role inválido: %', p_role using errcode = '22023';
  end if;
  perform set_config('app.bypass_role_guard', 'on', true);  -- local à transação
  update public.profiles set role = p_role
   where id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4.4 · Helpers para RLS (SECURITY DEFINER evita recursão de políticas)
-- ─────────────────────────────────────────────────────────────────────
create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('teacher', 'admin')
  );
$$;

create or replace function public.owns_classroom(p_classroom uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.classrooms
    where id = p_classroom and teacher_id = auth.uid()
  );
$$;

create or replace function public.is_member(p_classroom uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.classroom_members
    where classroom_id = p_classroom and student_id = auth.uid()
  );
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4.5 · Gamificação — XP/gold/streak só mudam por estas RPCs
-- ─────────────────────────────────────────────────────────────────────
-- Curva polinomial (base 80, expoente 1.5) — espelha level_utils.dart.
create or replace function public.level_for_xp(p_xp numeric)
returns int language plpgsql immutable as $$
declare lvl int := 1; total numeric := 0;
begin
  loop
    total := total + floor(80 * power(lvl, 1.5));
    exit when p_xp < total;
    lvl := lvl + 1;
  end loop;
  return lvl;
end;
$$;

create or replace function public.award_xp(p_amount numeric)
returns public.user_progress
language plpgsql security definer set search_path = public
as $$
declare v_row public.user_progress; v_new_level int;
begin
  if p_amount is null or p_amount <= 0 or p_amount > 1000 then
    raise exception 'XP inválido: %', p_amount using errcode = '22023';
  end if;

  update public.user_progress set xp = xp + p_amount
   where user_id = auth.uid()
  returning * into v_row;

  if v_row.user_id is null then
    raise exception 'Progresso do usuário não encontrado' using errcode = 'P0002';
  end if;

  v_new_level := public.level_for_xp(v_row.xp);
  if v_new_level > v_row.level then
    update public.user_progress set level = v_new_level
     where user_id = auth.uid() returning * into v_row;
  end if;

  return v_row;
end;
$$;

create or replace function public.award_gold(p_amount int)
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Gold inválido';
  end if;
  update public.user_progress set gold = gold + p_amount
   where user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

-- Atualiza streak de login (RF02.4) de forma idempotente no servidor.
create or replace function public.register_login()
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress; v_last date;
begin
  select last_login_date into v_last from public.user_progress where user_id = auth.uid();
  update public.user_progress
     set streak = case
           when v_last = current_date then streak                -- já logou hoje
           when v_last = current_date - 1 then streak + 1         -- dia consecutivo
           else 1                                                 -- quebrou ou primeiro
         end,
         last_login_date = current_date
   where user_id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;

-- Avança a fase atual do usuário (escrita direta em user_progress é
-- bloqueada pela RLS; só muda por esta RPC).
create or replace function public.advance_phase(p_phase int)
returns public.user_progress
language plpgsql security definer set search_path = public as $$
declare v_row public.user_progress;
begin
  if p_phase is null or p_phase < 1 then
    raise exception 'Fase inválida';
  end if;
  update public.user_progress set current_phase = p_phase
   where user_id = auth.uid() returning * into v_row;
  return v_row;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4.6 · Salas — código único, entrar, registrar resultado
-- ─────────────────────────────────────────────────────────────────────
-- Gera um código de 6 chars sem caracteres ambíguos.
create or replace function public.gen_classroom_code()
returns text language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code  text := '';
  i     int;
begin
  for i in 1..6 loop
    code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return code;
end;
$$;

-- Cria uma sala com código único garantido (loop até não colidir).
create or replace function public.create_classroom(p_name text, p_description text default '')
returns public.classrooms
language plpgsql security definer set search_path = public as $$
declare v_code text; v_row public.classrooms;
begin
  if not public.is_teacher() then
    raise exception 'Apenas professores podem criar salas' using errcode = '42501';
  end if;

  loop
    v_code := public.gen_classroom_code();
    exit when not exists (select 1 from public.classrooms where code = v_code);
  end loop;

  insert into public.classrooms (code, name, description, teacher_id)
  values (v_code, p_name, coalesce(p_description, ''), auth.uid())
  returning * into v_row;

  return v_row;
end;
$$;

-- Aluno entra numa sala pelo código (resolve o chicken-and-egg da RLS:
-- ele ainda não é membro, então não conseguiria ler a sala via SELECT).
create or replace function public.join_classroom(p_code text)
returns public.classrooms
language plpgsql security definer set search_path = public as $$
declare v_room public.classrooms; v_count int;
begin
  select * into v_room from public.classrooms
   where upper(code) = upper(p_code) and is_active = true;
  if v_room.id is null then
    raise exception 'Sala não encontrada ou inativa' using errcode = 'P0002';
  end if;

  select count(*) into v_count from public.classroom_members where classroom_id = v_room.id;
  if v_count >= v_room.max_students then
    raise exception 'Sala lotada' using errcode = 'P0001';
  end if;

  insert into public.classroom_members (classroom_id, student_id)
  values (v_room.id, auth.uid())
  on conflict do nothing;

  insert into public.classroom_activities (classroom_id, type, description)
  select v_room.id, 'student_joined',
         coalesce((select display_name from public.profiles where id = auth.uid()), 'Um aluno')
         || ' entrou na turma';

  return v_room;
end;
$$;

-- Registra (ou atualiza) o resultado do aluno numa fase + grava a atividade.
create or replace function public.submit_result(
  p_classroom uuid,
  p_phase     uuid,
  p_total     int,
  p_correct   int
)
returns public.classroom_results
language plpgsql security definer set search_path = public as $$
declare v_row public.classroom_results; v_name text; v_phase_title text;
begin
  if not public.is_member(p_classroom) then
    raise exception 'Você não é membro desta sala' using errcode = '42501';
  end if;
  if p_correct < 0 or p_total < 0 or p_correct > p_total then
    raise exception 'Resultado inválido' using errcode = '22023';
  end if;

  insert into public.classroom_results
    (classroom_id, student_id, phase_id, total_questions, correct_answers)
  values (p_classroom, auth.uid(), p_phase, p_total, p_correct)
  on conflict (classroom_id, student_id, phase_id) do update
    set total_questions = excluded.total_questions,
        correct_answers = excluded.correct_answers,
        completed_at     = now()
  returning * into v_row;

  select display_name into v_name from public.profiles where id = auth.uid();
  select title into v_phase_title from public.classroom_phases where id = p_phase;

  insert into public.classroom_activities (classroom_id, type, description)
  values (
    p_classroom, 'student_completed',
    coalesce(v_name, 'Um aluno') || ' concluiu'
      || coalesce(' a fase "' || v_phase_title || '"', '')
  );

  return v_row;
end;
$$;

-- Exclui a própria conta (auth.users → cascade apaga profile/progresso).
-- O cliente Supabase não consegue auto-deletar usuário (só service_role),
-- por isso a operação fica numa função SECURITY DEFINER restrita ao próprio uid.
create or replace function public.delete_account()
returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4.7 · Permissões de execução (RPCs só para autenticados)
-- ─────────────────────────────────────────────────────────────────────
do $$
declare fn text;
begin
  foreach fn in array array[
    'public.set_role(public.user_role)',
    'public.award_xp(numeric)',
    'public.award_gold(integer)',
    'public.advance_phase(integer)',
    'public.register_login()',
    'public.create_classroom(text, text)',
    'public.join_classroom(text)',
    'public.submit_result(uuid, uuid, integer, integer)',
    'public.delete_account()'
  ] loop
    execute format('revoke all on function %s from public, anon;', fn);
    execute format('grant execute on function %s to authenticated;', fn);
  end loop;
end;
$$;
