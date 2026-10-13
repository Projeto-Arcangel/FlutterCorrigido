-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Estágio 2 · Planos, limites mensais e banco de questões            ║
-- ║                                                                    ║
-- ║  - plans: catálogo (Free, Pro, Premium) com os limites do mês.     ║
-- ║  - subscriptions: assinatura de cada professor. Escrita só pelo    ║
-- ║    servidor (webhook do Asaas ou admin_grant_plan, manual).        ║
-- ║  - Uso por período de um mês contado do início do plano (pago: de  ║
-- ║    quando o plano começou; Free: do cadastro ou do fim do último   ║
-- ║    plano pago): questões por tema, questões por materiais (mínimo  ║
-- ║    de 5 por geração), minutos de vídeo; e questões guardadas.      ║
-- ║  - plan_reserve/plan_release: reserva do uso ANTES de chamar a IA, ║
-- ║    sob trava por professor — pedidos simultâneos não passam do     ║
-- ║    limite. Reserva esquecida (função que caiu) expira em 5 min.    ║
-- ║  - Gatilho de armazenamento: barra só INSERÇÕES acima do limite;   ║
-- ║    nada é apagado quando o plano diminui.                          ║
-- ║  - copy_questions_to_phase: "Reutilizar minhas questões" (cópia).  ║
-- ║                                                                    ║
-- ║  A mudança de plano vale na hora: tudo é calculado na consulta.    ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 1. Catálogo de planos ────────────────────────────────────────────
create table public.plans (
  id                  text primary key,
  name                text not null,
  price_cents         int  not null check (price_cents >= 0),
  -- Limites do mês.
  topic_questions     int  not null check (topic_questions >= 0),
  material_questions  int  not null check (material_questions >= 0),
  video_minutes       int  not null check (video_minutes >= 0),
  -- Limite de questões guardadas (todas as turmas do professor).
  stored_questions    int  not null check (stored_questions >= 0),
  -- Cada geração com materiais conta no mínimo isto: o material inteiro é
  -- lido a cada geração, então gerar 1 questão custa quase o mesmo que 10.
  material_min_charge int  not null default 5 check (material_min_charge >= 1),
  -- Chaves de modelo (ALLOWED_MODELS em _shared/openrouter.ts).
  allowed_models      text[] not null,
  pdf_export          boolean not null default false,
  priority_support    boolean not null default false,
  sort_order          int not null unique
);

comment on table public.plans is
  'Planos e limites mensais. Lido pelo app; alterado só por migration.';

insert into public.plans
  (id, name, price_cents, topic_questions, material_questions, video_minutes,
   stored_questions, allowed_models, pdf_export, priority_support, sort_order)
values
  ('free',    'Free',       0,  50,  15,  30, 200,
   array['gemini-flash', 'claude-haiku'],             false, false, 0),
  ('pro',     'Pro',     1999, 300,  60, 180, 400,
   array['gemini-flash', 'gpt-mini', 'claude-haiku'], true,  false, 1),
  ('premium', 'Premium', 3999, 600, 120, 480, 600,
   array['gemini-flash', 'gpt-mini', 'claude-haiku'], true,  true,  2);

alter table public.plans enable row level security;
create policy plans_read on public.plans for select to authenticated using (true);
grant select on public.plans to authenticated;
grant all    on public.plans to service_role;

-- ── 2. Assinaturas ───────────────────────────────────────────────────
-- status: pending (aguardando o 1º pagamento) · active · past_due (pagamento
-- atrasado; segue valendo por PLAN_GRACE) · canceled (vale até
-- current_period_end, sem renovar).
create table public.subscriptions (
  id                       uuid primary key default gen_random_uuid(),
  teacher_id               uuid not null references public.profiles (id) on delete cascade,
  plan_id                  text not null references public.plans (id),
  -- Redução agendada: entra no lugar de plan_id na próxima renovação.
  next_plan_id             text references public.plans (id),
  status                   text not null
    check (status in ('pending', 'active', 'past_due', 'canceled')),
  provider                 text not null check (provider in ('asaas', 'manual')),
  billing_type             text check (billing_type in ('PIX', 'CREDIT_CARD')),
  provider_customer_id     text,
  provider_subscription_id text unique,
  -- Pago até aqui. NULL numa assinatura manual = sem data para acabar.
  current_period_end       timestamptz,
  -- Quando o plano começou a valer (pagamento confirmado ou liberação
  -- manual): os períodos de uso contam a partir daqui. NULL = nunca valeu
  -- (pedido não pago).
  started_at               timestamptz,
  -- Cobrança em aberto (1º pagamento ou mudança de plano), para o app
  -- reabrir a página de pagamento do Asaas.
  invoice_url              text,
  canceled_at              timestamptz,
  note                     text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- No máximo uma assinatura em vigor e uma aguardando o 1º pagamento por
-- professor (a pendente substitui a em vigor quando é paga; a cancelada
-- coexiste com uma nova enquanto o período pago não acaba).
create unique index subscriptions_one_live
  on public.subscriptions (teacher_id)
  where status in ('active', 'past_due');
create unique index subscriptions_one_pending
  on public.subscriptions (teacher_id)
  where status = 'pending';
create index subscriptions_teacher_idx on public.subscriptions (teacher_id, created_at desc);

create trigger subscriptions_set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

-- Só o servidor lê e escreve; o app vê a própria assinatura por my_plan().
alter table public.subscriptions enable row level security;
grant all on public.subscriptions to service_role;

-- Cliente no Asaas de cada professor (o CPF/CNPJ fica só no Asaas).
create table public.billing_customers (
  teacher_id           uuid primary key references public.profiles (id) on delete cascade,
  provider             text not null default 'asaas' check (provider in ('asaas')),
  provider_customer_id text not null unique,
  created_at           timestamptz not null default now()
);
alter table public.billing_customers enable row level security;
grant all on public.billing_customers to service_role;

-- Eventos recebidos do Asaas: o id garante que cada um seja aplicado uma
-- vez só (o Asaas reenvia até receber 200).
create table public.billing_events (
  id           text primary key,
  event        text not null,
  payload      jsonb not null,
  processed_at timestamptz,
  error        text,
  received_at  timestamptz not null default now()
);
alter table public.billing_events enable row level security;
grant all on public.billing_events to service_role;

-- ── 3. Plano em vigor e período de uso ──────────────────────────────
-- Assinatura em vigor (a do maior plano, se houver duas). Pagamento
-- atrasado (past_due) mantém o plano por 3 dias além do período pago
-- (PLAN_GRACE), tempo de o Pix/cartão compensar; cancelada vale até o fim
-- do período pago. NULL = Free.
create or replace function public.effective_subscription(p_teacher uuid)
returns public.subscriptions
language sql stable security definer set search_path = public as $$
  select s.*
    from public.subscriptions s
    join public.plans p on p.id = s.plan_id
   where s.teacher_id = p_teacher
     and s.started_at is not null
     and (
       (s.status in ('active', 'past_due')
         and (s.current_period_end is null
              or s.current_period_end + interval '3 days' > now()))
       or (s.status = 'canceled' and s.current_period_end > now())
     )
   order by p.sort_order desc, s.started_at desc
   limit 1;
$$;

create or replace function public.effective_plan_id(p_teacher uuid)
returns text
language sql stable security definer set search_path = public as $$
  select coalesce((public.effective_subscription(p_teacher)).plan_id, 'free');
$$;

-- De onde contam os períodos de uso: do início do plano em vigor; no Free,
-- do cadastro ou do fim do último plano que chegou a valer (o que for mais
-- recente) — o uso feito no plano pago não pesa no Free. Pedido não pago
-- (started_at nulo) não mexe em nada.
create or replace function public.plan_anchor(p_teacher uuid)
returns timestamptz
language sql stable security definer set search_path = public as $$
  select coalesce(
    (public.effective_subscription(p_teacher)).started_at,
    greatest(
      (select pr.created_at from public.profiles pr where pr.id = p_teacher),
      (select max(s.current_period_end)
         from public.subscriptions s
        where s.teacher_id = p_teacher and s.started_at is not null
          and s.current_period_end <= now())
    ),
    now()
  );
$$;

-- Período de um mês que contém [p_now], contado de [p_anchor] (mesmo dia e
-- hora a cada mês, no fuso de SP; dia 31 vira o último dia dos meses
-- menores: 31/01 → 28/02 → 31/03).
create or replace function public.plan_cycle(p_anchor timestamptz, p_now timestamptz)
returns table (period_start timestamptz, period_end timestamptz)
language plpgsql stable set search_path = '' as $$
declare
  v_anchor timestamp := p_anchor at time zone 'America/Sao_Paulo';
  v_now    timestamp := p_now    at time zone 'America/Sao_Paulo';
  v_age    interval;
  v_n      int;
begin
  if v_anchor > v_now then
    v_anchor := v_now;
  end if;
  v_age := age(v_now, v_anchor);
  v_n := (extract(year from v_age) * 12 + extract(month from v_age))::int;
  if v_anchor + make_interval(months => v_n) > v_now then
    v_n := v_n - 1;
  end if;
  if v_anchor + make_interval(months => v_n + 1) <= v_now then
    v_n := v_n + 1;
  end if;
  period_start := (v_anchor + make_interval(months => v_n)) at time zone 'America/Sao_Paulo';
  period_end   := (v_anchor + make_interval(months => v_n + 1)) at time zone 'America/Sao_Paulo';
  return next;
end;
$$;

-- Período atual do professor.
create or replace function public.plan_period(p_teacher uuid)
returns table (period_start timestamptz, period_end timestamptz)
language sql stable security definer set search_path = public as $$
  select c.period_start, c.period_end
    from public.plan_cycle(public.plan_anchor(p_teacher), now()) c;
$$;

-- ── 4. Uso do período ────────────────────────────────────────────────
-- Conta só o que deu certo. Materiais: cada geração vale no mínimo
-- material_min_charge. Vídeo: minutos lidos de cada vídeo, arredondados
-- para cima (inclui leitura parcial: os trechos lidos foram cobrados).
create or replace function public.plan_used(p_teacher uuid, p_resource text)
returns int
language plpgsql stable security definer set search_path = public as $$
declare
  v_start timestamptz := (select period_start from public.plan_period(p_teacher));
  v_min   int;
  v_used  int;
begin
  case p_resource
    when 'topic' then
      select coalesce(sum(coalesce(l.quantity, 0)), 0) into v_used
        from public.ai_generation_logs l
       where l.teacher_id = p_teacher and l.status = 'success'
         and l.source = 'topic' and l.created_at >= v_start;
    when 'materials' then
      select p.material_min_charge into v_min
        from public.plans p where p.id = public.effective_plan_id(p_teacher);
      select coalesce(sum(greatest(coalesce(l.quantity, 0), v_min)), 0) into v_used
        from public.ai_generation_logs l
       where l.teacher_id = p_teacher and l.status = 'success'
         and l.source = 'materials' and l.created_at >= v_start;
    when 'video_minutes' then
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

-- ── 5. Reserva de uso (Edge Functions) ───────────────────────────────
-- A Edge Function reserva o uso antes de chamar a IA e libera a reserva
-- depois de registrar o resultado. A trava por professor faz pedidos
-- simultâneos entrarem em fila: um não "vê" o limite livre do outro.
create table public.plan_usage_holds (
  id         uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles (id) on delete cascade,
  resource   text not null check (resource in ('topic', 'materials', 'video_minutes')),
  amount     int  not null check (amount > 0),
  created_at timestamptz not null default now()
);
create index plan_usage_holds_teacher_idx on public.plan_usage_holds (teacher_id);
alter table public.plan_usage_holds enable row level security;
grant all on public.plan_usage_holds to service_role;

-- p_amount: questões pedidas (topic/materials) ou minutos (video_minutes).
-- p_model: chave do modelo pedido (só topic/materials); fora do plano = recusa.
-- Devolve { ok, reason?, hold?, plan, plan_name, allowed_models?, limit, used,
-- remaining, charge, min_charge?, period_end (quando o uso renova) }.
create or replace function public.plan_reserve(
  p_teacher  uuid,
  p_resource text,
  p_amount   int,
  p_model    text default null
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_plan   public.plans;
  v_limit  int;
  v_used   int;
  v_charge int;
  v_hold   uuid;
  v_renew  timestamptz;
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
  v_charge := case p_resource
    when 'materials' then greatest(p_amount, v_plan.material_min_charge)
    else p_amount
  end;
  v_used := public.plan_used(p_teacher, p_resource)
    + (select coalesce(sum(h.amount), 0)::int
         from public.plan_usage_holds h
        where h.teacher_id = p_teacher and h.resource = p_resource);

  if v_used + v_charge > v_limit then
    return jsonb_build_object(
      'ok', false, 'reason', 'limit',
      'plan', v_plan.id, 'plan_name', v_plan.name,
      'limit', v_limit, 'used', v_used, 'charge', v_charge,
      'min_charge', v_plan.material_min_charge, 'period_end', v_renew,
      'remaining', greatest(0, v_limit - v_used));
  end if;

  insert into public.plan_usage_holds (teacher_id, resource, amount)
  values (p_teacher, p_resource, v_charge)
  returning id into v_hold;

  -- allowed_models: o fallback da geração também fica dentro do plano.
  return jsonb_build_object(
    'ok', true, 'hold', v_hold,
    'plan', v_plan.id, 'plan_name', v_plan.name,
    'allowed_models', to_jsonb(v_plan.allowed_models),
    'limit', v_limit, 'used', v_used, 'charge', v_charge, 'period_end', v_renew,
    'remaining', v_limit - v_used - v_charge);
end;
$$;

create or replace function public.plan_release(p_hold uuid)
returns void
language sql security definer set search_path = public as $$
  delete from public.plan_usage_holds where id = p_hold;
$$;

-- ── 6. Plano do professor logado (app) ───────────────────────────────
create or replace function public.my_plan()
returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'plan', to_jsonb(p),
    'usage', jsonb_build_object(
      'topic',         public.plan_used(auth.uid(), 'topic'),
      'materials',     public.plan_used(auth.uid(), 'materials'),
      'video_minutes', public.plan_used(auth.uid(), 'video_minutes'),
      'stored',        public.plan_used(auth.uid(), 'stored')
    ),
    -- Assinatura em vigor (ou cancelada que ainda vale até o fim do período).
    'subscription', (
      select jsonb_build_object(
        'plan_id',            s.plan_id,
        'next_plan_id',       s.next_plan_id,
        'status',             s.status,
        'provider',           s.provider,
        'billing_type',       s.billing_type,
        'current_period_end', s.current_period_end,
        'canceled_at',        s.canceled_at,
        'invoice_url',        s.invoice_url)
        from public.subscriptions s
       where s.teacher_id = auth.uid()
         and (s.status in ('active', 'past_due')
              or (s.status = 'canceled' and s.current_period_end > now()))
       order by (s.status in ('active', 'past_due')) desc, s.created_at desc
       limit 1
    ),
    -- Assinatura aguardando o 1º pagamento.
    'pending', (
      select jsonb_build_object(
        'plan_id',      s.plan_id,
        'status',       s.status,
        'provider',     s.provider,
        'billing_type', s.billing_type,
        'invoice_url',  s.invoice_url,
        'created_at',   s.created_at)
        from public.subscriptions s
       where s.teacher_id = auth.uid() and s.status = 'pending'
       limit 1
    ),
    'period_start', per.period_start,
    'period_end',   per.period_end
  )
  from public.plans p, public.plan_period(auth.uid()) per
  where p.id = public.effective_plan_id(auth.uid());
$$;

-- ── 7. Limite de questões guardadas ──────────────────────────────────
-- Gatilho por COMANDO (um por insert, com todas as linhas novas): a
-- contagem roda uma vez por professor afetado, não uma vez por questão.
-- A trava por professor serializa inserções simultâneas; a contagem, feita
-- depois dela, já enxerga o que a outra transação gravou.
create or replace function public.enforce_stored_questions()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r       record;
  v_plan  public.plans;
  v_total int;
begin
  for r in
    select c.teacher_id, count(*)::int as added
      from new_rows q
      join public.classroom_phases ph on ph.id = q.phase_id
      join public.classrooms c        on c.id = ph.classroom_id
     group by c.teacher_id
     order by c.teacher_id
  loop
    perform pg_advisory_xact_lock(hashtextextended('plan_storage:' || r.teacher_id::text, 0));
    select * into v_plan from public.plans where id = public.effective_plan_id(r.teacher_id);
    v_total := public.plan_used(r.teacher_id, 'stored');
    if v_total > v_plan.stored_questions then
      -- PT402: o PostgREST responde HTTP 402 com este código; o app mostra
      -- a mensagem e a dica.
      raise exception using
        errcode = 'PT402',
        message = format(
          'Seu plano %s guarda até %s questões e você já tem %s. %s',
          v_plan.name, v_plan.stored_questions, v_total - r.added,
          case when r.added = 1 then 'Esta questão não cabe.'
               else format('Estas %s questões não cabem.', r.added) end),
        detail = format('stored_limit:%s:%s:%s',
          v_plan.stored_questions, v_total - r.added, r.added),
        hint = 'Apague questões que você não usa mais ou mude de plano.';
    end if;
  end loop;
  return null;
end;
$$;

create trigger questions_enforce_storage
  after insert on public.questions
  referencing new table as new_rows
  for each statement execute function public.enforce_stored_questions();

-- ── 8. Reutilizar minhas questões (cópia) ────────────────────────────
-- Copia questões de qualquer turma do professor para o fim de uma fase.
-- Cópia, não vínculo: editar uma não muda a outra. As cópias contam no
-- limite de armazenamento (o gatilho acima barra o excesso e nada é
-- copiado). Devolve quantas questões foram copiadas.
create or replace function public.copy_questions_to_phase(p_phase uuid, p_question_ids uuid[])
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_classroom uuid;
  v_next      int;
  v_count     int;
begin
  -- Trava a fase: duas cópias ao mesmo tempo não repetem posições.
  select ph.classroom_id into v_classroom
    from public.classroom_phases ph
   where ph.id = p_phase
     for update;
  if v_classroom is null or not public.owns_classroom(v_classroom) then
    raise exception 'Apenas o professor da turma pode adicionar questões a esta fase.'
      using errcode = '42501';
  end if;

  if p_question_ids is null or cardinality(p_question_ids) = 0 then
    raise exception 'Escolha ao menos uma questão.' using errcode = '22023';
  end if;
  if cardinality(p_question_ids) > 100 then
    raise exception 'Copie no máximo 100 questões por vez.' using errcode = '22023';
  end if;

  if exists (
    select 1 from unnest(p_question_ids) x
     where not exists (
       select 1
         from public.questions q
         join public.classroom_phases ph on ph.id = q.phase_id
         join public.classrooms c        on c.id = ph.classroom_id
        where q.id = x and c.teacher_id = auth.uid()))
  then
    raise exception 'Alguma das questões escolhidas não existe mais. Recarregue a lista e tente de novo.'
      using errcode = '22023';
  end if;

  select coalesce(max(q.sort_order), 0) into v_next
    from public.questions q where q.phase_id = p_phase;

  insert into public.questions
    (phase_id, text, options, correct_answer, explanation, type,
     image_url, image_author, image_source, ai_generated, sort_order)
  select p_phase, q.text, q.options, q.correct_answer, q.explanation, q.type,
         q.image_url, q.image_author, q.image_source, q.ai_generated,
         v_next + row_number() over (order by o.pos)
    from (select x, min(pos) as pos
            from unnest(p_question_ids) with ordinality as u(x, pos)
           group by x) o
    join public.questions q on q.id = o.x;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ── 9. Plano manual (enquanto o Asaas não está ligado) ───────────────
-- Uso no SQL Editor do Supabase, depois de receber o pedido por e-mail:
--   select public.admin_grant_plan('prof@escola.com', 'pro', 1);
--   select public.admin_grant_plan('prof@escola.com', 'free');  -- encerra
-- Vale na hora. Encerra a assinatura manual anterior; assinatura do Asaas
-- precisa ser cancelada por lá.
create or replace function public.admin_grant_plan(
  p_email  text,
  p_plan   text,
  p_months int  default 1,
  p_note   text default null
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_teacher uuid;
  v_sub     public.subscriptions;
  v_started timestamptz;
begin
  select id into v_teacher
    from public.profiles
   where lower(email) = lower(trim(p_email)) and role in ('teacher', 'admin');
  if v_teacher is null then
    raise exception 'Professor não encontrado: %', p_email;
  end if;
  if not exists (select 1 from public.plans where id = p_plan) then
    raise exception 'Plano desconhecido: %', p_plan;
  end if;
  if p_months is null or p_months < 1 or p_months > 24 then
    raise exception 'Meses deve ficar entre 1 e 24.';
  end if;
  if exists (
    select 1 from public.subscriptions
     where teacher_id = v_teacher and provider = 'asaas'
       and status in ('pending', 'active', 'past_due'))
  then
    raise exception 'Este professor tem assinatura no Asaas: cancele por lá antes.';
  end if;

  -- Prorrogar o mesmo plano mantém o período de uso; plano novo começa
  -- um período novo (como numa compra).
  select s.started_at into v_started
    from public.subscriptions s
   where s.id = (public.effective_subscription(v_teacher)).id
     and s.provider = 'manual' and s.plan_id = p_plan;

  update public.subscriptions
     set status = 'canceled', canceled_at = now(), current_period_end = now()
   where teacher_id = v_teacher and provider = 'manual'
     and (status in ('pending', 'active', 'past_due')
          or (status = 'canceled' and current_period_end > now()));

  if p_plan = 'free' then
    return jsonb_build_object('teacher_id', v_teacher, 'plan', 'free');
  end if;

  insert into public.subscriptions
    (teacher_id, plan_id, status, provider, current_period_end, started_at, note)
  values
    (v_teacher, p_plan, 'active', 'manual',
     now() + make_interval(months => p_months), coalesce(v_started, now()), p_note)
  returning * into v_sub;
  return to_jsonb(v_sub);
end;
$$;

-- ── 10. Cobrança (Asaas) — mudanças de estado atômicas ──────────────
-- Chamadas só pelas Edge Functions billing-* (service_role). O pagamento
-- pelo app fica desligado até a conta do Asaas existir (sem ASAAS_API_KEY
-- as funções respondem "em breve").

-- Pagamento confirmado de uma assinatura: ativa (1º pagamento) ou renova.
-- O período pago vai até o fim do dia do vencimento seguinte (fuso de SP).
-- No 1º pagamento, as outras assinaturas do professor (ex.: plano manual)
-- são encerradas; as do Asaas voltam na resposta para o webhook cancelar
-- lá. Na renovação, uma redução agendada (next_plan_id) entra em vigor.
create or replace function public.billing_payment_confirmed(
  p_provider_subscription text,
  p_due_date              date
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_sub        public.subscriptions;
  v_end        timestamptz;
  v_superseded text[] := '{}';
begin
  select * into v_sub from public.subscriptions
   where provider_subscription_id = p_provider_subscription
     for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'unknown_subscription');
  end if;
  if v_sub.status = 'canceled' then
    -- Cobrança paga de assinatura já encerrada: a equipe decide (estorno).
    return jsonb_build_object('ok', false, 'reason', 'canceled', 'teacher_id', v_sub.teacher_id);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('billing:' || v_sub.teacher_id::text, 0));
  v_end := ((p_due_date + interval '1 month')::date + 1)::timestamp
             at time zone 'America/Sao_Paulo';

  if v_sub.status = 'pending' then
    select coalesce(array_agg(o.provider_subscription_id)
             filter (where o.provider = 'asaas' and o.provider_subscription_id is not null), '{}')
      into v_superseded
      from public.subscriptions o
     where o.teacher_id = v_sub.teacher_id and o.id <> v_sub.id
       and o.status in ('active', 'past_due');
    update public.subscriptions
       set status = 'canceled', canceled_at = now(),
           current_period_end = least(coalesce(current_period_end, now()), now())
     where teacher_id = v_sub.teacher_id and id <> v_sub.id
       and status in ('active', 'past_due');
  end if;

  update public.subscriptions
     set status = 'active',
         -- 1º pagamento: o plano começa a valer e os períodos contam daqui.
         started_at = coalesce(started_at, now()),
         plan_id = case when v_sub.status <> 'pending' and next_plan_id is not null
                        then next_plan_id else plan_id end,
         next_plan_id = case when v_sub.status <> 'pending' then null else next_plan_id end,
         current_period_end = greatest(coalesce(current_period_end, v_end), v_end),
         invoice_url = null
   where id = v_sub.id
  returning * into v_sub;

  return jsonb_build_object(
    'ok', true, 'teacher_id', v_sub.teacher_id, 'plan_id', v_sub.plan_id,
    'current_period_end', v_sub.current_period_end,
    'superseded', to_jsonb(v_superseded));
end;
$$;

-- Diferença paga para subir de plano no meio do período: o plano novo vale
-- na hora (o período pago continua o mesmo).
create or replace function public.billing_upgrade_paid(p_subscription uuid, p_plan text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_sub public.subscriptions;
begin
  update public.subscriptions
     set plan_id = p_plan, next_plan_id = null, invoice_url = null
   where id = p_subscription and status in ('active', 'past_due')
     and exists (select 1 from public.plans where id = p_plan)
  returning * into v_sub;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'not_active');
  end if;
  return jsonb_build_object(
    'ok', true, 'teacher_id', v_sub.teacher_id,
    'provider_subscription_id', v_sub.provider_subscription_id,
    'price_cents', (select price_cents from public.plans where id = p_plan));
end;
$$;

-- Pagamento vencido: segue valendo por 3 dias além do período pago.
create or replace function public.billing_payment_overdue(p_provider_subscription text)
returns void
language sql security definer set search_path = public as $$
  update public.subscriptions set status = 'past_due'
   where provider_subscription_id = p_provider_subscription and status = 'active';
$$;

-- Assinatura encerrada no Asaas. p_revoke (estorno/chargeback): perde o
-- plano na hora; senão vale até o fim do período pago.
create or replace function public.billing_subscription_ended(
  p_provider_subscription text,
  p_revoke                boolean default false
)
returns void
language sql security definer set search_path = public as $$
  update public.subscriptions
     set status = 'canceled',
         canceled_at = coalesce(canceled_at, now()),
         current_period_end = case when p_revoke or status = 'pending' then now()
                                   else current_period_end end,
         invoice_url = null
   where provider_subscription_id = p_provider_subscription
     and (status <> 'canceled' or p_revoke);
$$;

-- ── 11. Privilégios (regra da migration 20261008120000) ──────────────
revoke all on function public.effective_subscription(uuid)             from public, anon, authenticated;
revoke all on function public.effective_plan_id(uuid)                  from public, anon, authenticated;
revoke all on function public.plan_anchor(uuid)                        from public, anon, authenticated;
revoke all on function public.plan_cycle(timestamptz, timestamptz)     from public, anon, authenticated;
revoke all on function public.plan_period(uuid)                        from public, anon, authenticated;
revoke all on function public.plan_used(uuid, text)                    from public, anon, authenticated;
revoke all on function public.plan_reserve(uuid, text, int, text)      from public, anon, authenticated;
revoke all on function public.plan_release(uuid)                       from public, anon, authenticated;
revoke all on function public.my_plan()                                from public, anon, authenticated;
revoke all on function public.enforce_stored_questions()               from public, anon, authenticated;
revoke all on function public.copy_questions_to_phase(uuid, uuid[])    from public, anon, authenticated;
revoke all on function public.admin_grant_plan(text, text, int, text)  from public, anon, authenticated;
revoke all on function public.billing_payment_confirmed(text, date)    from public, anon, authenticated;
revoke all on function public.billing_upgrade_paid(uuid, text)         from public, anon, authenticated;
revoke all on function public.billing_payment_overdue(text)            from public, anon, authenticated;
revoke all on function public.billing_subscription_ended(text, boolean) from public, anon, authenticated;

-- Servidor (Edge Functions).
grant execute on function
  public.effective_subscription(uuid),
  public.effective_plan_id(uuid),
  public.plan_anchor(uuid),
  public.plan_cycle(timestamptz, timestamptz),
  public.plan_period(uuid),
  public.plan_used(uuid, text),
  public.plan_reserve(uuid, text, int, text),
  public.plan_release(uuid),
  public.my_plan(),
  public.copy_questions_to_phase(uuid, uuid[]),
  public.admin_grant_plan(text, text, int, text),
  public.billing_payment_confirmed(text, date),
  public.billing_upgrade_paid(uuid, text),
  public.billing_payment_overdue(text),
  public.billing_subscription_ended(text, boolean)
to service_role;

-- App: só o próprio plano/uso e a cópia de questões (as duas usam
-- auth.uid() — ninguém consulta outro professor).
grant execute on function public.my_plan()                             to authenticated;
grant execute on function public.copy_questions_to_phase(uuid, uuid[]) to authenticated;

-- A cota diária antiga (my_ai_quota, ai_questions_today, videos_read_today)
-- fica até a nova versão do app estar no ar; sai numa migration seguinte.
