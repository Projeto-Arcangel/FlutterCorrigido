-- Marca as questões do ENEM que possuem imagem (no enunciado OU em alguma
-- alternativa), para alimentar o filtro "somente sem imagem" da busca do
-- professor. Popula as linhas já existentes (sem precisar re-importar); o
-- script de importação passa a manter a coluna atualizada em novas cargas.

alter table public.enem_questions
  add column if not exists has_image boolean not null default false;

update public.enem_questions q
  set has_image = (array_length(q.context_images, 1) is not null)
    or exists (
      select 1
      from jsonb_array_elements(q.alternatives) e
      where nullif(e->>'file', '') is not null
    );

create index if not exists enem_questions_has_image_idx
  on public.enem_questions (has_image);
