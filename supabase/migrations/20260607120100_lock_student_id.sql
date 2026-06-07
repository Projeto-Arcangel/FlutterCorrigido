-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Trava do prontuário (profiles.student_id) após o 1º preenchimento  ║
-- ║                                                                    ║
-- ║  Uma vez gravado um prontuário não-vazio, o próprio aluno não pode  ║
-- ║  mais alterá-lo nem apagá-lo. Evita spoofing de identidade na       ║
-- ║  caderneta (trocar o prontuário para se passar por outro aluno).    ║
-- ║                                                                    ║
-- ║  Espelha o trigger prevent_role_escalation (lock de role): a RLS    ║
-- ║  WITH CHECK não enxerga o valor ANTIGO, então a trava precisa ser   ║
-- ║  um trigger BEFORE UPDATE que compara OLD x NEW.                    ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.lock_student_id()
returns trigger
language plpgsql
as $$
begin
  -- Chamadas do servidor (service_role / SQL admin) não têm auth.uid():
  -- permitimos correção legítima de prontuário fora do app.
  if auth.uid() is null then
    return new;
  end if;

  -- Já existe um prontuário gravado e a atualização tenta trocá-lo (ou
  -- apagá-lo): bloqueia. Reenviar o MESMO valor é permitido (idempotente),
  -- então editar só o nome continua funcionando.
  if old.student_id is not null
     and btrim(old.student_id) <> ''
     and new.student_id is distinct from old.student_id then
    raise exception 'O prontuário já foi definido e não pode ser alterado.'
      using errcode = '42501';   -- insufficient_privilege
  end if;

  return new;
end;
$$;

create trigger profiles_lock_student_id
  before update on public.profiles
  for each row execute function public.lock_student_id();