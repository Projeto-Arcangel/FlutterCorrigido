-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Consumo real de cada geração por IA (tokens e custo)               ║
-- ║                                                                    ║
-- ║  A generate-questions passa a pedir ao OpenRouter o consumo de     ║
-- ║  cada chamada (usage accounting) e grava aqui, somando as          ║
-- ║  tentativas que falharam (também são cobradas). Base para          ║
-- ║  dimensionar os limites dos planos e acompanhar o custo por        ║
-- ║  professor. Gerações antigas ficam com NULL.                       ║
-- ╚══════════════════════════════════════════════════════════════════╝

alter table public.ai_generation_logs
  add column input_tokens  int,
  add column output_tokens int,
  add column cost_usd      numeric(12, 6);

comment on column public.ai_generation_logs.input_tokens is
  'Tokens de entrada (prompt + materiais), somando todas as tentativas.';
comment on column public.ai_generation_logs.output_tokens is
  'Tokens de saída (inclui raciocínio interno cobrado), somando as tentativas.';
comment on column public.ai_generation_logs.cost_usd is
  'Custo informado pelo OpenRouter, em dólares, somando as tentativas.';
