-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Origem de cada geração por IA: por tema ou a partir de materiais    ║
-- ║                                                                    ║
-- ║  Os planos (Estágio 2) têm limites separados para "questões com IA  ║
-- ║  a partir de um tema" e "a partir dos seus materiais". A coluna     ║
-- ║  `source` permite contar cada um. Gerações antigas = 'topic'.       ║
-- ║                                                                    ║
-- ║  `materials` guarda só METADADOS (nome, tipo, nº de caracteres e    ║
-- ║  quanto do material a IA leu) — nunca o conteúdo: o arquivo do      ║
-- ║  professor é lido no navegador e descartado.                        ║
-- ╚══════════════════════════════════════════════════════════════════╝

alter table public.ai_generation_logs
  add column source text not null default 'topic'
    constraint ai_generation_logs_source_check
      check (source in ('topic', 'materials')),
  add column materials jsonb;

comment on column public.ai_generation_logs.source is
  'Origem da geração: topic (tema digitado) ou materials (arquivos do professor).';
comment on column public.ai_generation_logs.materials is
  'Metadados dos materiais usados: [{name, kind, chars, coverage}]. Sem conteúdo.';
