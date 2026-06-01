-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ 05 · Row Level Security (deny-by-default + políticas)              ║
-- ╚══════════════════════════════════════════════════════════════════╝
-- service_role (Edge Functions) ignora RLS. Todas as políticas abaixo
-- são restritas a `authenticated`.

alter table public.profiles             enable row level security;
alter table public.user_progress        enable row level security;
alter table public.classrooms           enable row level security;
alter table public.classroom_members    enable row level security;
alter table public.classroom_phases     enable row level security;
alter table public.questions            enable row level security;
alter table public.classroom_results    enable row level security;
alter table public.classroom_activities enable row level security;
alter table public.achievements         enable row level security;
alter table public.user_achievements    enable row level security;
alter table public.ai_generation_logs   enable row level security;

-- ── profiles ──────────────────────────────────────────────────────────
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
-- INSERT: feito pelo trigger handle_new_user (security definer); sem policy p/ cliente.

-- ── user_progress (leitura própria; escrita SÓ via RPCs award_*) ──────
create policy progress_select_own on public.user_progress
  for select to authenticated using (user_id = auth.uid());

-- ── classrooms ────────────────────────────────────────────────────────
create policy classrooms_select on public.classrooms
  for select to authenticated using (teacher_id = auth.uid() or public.is_member(id));
create policy classrooms_insert on public.classrooms
  for insert to authenticated with check (public.is_teacher() and teacher_id = auth.uid());
create policy classrooms_update on public.classrooms
  for update to authenticated using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy classrooms_delete on public.classrooms
  for delete to authenticated using (teacher_id = auth.uid());

-- ── classroom_members ─────────────────────────────────────────────────
create policy members_select on public.classroom_members
  for select to authenticated
  using (public.owns_classroom(classroom_id) or public.is_member(classroom_id));
create policy members_insert_self on public.classroom_members
  for insert to authenticated with check (student_id = auth.uid());
create policy members_delete on public.classroom_members
  for delete to authenticated using (student_id = auth.uid() or public.owns_classroom(classroom_id));

-- ── classroom_phases ──────────────────────────────────────────────────
create policy phases_select on public.classroom_phases
  for select to authenticated using (public.owns_classroom(classroom_id) or public.is_member(classroom_id));
create policy phases_write on public.classroom_phases
  for all to authenticated
  using (public.owns_classroom(classroom_id))
  with check (public.owns_classroom(classroom_id));

-- ── questions (sempre via fase → sala) ────────────────────────────────
create policy questions_read on public.questions
  for select to authenticated using (
    exists (
      select 1 from public.classroom_phases ph
      where ph.id = questions.phase_id
        and (public.owns_classroom(ph.classroom_id) or public.is_member(ph.classroom_id))
    )
  );
create policy questions_write on public.questions
  for all to authenticated
  using (
    exists (
      select 1 from public.classroom_phases ph
      where ph.id = questions.phase_id and public.owns_classroom(ph.classroom_id)
    )
  )
  with check (
    exists (
      select 1 from public.classroom_phases ph
      where ph.id = questions.phase_id and public.owns_classroom(ph.classroom_id)
    )
  );

-- ── classroom_results ─────────────────────────────────────────────────
create policy results_select on public.classroom_results
  for select to authenticated using (public.owns_classroom(classroom_id) or student_id = auth.uid());
create policy results_insert on public.classroom_results
  for insert to authenticated with check (student_id = auth.uid() and public.is_member(classroom_id));
create policy results_update_own on public.classroom_results
  for update to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());

-- ── classroom_activities (leitura só dono; escrita só server-side) ────
create policy activities_select on public.classroom_activities
  for select to authenticated using (public.owns_classroom(classroom_id));

-- ── achievements (catálogo: leitura p/ autenticados) ──────────────────
create policy achievements_read on public.achievements
  for select to authenticated using (auth.uid() is not null);

-- ── user_achievements (próprias) ──────────────────────────────────────
create policy user_achievements_select on public.user_achievements
  for select to authenticated using (user_id = auth.uid());

-- ── ai_generation_logs (próprios; escrita só Edge Function/service_role)
create policy ai_logs_select_own on public.ai_generation_logs
  for select to authenticated using (teacher_id = auth.uid());
