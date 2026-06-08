-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ handle_new_user também grava o prontuário (student_id) do metadata  ║
-- ║                                                                    ║
-- ║  Com a confirmação de e-mail LIGADA, não existe sessão logo após o  ║
-- ║  signUp — então o cliente não consegue escrever o prontuário em     ║
-- ║  profiles (a RLS exige auth.uid()). A solução: o cadastro envia o   ║
-- ║  student_id no metadata do signUp e este trigger (SECURITY DEFINER) ║
-- ║  grava no profiles já na criação da conta.                          ║
-- ║                                                                    ║
-- ║  É um INSERT, então a trava profiles_lock_student_id (BEFORE UPDATE)║
-- ║  não interfere; o prontuário fica travado para alterações futuras.  ║
-- ╚══════════════════════════════════════════════════════════════════╝

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
    -- role propositalmente NULL quando não vem no metadata: o app força a
    -- RoleSelectionPage e grava via RPC set_role.
    (new.raw_user_meta_data ->> 'role')::public.user_role,
    -- prontuário (opcional); string vazia vira NULL.
    nullif(new.raw_user_meta_data ->> 'student_id', '')
  );
  insert into public.user_progress (user_id) values (new.id);
  return new;
end;
$$;