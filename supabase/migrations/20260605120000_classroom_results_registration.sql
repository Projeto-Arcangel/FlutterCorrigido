-- get_classroom_results agora também devolve o prontuário do aluno
-- (profiles.student_id), usado na exportação de notas do professor.
-- Continua SECURITY DEFINER: o professor não lê profiles de alunos via RLS,
-- então o prontuário precisa vir por aqui.

create or replace function public.get_classroom_results(p_classroom uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'student_id',      r.student_id,
    'student_name',    coalesce(p.display_name, ''),
    'registration',    coalesce(p.student_id, ''),
    'total_questions', r.total_questions,
    'correct_answers', r.correct_answers,
    'completed_at',    r.completed_at
  )), '[]'::jsonb)
  from public.classroom_results r
  left join public.profiles p on p.id = r.student_id
  where r.classroom_id = p_classroom
    and (public.owns_classroom(p_classroom) or public.is_member(p_classroom));
$$;
