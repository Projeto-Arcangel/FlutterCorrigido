-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Banco de questões do ENEM (dataset enem.dev, 2009–2023)            ║
-- ║   Tabela só-leitura para os professores comporem trilhas.          ║
-- ║   Populada via script de importação (service_role).                ║
-- ║   Imagens no bucket público `enem-questions`.                      ║
-- ╚══════════════════════════════════════════════════════════════════╝

create table public.enem_questions (
  id                        uuid primary key default gen_random_uuid(),
  year                      int  not null,
  index                     int  not null,                 -- nº da questão na prova
  discipline                text not null,                 -- ciencias-humanas | ciencias-natureza | linguagens | matematica
  language                  text not null default '',      -- '' | ingles | espanhol ('' p/ idempotência do unique)
  context                   text not null default '',      -- enunciado (markdown)
  context_images            text[] not null default '{}',  -- URLs das imagens do enunciado
  alternatives_introduction text not null default '',
  correct_alternative       text not null,                 -- 'A'..'E'
  alternatives              jsonb not null,                -- [{letter,text,file,isCorrect}]
  created_at                timestamptz not null default now(),
  -- Idempotência da importação: uma questão por (ano, índice, idioma).
  unique (year, index, language)
);

-- Índice para os filtros do professor (ano / área / idioma).
create index enem_questions_filter_idx
  on public.enem_questions (year, discipline, language);

alter table public.enem_questions enable row level security;

-- Qualquer usuário autenticado pode pesquisar o banco de questões.
create policy enem_questions_select
  on public.enem_questions for select
  to authenticated
  using (true);

-- Sem policies de escrita: somente o service_role (que ignora RLS) popula
-- via o script de importação.

grant select on public.enem_questions to authenticated;
grant all    on public.enem_questions to service_role;

-- ── Storage: bucket público para as imagens das questões ──────────────
-- Bucket público → leitura anônima das imagens pela URL; upload só via
-- service_role no script. Idempotente.
insert into storage.buckets (id, name, public)
values ('enem-questions', 'enem-questions', true)
on conflict (id) do nothing;
