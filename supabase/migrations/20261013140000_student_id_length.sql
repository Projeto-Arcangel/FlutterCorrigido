-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Prontuário sem formato fixo, sempre em maiúsculas                   ║
-- ║                                                                    ║
-- ║  O app deixou de exigir o formato do IFSP (PT + 7 dígitos): o      ║
-- ║  campo agora é a identificação institucional de qualquer escola.   ║
-- ║  O banco nunca validou o formato. Aqui ele passa a garantir o que  ║
-- ║  o app já faz, porque o prontuário do cadastro chega pelo metadata ║
-- ║  do signUp (gravado pelo handle_new_user) e não passa pelo app:    ║
-- ║   - sempre em maiúsculas, sem espaços nas pontas nem repetidos;    ║
-- ║   - até 40 caracteres (o app limita a 30).                         ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- Normaliza antes de gravar. O nome do gatilho ("clean") vem antes de
-- "lock" na ordem alfabética: a trava do prontuário (profiles_lock_student_id)
-- compara o valor JÁ normalizado — reenviar o mesmo prontuário em minúsculas
-- não conta como troca.
create or replace function public.clean_student_id()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.student_id := nullif(
    upper(regexp_replace(btrim(new.student_id), '\s+', ' ', 'g')),
    ''
  );
  return new;
end;
$$;

-- Função de gatilho: dispara sem precisar de EXECUTE.
revoke all on function public.clean_student_id() from public, anon, authenticated;

create trigger profiles_clean_student_id
  before insert or update of student_id on public.profiles
  for each row execute function public.clean_student_id();

alter table public.profiles
  add constraint profiles_student_id_length
    check (student_id is null or char_length(student_id) <= 40),
  add constraint profiles_student_id_upper
    check (student_id is null or student_id = upper(student_id));
