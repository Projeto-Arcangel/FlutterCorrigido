-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Gerações com materiais contam exatamente as questões pedidas        ║
-- ║                                                                    ║
-- ║  Antes cada geração com materiais contava no mínimo 5 questões     ║
-- ║  (material_min_charge). O controle passa a ser só o limite de      ║
-- ║  questões com materiais de cada plano: pedir 2 conta 2.            ║
-- ║  plan_used e plan_reserve deixam de aplicar o mínimo, e a coluna   ║
-- ║  sai da tabela de planos. Vale também para o uso já feito no       ║
-- ║  período atual (a conta é feita na consulta).                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

create or replace function public.plan_used(p_teacher uuid, p_resource text)
returns int
language plpgsql stable security definer set search_path = public as $$
declare
  v_start timestamptz := (select period_start from public.plan_period(p_teacher));
  v_used  int;
begin
  case p_resource
    when 'topic', 'materials' then
      select coalesce(sum(coalesce(l.quantity, 0)), 0) into v_used
        from public.ai_generation_logs l
       where l.teacher_id = p_teacher and l.status = 'success'
         and l.source = p_resource and l.created_at >= v_start;
    when 'video_minutes' then
      -- Minutos lidos de cada vídeo, arredondados para cima (inclui leitura
      -- parcial: os trechos lidos foram cobrados).
      select coalesce(sum(ceil(e.seconds / 60.0)), 0) into v_used
        from public.material_extractions e
       where e.teacher_id = p_teacher and e.kind = 'video'
         and e.status in ('success', 'partial') and e.seconds > 0
         and e.created_at >= v_start;
    when 'stored' then
      select count(*) into v_used
        from public.questions q
        join public.classroom_phases ph on ph.id = q.phase_id
        join public.classrooms c        on c.id = ph.classroom_id
       where c.teacher_id = p_teacher;
    else
      raise exception 'Recurso de plano desconhecido: %', p_resource
        using errcode = '22023';
  end case;
  return v_used;
end;
$$;

-- p_amount: questões pedidas (topic/materials) ou minutos (video_minutes).
-- p_model: chave do modelo pedido (só topic/materials); fora do plano = recusa.
-- Devolve { ok, reason?, hold?, plan, plan_name, allowed_models?, limit, used,
-- remaining, period_end (quando o uso renova) }.
create or replace function public.plan_reserve(
  p_teacher  uuid,
  p_resource text,
  p_amount   int,
  p_model    text default null
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_plan  public.plans;
  v_limit int;
  v_used  int;
  v_hold  uuid;
  v_renew timestamptz;
begin
  if p_resource not in ('topic', 'materials', 'video_minutes')
     or p_amount is null or p_amount < 1 then
    raise exception 'Reserva inválida.' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('plan_usage:' || p_teacher::text, 0));

  select * into v_plan from public.plans where id = public.effective_plan_id(p_teacher);
  v_renew := (select period_end from public.plan_period(p_teacher));

  if p_model is not null and not (p_model = any (v_plan.allowed_models)) then
    return jsonb_build_object(
      'ok', false, 'reason', 'model',
      'plan', v_plan.id, 'plan_name', v_plan.name, 'period_end', v_renew);
  end if;

  -- Reservas de funções que caíram sem liberar (tempo máximo de uma Edge
  -- Function: 150 s).
  delete from public.plan_usage_holds
   where teacher_id = p_teacher and created_at < now() - interval '5 minutes';

  v_limit := case p_resource
    when 'topic'     then v_plan.topic_questions
    when 'materials' then v_plan.material_questions
    else v_plan.video_minutes
  end;
  v_used := public.plan_used(p_teacher, p_resource)
    + (select coalesce(sum(h.amount), 0)::int
         from public.plan_usage_holds h
        where h.teacher_id = p_teacher and h.resource = p_resource);

  if v_used + p_amount > v_limit then
    return jsonb_build_object(
      'ok', false, 'reason', 'limit',
      'plan', v_plan.id, 'plan_name', v_plan.name,
      'limit', v_limit, 'used', v_used, 'period_end', v_renew,
      'remaining', greatest(0, v_limit - v_used));
  end if;

  insert into public.plan_usage_holds (teacher_id, resource, amount)
  values (p_teacher, p_resource, p_amount)
  returning id into v_hold;

  -- allowed_models: o fallback da geração também fica dentro do plano.
  return jsonb_build_object(
    'ok', true, 'hold', v_hold,
    'plan', v_plan.id, 'plan_name', v_plan.name,
    'allowed_models', to_jsonb(v_plan.allowed_models),
    'limit', v_limit, 'used', v_used, 'period_end', v_renew,
    'remaining', v_limit - v_used - p_amount);
end;
$$;

alter table public.plans drop column material_min_charge;

-- create or replace mantém os privilégios; reafirmados aqui pela regra da
-- migration 20261008120000 (só o servidor reserva e consulta o uso).
revoke all on function public.plan_used(uuid, text)               from public, anon, authenticated;
revoke all on function public.plan_reserve(uuid, text, int, text) from public, anon, authenticated;
grant execute on function public.plan_used(uuid, text)               to service_role;
grant execute on function public.plan_reserve(uuid, text, int, text) to service_role;
