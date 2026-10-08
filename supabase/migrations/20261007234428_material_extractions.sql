-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Leituras de materiais feitas por IA no servidor (vídeos)           ║
-- ║                                                                    ║
-- ║  A leitura de um vídeo do YouTube (Edge Function extract-video)     ║
-- ║  custa tokens do Gemini: cada leitura fica registrada aqui para o   ║
-- ║  teto diário por professor e, no Estágio 2, para os limites dos     ║
-- ║  planos. Só METADADOS — as anotações voltam para o app e não são    ║
-- ║  guardadas.                                                         ║
-- ╚══════════════════════════════════════════════════════════════════╝

create table public.material_extractions (
  id            uuid primary key default gen_random_uuid(),
  teacher_id    uuid not null references public.profiles (id) on delete cascade,
  kind          text not null
    constraint material_extractions_kind_check check (kind in ('video')),
  source        text not null,               -- endereço canônico do vídeo
  title         text,
  seconds       int,                         -- segundos lidos (trechos que responderam)
  model         text,                        -- modelos que responderam (vírgula)
  input_tokens  int,
  output_tokens int,
  status        public.ai_generation_status not null,
  error_message text,
  created_at    timestamptz not null default now()
);

create index material_extractions_teacher_idx
  on public.material_extractions (teacher_id, created_at desc);

-- Escrita e leitura só pelo servidor (service_role ignora a RLS); sem
-- policies, nenhum outro papel vê as linhas.
alter table public.material_extractions enable row level security;
grant all on public.material_extractions to service_role;

-- Vídeos lidos HOJE (fuso de SP) pelo professor informado — inteiros ou em
-- parte ('partial': algum trecho falhou, mas os outros consumiram tokens).
-- Mesmo padrão de ai_questions_today: o teto vive na Edge Function.
create or replace function public.videos_read_today(p_teacher uuid)
returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int
  from public.material_extractions
  where teacher_id = p_teacher
    and kind = 'video'
    and status in ('success', 'partial')
    and (created_at at time zone 'America/Sao_Paulo')::date
      = (now()       at time zone 'America/Sao_Paulo')::date;
$$;

revoke all on function public.videos_read_today(uuid) from public, anon, authenticated;
grant execute on function public.videos_read_today(uuid) to service_role;
