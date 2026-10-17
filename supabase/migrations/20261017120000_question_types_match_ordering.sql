-- Estágio 4, Etapa 2: tipos "ligar colunas" e "ordenar".
-- Fica num arquivo só seu: o Postgres só deixa usar um valor novo de enum
-- depois que a transação que o criou termina (a migration seguinte usa).
alter type public.question_type add value if not exists 'match_columns';
alter type public.question_type add value if not exists 'ordering';
