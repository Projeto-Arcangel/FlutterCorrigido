-- Estágio 4, Etapa 4: tipos "cruzadinha" e "caça-palavras".
-- Arquivo só seu: o valor novo de enum só pode ser usado depois que a
-- transação que o criou termina (a migration seguinte usa).
alter type public.question_type add value if not exists 'crossword';
alter type public.question_type add value if not exists 'word_search';
