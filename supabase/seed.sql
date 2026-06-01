-- Seed idempotente — catálogo de conquistas (espelha achievementCatalog do app).
insert into public.achievements (id, title, description, rarity, xp_required, icon) values
  ('first_step', 'Primeiro Passo', 'Ganhe seus primeiros 50 XP', 'bronze',    50, 'bolt'),
  ('scholar',    'Estudante',      'Alcance 200 XP',             'bronze',   200, 'book'),
  ('dedicated',  'Dedicado',       'Alcance 500 XP',             'silver',   500, 'star'),
  ('historian',  'Historiador',    'Alcance 1 000 XP',           'silver',  1000, 'auto_stories'),
  ('sage',       'Sábio',          'Alcance 2 500 XP',           'gold',    2500, 'hat_wizard'),
  ('legend',     'Lenda',          'Alcance 5 000 XP',           'platinum',5000, 'trophy')
on conflict (id) do update set
  title       = excluded.title,
  description = excluded.description,
  rarity      = excluded.rarity,
  xp_required = excluded.xp_required,
  icon        = excluded.icon;
