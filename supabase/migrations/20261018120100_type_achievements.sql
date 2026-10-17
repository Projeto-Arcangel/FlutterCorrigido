-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Conquistas por tipo — Estágio 4, Etapa 5                            ║
-- ║                                                                    ║
-- ║  As conquistas de XP continuam (calculadas pelo XP). Entram 7 por  ║
-- ║  tipo de questão/mecânica, conferidas no servidor e liberadas ao   ║
-- ║  entregar a tentativa, com 10 moedas cada:                         ║
-- ║   Eletricista     5 questões de ligar com todos os fios certos     ║
-- ║   Organizado      5 questões de ordenar sem erro                   ║
-- ║   Completa-tudo   5 questões de lacunas sem erro                   ║
-- ║   Cruciverbalista 3 cruzadinhas sem erro                           ║
-- ║   Detetive        3 caça-palavras com todas as palavras            ║
-- ║   Em chamas       sequência de 5 acertos                           ║
-- ║   Três estrelas   3 estrelas numa fase                             ║
-- ║  Contam questões DIFERENTES: refazer a mesma não soma (sem farm).  ║
-- ║                                                                    ║
-- ║  Perfil do colega: quem é da turma vê, pelo ranking, nome, foto,   ║
-- ║  nível, XP, estrelas e fases na turma e as conquistas — nunca      ║
-- ║  e-mail nem prontuário.                                            ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Catálogo ──────────────────────────────────────────────────────
alter table public.achievements
  add column criterion   text not null default 'xp'
    constraint achievements_criterion_check check (criterion in (
      'xp', 'match_perfect', 'ordering_perfect', 'blanks_perfect',
      'crossword_perfect', 'word_search_perfect', 'streak', 'three_stars')),
  add column goal        int check (goal is null or goal > 0),
  add column gold_reward int not null default 0 check (gold_reward >= 0),
  add column sort_order  int not null default 0;

comment on column public.achievements.criterion is
  'O que conta: xp (usa xp_required) ou um contador do servidor (achievement_progress).';

update public.achievements set sort_order = case id
  when 'first_step' then 1 when 'scholar' then 2 when 'dedicated' then 3
  when 'historian' then 4 when 'sage' then 5 when 'legend' then 6 else 99 end
 where criterion = 'xp';

insert into public.achievements
  (id, title, description, rarity, xp_required, icon, criterion, goal, gold_reward, sort_order)
values
  ('electrician',    'Eletricista',     'Ligue todos os fios certos em 5 questões',     'silver', 0, 'cable',        'match_perfect',       5, 10, 10),
  ('organized',      'Organizado',      'Ordene sem erro 5 questões',                   'silver', 0, 'format_list',  'ordering_perfect',    5, 10, 11),
  ('blank_filler',   'Completa-tudo',   'Acerte todas as lacunas em 5 questões',        'silver', 0, 'edit_note',    'blanks_perfect',      5, 10, 12),
  ('cruciverbalist', 'Cruciverbalista', 'Complete 3 cruzadinhas sem erro',              'gold',   0, 'grid',         'crossword_perfect',   3, 10, 13),
  ('detective',      'Detetive',        'Ache todas as palavras em 3 caça-palavras',    'gold',   0, 'search',       'word_search_perfect', 3, 10, 14),
  ('on_fire',        'Em chamas',       'Acerte 5 questões seguidas',                   'bronze', 0, 'fire',         'streak',              5, 10, 15),
  ('three_stars',    'Três estrelas',   'Tire 3 estrelas numa fase',                    'gold',   0, 'stars',        'three_stars',         1, 10, 16)
on conflict (id) do update set
  title = excluded.title, description = excluded.description, rarity = excluded.rarity,
  xp_required = excluded.xp_required, icon = excluded.icon, criterion = excluded.criterion,
  goal = excluded.goal, gold_reward = excluded.gold_reward, sort_order = excluded.sort_order;

-- Conquistas liberadas em cada entrega (vão no resultado da tentativa).
alter table public.phase_attempts
  add column achievements jsonb;

-- ── 2. Progresso de cada conquista ───────────────────────────────────
-- Só o servidor: recebe um aluno qualquer.
create or replace function public.achievement_progress(p_user uuid)
returns table (achievement_id text, progress int, goal int, unlocked_at timestamptz)
language sql stable security definer set search_path = public as $$
  with perfect as (
    -- Questões DIFERENTES com nota cheia, por tipo (refazer não soma).
    select q.type::text as t, count(distinct x.question_id)::int as n
      from public.attempt_answers x
      join public.phase_attempts pa on pa.id = x.attempt_id
      join public.questions q       on q.id = x.question_id
     where pa.student_id = p_user and x.answered_at is not null and x.score >= 1
     group by q.type
  ),
  stats as (
    select
      coalesce((select floor(up.xp)::int from public.user_progress up
                 where up.user_id = p_user), 0) as xp,
      coalesce((select max(x.streak) from public.attempt_answers x
                  join public.phase_attempts pa on pa.id = x.attempt_id
                 where pa.student_id = p_user), 0) as streak,
      (select count(*)::int from public.classroom_results r
        where r.student_id = p_user and r.phase_id is not null and r.total_questions > 0
          and coalesce(r.best_pct,
                       round(r.correct_answers * 100.0 / r.total_questions, 2)) >= 100)
        as three_stars
  )
  select a.id,
         case a.criterion
           when 'xp'          then s.xp
           when 'streak'      then s.streak
           when 'three_stars' then s.three_stars
           else coalesce((select p.n from perfect p where p.t = case a.criterion
                            when 'match_perfect'       then 'match_columns'
                            when 'ordering_perfect'    then 'ordering'
                            when 'blanks_perfect'      then 'fill_blanks'
                            when 'crossword_perfect'   then 'crossword'
                            when 'word_search_perfect' then 'word_search'
                          end), 0)
         end,
         case a.criterion when 'xp' then a.xp_required::int else a.goal end,
         ua.unlocked_at
    from public.achievements a
    cross join stats s
    left join public.user_achievements ua
      on ua.user_id = p_user and ua.achievement_id = a.id;
$$;

-- Libera as conquistas por tipo que o aluno completou e credita as
-- moedas (uma vez só: a chave de user_achievements segura). Devolve as
-- novas: [{id, title, gold}].
create or replace function public.award_achievements(p_user uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r      record;
  v_new  jsonb := '[]'::jsonb;
  v_gold int := 0;
begin
  for r in
    select a.id, a.title, a.gold_reward
      from public.achievement_progress(p_user) p
      join public.achievements a on a.id = p.achievement_id
     where a.criterion <> 'xp' and p.unlocked_at is null and p.progress >= p.goal
     order by a.sort_order
  loop
    insert into public.user_achievements (user_id, achievement_id)
    values (p_user, r.id)
    on conflict do nothing;
    if found then
      v_gold := v_gold + r.gold_reward;
      v_new := v_new || jsonb_build_object('id', r.id, 'title', r.title, 'gold', r.gold_reward);
    end if;
  end loop;
  if v_gold > 0 then
    update public.user_progress set gold = gold + v_gold where user_id = p_user;
  end if;
  return v_new;
end;
$$;

-- ── 3. Entrega da tentativa libera as conquistas ─────────────────────
create or replace function public.attempt_result(p_attempt uuid)
returns jsonb language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'attempt_id',    a.id,
    'attempt_no',    a.attempt_no,
    'first_attempt', a.official,
    'total',         a.total,
    'score',         a.score,
    'pct',           a.pct,
    'stars',         public.phase_stars(a.pct),
    'points',        a.points,
    'best_streak',   a.best_streak,
    'xp',            a.xp_awarded,
    'gold',          a.gold_awarded,
    -- Conquistas liberadas nesta entrega (cada uma com as moedas dela).
    'achievements',  coalesce(a.achievements, '[]'::jsonb),
    'official', jsonb_build_object(
      'total',   r.total_questions,
      'correct', r.correct_answers,
      'pct',     o.pct
    ),
    'best_pct',   b.best,
    'best_stars', public.phase_stars(b.best),
    'review', coalesce((
      select jsonb_agg(jsonb_build_object(
               'question_id', q.id,
               'score',       coalesce(x.score, 0),
               'correct',     coalesce(x.score, 0) >= 1,
               'answered',    x.answered_at is not null,
               'timed_out',   coalesce(x.timed_out, false),
               'response',    x.response,
               'reveal',      public.question_reveal(q),
               'explanation', coalesce(q.explanation, '')
             ) order by t.ord)
        from unnest(a.question_ids) with ordinality as t(qid, ord)
        join public.questions q on q.id = t.qid
        left join public.attempt_answers x
          on x.attempt_id = a.id and x.question_id = q.id
    ), '[]'::jsonb)
  )
  from public.phase_attempts a
  left join public.classroom_results r
    on r.classroom_id = a.classroom_id and r.student_id = a.student_id
   and r.phase_id = a.phase_id
  cross join lateral (
    select case when r.total_questions > 0
                then round(r.correct_answers * 100.0 / r.total_questions, 2)
                else 100 end as pct
  ) o
  cross join lateral (select coalesce(r.best_pct, o.pct) as best) b
  where a.id = p_attempt and a.finished_at is not null;
$$;

create or replace function public.finalize_attempt(p_attempt uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_att         public.phase_attempts%rowtype;
  v_total       int;
  v_score       numeric;
  v_pct         numeric;
  v_points      int;
  v_best_streak int;
  v_first       boolean;
  v_old_best    numeric;
  v_new_best    numeric;
  v_xp          int := 0;
  v_gold        int := 0;
  v_title       text;
  v_name        text;
  v_new         jsonb;
begin
  select * into v_att from public.phase_attempts where id = p_attempt for update;
  if not found then
    return null;
  end if;
  if v_att.finished_at is not null then
    return public.attempt_result(p_attempt);
  end if;

  -- Questões apagadas no meio do caminho saem da conta; as que ficaram
  -- sem resposta valem 0.
  select count(*) into v_total
    from unnest(v_att.question_ids) as t(qid)
   where exists (select 1 from public.questions q where q.id = t.qid);

  select coalesce(sum(x.score), 0), coalesce(sum(x.points), 0), coalesce(max(x.streak), 0)
    into v_score, v_points, v_best_streak
    from public.attempt_answers x
   where x.attempt_id = p_attempt and x.answered_at is not null;

  v_pct := case when v_total > 0 then round(v_score * 100 / v_total, 2) else 100 end;

  with ins as (
    insert into public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers, best_pct)
    values (v_att.classroom_id, v_att.student_id, v_att.phase_id, v_total, v_score, v_pct)
    on conflict (classroom_id, student_id, phase_id) do nothing
    returning 1
  )
  select exists (select 1 from ins) into v_first;

  if v_first then
    v_xp   := 5 + round(v_points / 5.0)::int;
    v_gold := 5 * public.phase_stars(v_pct);

    select title into v_title from public.classroom_phases where id = v_att.phase_id;
    select display_name into v_name from public.profiles where id = v_att.student_id;
    insert into public.classroom_activities (classroom_id, type, description)
    values (v_att.classroom_id, 'student_completed',
      coalesce(v_name, 'Um aluno') || ' concluiu a fase "' || coalesce(v_title, '') || '"');
  else
    -- Refazer: as respostas só são aceitas com a fase aberta, então a
    -- melhor nota pode subir. Moedas só por estrela nova.
    select coalesce(best_pct,
                    case when total_questions > 0
                         then round(correct_answers * 100.0 / total_questions, 2)
                         else 100 end)
      into v_old_best
      from public.classroom_results
     where classroom_id = v_att.classroom_id and student_id = v_att.student_id
       and phase_id = v_att.phase_id
       for update;
    v_new_best := greatest(v_old_best, v_pct);
    update public.classroom_results
       set best_pct = v_new_best
     where classroom_id = v_att.classroom_id and student_id = v_att.student_id
       and phase_id = v_att.phase_id;
    v_gold := 5 * greatest(0, public.phase_stars(v_new_best) - public.phase_stars(v_old_best));
  end if;

  if v_xp > 0 or v_gold > 0 then
    update public.user_progress
       set xp    = xp + v_xp,
           gold  = gold + v_gold,
           level = greatest(level, public.level_for_xp(xp + v_xp))
     where user_id = v_att.student_id;
  end if;

  -- Conquistas por tipo que esta entrega completou (moedas creditadas
  -- dentro de award_achievements).
  v_new := public.award_achievements(v_att.student_id);

  update public.phase_attempts
     set achievements = v_new,
         finished_at  = now(),
         total        = v_total,
         score        = v_score,
         pct          = v_pct,
         points       = v_points,
         best_streak  = v_best_streak,
         official     = v_first,
         xp_awarded   = v_xp,
         gold_awarded = v_gold
   where id = p_attempt;

  return public.attempt_result(p_attempt);
end;
$$;

-- ── 4. Minhas conquistas (perfil) ────────────────────────────────────
-- Antes de ler, libera o que tentativas antigas já completaram (ex.: 100%
-- de antes desta versão). Devolve {achievements, gold_awarded}: com
-- moedas creditadas agora, o app relê o saldo.
create or replace function public.my_achievements()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_new jsonb;
begin
  if auth.uid() is null then
    return jsonb_build_object('achievements', '[]'::jsonb, 'gold_awarded', 0);
  end if;
  v_new := public.award_achievements(auth.uid());
  return jsonb_build_object(
    'gold_awarded', (select coalesce(sum((e ->> 'gold')::int), 0)
                       from jsonb_array_elements(v_new) e),
    'achievements', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id',          a.id,
               'title',       a.title,
               'description', a.description,
               'rarity',      a.rarity,
               'icon',        a.icon,
               'criterion',   a.criterion,
               'gold_reward', a.gold_reward,
               'progress',    p.progress,
               'goal',        p.goal,
               'unlocked',    (a.criterion = 'xp' and p.progress >= p.goal)
                              or p.unlocked_at is not null,
               'unlocked_at', p.unlocked_at
             ) order by a.sort_order, a.id), '[]'::jsonb)
        from public.achievements a
        join public.achievement_progress(auth.uid()) p on p.achievement_id = a.id));
end;
$$;

-- ── 5. Perfil do colega (pelo ranking da turma) ──────────────────────
-- Quem é da turma (aluno ou o professor dono) vê um aluno da turma.
-- NULL se não puder. Nada de e-mail, prontuário ou moedas.
create or replace function public.get_classmate_profile(p_classroom uuid, p_student uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'user_id',     p.id,
    'name',        coalesce(p.display_name, ''),
    'photo_url',   p.photo_url,
    'level',       coalesce(up.level, 1),
    'xp',          coalesce(floor(up.xp), 0),
    'phases_done', (select count(*) from public.classroom_results r
                     where r.classroom_id = p_classroom and r.student_id = p.id
                       and r.phase_id is not null),
    'stars',       coalesce((
                     select sum(public.phase_stars(coalesce(r.best_pct,
                              case when r.total_questions > 0
                                   then round(r.correct_answers * 100.0 / r.total_questions, 2)
                                   else 100 end)))
                       from public.classroom_results r
                      where r.classroom_id = p_classroom and r.student_id = p.id
                        and r.phase_id is not null and r.total_questions > 0), 0),
    'achievements', coalesce((
                     select jsonb_agg(jsonb_build_object(
                              'id', a.id, 'title', a.title, 'description', a.description,
                              'rarity', a.rarity, 'icon', a.icon) order by a.sort_order, a.id)
                       from public.achievements a
                       join public.achievement_progress(p.id) ap on ap.achievement_id = a.id
                      where (a.criterion = 'xp' and ap.progress >= ap.goal)
                         or ap.unlocked_at is not null), '[]'::jsonb),
    'achievements_total', (select count(*) from public.achievements)
  )
  from public.profiles p
  left join public.user_progress up on up.user_id = p.id
  where p.id = p_student
    and exists (select 1 from public.classroom_members m
                 where m.classroom_id = p_classroom and m.student_id = p_student)
    and (public.is_member(p_classroom) or public.owns_classroom(p_classroom));
$$;

-- ── 6. Privilégios (regra da migration 20261008120000) ──────────────
-- Recebem um aluno qualquer: só o servidor.
revoke all on function
  public.achievement_progress(uuid),
  public.award_achievements(uuid),
  public.attempt_result(uuid),
  public.finalize_attempt(uuid)
from public, anon, authenticated;
grant execute on function
  public.achievement_progress(uuid),
  public.award_achievements(uuid),
  public.attempt_result(uuid),
  public.finalize_attempt(uuid)
to service_role;

-- RPCs do app (conferem auth.uid() e a turma).
revoke all on function
  public.my_achievements(),
  public.get_classmate_profile(uuid, uuid)
from public, anon;
grant execute on function
  public.my_achievements(),
  public.get_classmate_profile(uuid, uuid)
to authenticated, service_role;
