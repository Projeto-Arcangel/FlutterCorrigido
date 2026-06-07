-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  SEED DE DEMONSTRAÇÃO — Arcangel                                  ║
-- ║  Execute no Supabase Dashboard → SQL Editor → New Query           ║
-- ║  Idempotente: pode rodar várias vezes (limpa dados antigos).      ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ── 0 · Limpeza de dados anteriores do seed ─────────────────────────
-- Apaga alunos-demo (cascade → profiles, user_progress, members, results)
DELETE FROM auth.users WHERE email LIKE '%@demo.arcangel.app';
-- Apaga turmas-demo (cascade → phases → questions, results, activities, members)
DELETE FROM public.classrooms WHERE code IN ('PRT3AA', 'MAT3AB');

-- ── 1 · Variáveis do seed ───────────────────────────────────────────
DO $$
DECLARE
  -- Professor (conta real já existente)
  v_teacher uuid := '5fb3bad3-2445-47ec-a8f0-1909c6f20d06';

  -- UUIDs fixos para turmas
  v_c1 uuid := 'c1000000-0001-4000-a000-000000000001'; -- Português
  v_c2 uuid := 'c2000000-0002-4000-a000-000000000002'; -- Matemática

  -- UUIDs fixos para fases (p = português, m = matemática)
  v_p1 uuid := 'f1000000-0001-4000-a000-000000000001';
  v_p2 uuid := 'f1000000-0002-4000-a000-000000000002';
  v_p3 uuid := 'f1000000-0003-4000-a000-000000000003';
  v_m1 uuid := 'f2000000-0001-4000-a000-000000000001';
  v_m2 uuid := 'f2000000-0002-4000-a000-000000000002';
  v_m3 uuid := 'f2000000-0003-4000-a000-000000000003';

  -- Arrays de alunos
  v_names text[] := ARRAY[
    'Ana Clara Santos','Bruno Henrique Oliveira','Camila Ferreira Lima',
    'Daniel Rodrigues Costa','Eduarda Almeida Silva','Felipe Souza Martins',
    'Gabriela Pereira Nunes','Henrique Castro Ribeiro','Isabela Moreira Pinto',
    'João Pedro Araújo','Karina Lopes Barbosa','Lucas Mendes Carvalho',
    'Mariana Gomes Teixeira','Nicolas Dias Correia','Olívia Nascimento Ramos',
    'Pedro Augusto Vieira','Rafaela Cardoso Freitas','Samuel Batista Monteiro',
    'Tatiana Rocha Azevedo','Ulisses Campos Duarte','Valentina Cruz Melo',
    'William Farias Rezende','Yasmin Borges Fonseca','Thiago Cunha Medeiros',
    'Letícia Andrade Moura','Matheus Pinheiro Leal','Natália Vasconcelos Serra',
    'Otávio Brito Nogueira','Priscila Domingues Amaral','Renato Machado Queiroz'
  ];

  v_sid  uuid;
  v_email text;
  v_pwd  text;
  i int;

  -- Scores por aluno: 6 fases (p1,p2,p3,m1,m2,m3), cada com 5 questões
  -- Organizado para simular distribuição realista
  v_scores int[][] := ARRAY[
    -- Excelentes (1-5)
    ARRAY[5,4,5,5,5,4], ARRAY[4,5,4,5,4,5], ARRAY[5,5,4,4,5,5],
    ARRAY[4,4,5,5,4,4], ARRAY[5,5,5,4,5,5],
    -- Bons (6-12)
    ARRAY[4,3,4,3,4,3], ARRAY[3,4,3,4,3,4], ARRAY[4,4,3,3,4,4],
    ARRAY[3,3,4,4,3,3], ARRAY[4,3,3,3,4,3], ARRAY[3,4,4,4,3,4],
    ARRAY[4,3,4,4,4,3],
    -- Medianos (13-20)
    ARRAY[3,2,3,3,3,2], ARRAY[2,3,2,3,2,3], ARRAY[3,3,2,2,3,3],
    ARRAY[2,2,3,3,2,2], ARRAY[3,2,2,2,3,2], ARRAY[2,3,3,3,2,3],
    ARRAY[3,2,3,2,3,2], ARRAY[2,3,2,3,2,3],
    -- Abaixo da média (21-27)
    ARRAY[2,1,2,2,2,1], ARRAY[1,2,1,2,1,2], ARRAY[2,2,1,1,2,2],
    ARRAY[1,1,2,2,1,1], ARRAY[2,1,1,1,2,1], ARRAY[1,2,2,1,1,2],
    ARRAY[2,1,2,1,2,1],
    -- Com dificuldade (28-30)
    ARRAY[1,0,1,1,1,0], ARRAY[0,1,0,1,0,1], ARRAY[1,1,0,0,1,1]
  ];

  v_phase_ids uuid[];
  v_student_ids uuid[] := '{}';

BEGIN
  v_phase_ids := ARRAY[v_p1, v_p2, v_p3, v_m1, v_m2, v_m3];

  -- Gera senha hash para os alunos demo (não precisam logar)
  v_pwd := crypt('Demo@2026!', gen_salt('bf'));

  -- ── 2 · Criar 30 alunos em auth.users ────────────────────────────
  FOR i IN 1..30 LOOP
    v_sid := gen_random_uuid();
    v_student_ids := v_student_ids || v_sid;
    v_email := 'aluno' || lpad(i::text, 2, '0') || '@demo.arcangel.app';

    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, is_sso_user, is_anonymous
    ) VALUES (
      v_sid,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      v_email, v_pwd,
      now() - interval '14 days',
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'display_name', v_names[i],
        'role', 'student'
      ),
      now() - interval '14 days',
      now(),
      false, false
    );
    -- O trigger handle_new_user cria profiles + user_progress automaticamente

    -- Atualiza prontuário (student_id) — trigger lock_student_id permite
    -- porque auth.uid() é null no contexto SQL Editor
    UPDATE public.profiles
       SET student_id = 'SP30' || lpad((1000 + i)::text, 4, '0')
     WHERE id = v_sid;

    -- Atualiza gamificação com valores variados
    UPDATE public.user_progress SET
      xp    = (50 - i) * 3.5 + (i % 7) * 10,
      gold  = (35 - i) * 2 + (i % 5) * 5,
      level = GREATEST(1, public.level_for_xp((50 - i) * 3.5 + (i % 7) * 10)),
      streak = CASE
        WHEN i <= 5  THEN 5 + (i % 3)
        WHEN i <= 15 THEN 2 + (i % 4)
        WHEN i <= 25 THEN i % 3
        ELSE 0
      END,
      last_login_date = current_date - (i % 5)
    WHERE user_id = v_sid;
  END LOOP;

  -- ── 3 · Criar turmas ─────────────────────────────────────────────
  INSERT INTO public.classrooms (id, code, name, description, teacher_id, is_active, created_at)
  VALUES
    (v_c1, 'PRT3AA', 'Português — 3º Ano A',
     'Turma de Língua Portuguesa do 3º ano do Ensino Médio, turno matutino.',
     v_teacher, true, now() - interval '30 days'),
    (v_c2, 'MAT3AB', 'Matemática — 3º Ano B',
     'Turma de Matemática do 3º ano do Ensino Médio, turno vespertino.',
     v_teacher, true, now() - interval '28 days');

  -- ── 4 · Matricular alunos nas turmas ──────────────────────────────
  FOR i IN 1..30 LOOP
    INSERT INTO public.classroom_members (classroom_id, student_id, joined_at)
    VALUES
      (v_c1, v_student_ids[i], now() - interval '25 days' + (i * interval '2 hours')),
      (v_c2, v_student_ids[i], now() - interval '23 days' + (i * interval '2 hours'));
  END LOOP;

  -- ── 5 · Criar fases ──────────────────────────────────────────────
  INSERT INTO public.classroom_phases (id, classroom_id, title, description, sort_order, weight) VALUES
    -- Português
    (v_p1, v_c1, 'Interpretação de Texto',
     'Análise e compreensão de textos em diferentes gêneros.', 0, 1),
    (v_p2, v_c1, 'Gramática Aplicada',
     'Aplicação prática de regras gramaticais em contexto.', 1, 1.5),
    (v_p3, v_c1, 'Literatura Brasileira',
     'Movimentos literários e obras fundamentais da literatura nacional.', 2, 2),
    -- Matemática
    (v_m1, v_c2, 'Funções e Gráficos',
     'Estudo de funções do 1º e 2º grau, exponenciais e logarítmicas.', 0, 1),
    (v_m2, v_c2, 'Geometria Analítica',
     'Estudo de pontos, retas e circunferências no plano cartesiano.', 1, 1.5),
    (v_m3, v_c2, 'Probabilidade e Estatística',
     'Análise combinatória, probabilidade e medidas estatísticas.', 2, 2);

  -- ── 6 · Criar questões (5 por fase = 30 total) ───────────────────

  -- ▸ Português — Fase 1: Interpretação de Texto
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_p1,
   'No trecho "A cidade acordava lentamente sob um véu de neblina", a expressão "véu de neblina" é exemplo de qual figura de linguagem?',
   ARRAY['Hipérbole','Metáfora','Metonímia','Eufemismo'], 1,
   'A neblina é comparada implicitamente a um véu, caracterizando uma metáfora.', 0),
  (v_p1,
   'Qual é a função principal do primeiro parágrafo em um texto dissertativo-argumentativo?',
   ARRAY['Apresentar contra-argumentos','Concluir a discussão','Introduzir a tese','Detalhar exemplos'], 2,
   'O primeiro parágrafo apresenta o tema e a tese que será defendida.', 1),
  (v_p1,
   'O conectivo "entretanto" estabelece uma relação de:',
   ARRAY['Adição','Causa','Oposição','Conclusão'], 2,
   '"Entretanto" indica oposição/contraste entre ideias.', 2),
  (v_p1,
   'Em "Os alunos cujos pais participam das reuniões têm melhor desempenho", o pronome relativo "cujos" indica:',
   ARRAY['Lugar','Posse','Tempo','Modo'], 1,
   '"Cujos" é pronome relativo que expressa posse.', 3),
  (v_p1,
   'No contexto da crônica, a linguagem coloquial serve principalmente para:',
   ARRAY['Distanciar o leitor','Aproximar o leitor do cotidiano','Formalizar o texto','Confundir a interpretação'], 1,
   'A linguagem coloquial na crônica gera identificação e proximidade com o leitor.', 4);

  -- ▸ Português — Fase 2: Gramática Aplicada
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_p2,
   'Assinale a alternativa em que o verbo está na voz passiva:',
   ARRAY['O menino correu pelo parque','A carta foi entregue ao destinatário','Ela saiu cedo de casa','Nós estudamos para a prova'], 1,
   '"Foi entregue" é locução verbal na voz passiva analítica.', 0),
  (v_p2,
   'Qual frase contém erro de concordância verbal?',
   ARRAY['Fazem dois anos que não viajo','Existem muitas opções','Houve vários acidentes','Choveu bastante ontem'], 0,
   'O correto é "Faz dois anos" — verbo fazer indicando tempo é impessoal.', 1),
  (v_p2,
   'Na oração "Se eu pudesse, viajaria o mundo", os tempos verbais são:',
   ARRAY['Futuro e pretérito','Pretérito imperfeito do subjuntivo e futuro do pretérito','Presente e futuro','Imperativo e gerúndio'], 1,
   '"Pudesse" = pret. imp. subjuntivo; "viajaria" = futuro do pretérito.', 2),
  (v_p2,
   'A palavra "anti-inflamatório" usa hífen porque:',
   ARRAY['Todo prefixo usa hífen antes de vogal','O segundo elemento inicia por "i"','O prefixo termina em "i" e o segundo elemento também inicia por "i"','Toda palavra composta usa hífen'], 2,
   'Usa-se hífen quando o prefixo termina com a mesma letra que inicia o segundo elemento.', 3),
  (v_p2,
   'Identifique a oração subordinada adverbial: "Embora estivesse cansado, ele continuou estudando."',
   ARRAY['ele continuou estudando','Embora estivesse cansado','continuou estudando','ele continuou'], 1,
   '"Embora estivesse cansado" é oração subordinada adverbial concessiva.', 4);

  -- ▸ Português — Fase 3: Literatura Brasileira
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_p3,
   'O Modernismo brasileiro de 1922 teve como principal objetivo:',
   ARRAY['Imitar a literatura portuguesa','Romper com o academicismo e valorizar a cultura nacional','Restaurar os valores do Romantismo','Adotar exclusivamente formas europeias'], 1,
   'A Semana de 22 buscou romper com padrões acadêmicos e celebrar a brasilidade.', 0),
  (v_p3,
   'Qual obra de Machado de Assis marca a transição para o Realismo?',
   ARRAY['A Mão e a Luva','Memórias Póstumas de Brás Cubas','Helena','Iracema'], 1,
   'Memórias Póstumas (1881) inaugurou o Realismo na literatura brasileira.', 1),
  (v_p3,
   'Grande Sertão: Veredas, de Guimarães Rosa, se destaca por:',
   ARRAY['Linguagem simples e direta','Narrativa linear e cronológica','Criação linguística e fluxo de consciência','Temática exclusivamente urbana'], 2,
   'Rosa reinventa a língua portuguesa, fundindo erudição e fala sertaneja.', 2),
  (v_p3,
   'Qual movimento literário priorizou a denúncia social no Nordeste?',
   ARRAY['Parnasianismo','Simbolismo','Romance de 30','Concretismo'], 2,
   'O Romance de 30 (Graciliano Ramos, Jorge Amado, Rachel de Queiroz) denunciou miséria e seca.', 3),
  (v_p3,
   'Clarice Lispector é mais associada a qual tipo de narrativa?',
   ARRAY['Romance de costumes','Ficção científica','Introspecção psicológica','Romance histórico'], 2,
   'Clarice explorou os estados interiores e a subjetividade humana.', 4);

  -- ▸ Matemática — Fase 1: Funções e Gráficos
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_m1,
   'Qual é o domínio da função f(x) = √(x − 3)?',
   ARRAY['x ≥ 0','x ≥ 3','x > 3','Todos os reais'], 1,
   'Para a raiz existir em ℝ, x − 3 ≥ 0, logo x ≥ 3.', 0),
  (v_m1,
   'O vértice da parábola y = x² − 6x + 8 é:',
   ARRAY['(3, −1)','(3, 1)','(−3, −1)','(6, 8)'], 0,
   'xv = 6/2 = 3; yv = 9 − 18 + 8 = −1. Vértice = (3, −1).', 1),
  (v_m1,
   'A função f(x) = 2ˣ é classificada como:',
   ARRAY['Polinomial','Logarítmica','Exponencial','Racional'], 2,
   'A variável está no expoente, caracterizando função exponencial.', 2),
  (v_m1,
   'Se f(x) = 3x + 2, qual é o valor de f(4)?',
   ARRAY['12','14','10','16'], 1,
   'f(4) = 3·4 + 2 = 14.', 3),
  (v_m1,
   'A função f(x) = −x² + 4 tem concavidade voltada para:',
   ARRAY['Cima','Baixo','Direita','Esquerda'], 1,
   'Coeficiente de x² negativo → concavidade para baixo.', 4);

  -- ▸ Matemática — Fase 2: Geometria Analítica
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_m2,
   'A distância entre os pontos A(1, 2) e B(4, 6) é:',
   ARRAY['4','5','6','7'], 1,
   'd = √((4−1)² + (6−2)²) = √(9+16) = √25 = 5.', 0),
  (v_m2,
   'A equação x² + y² = 25 representa:',
   ARRAY['Uma reta','Uma parábola','Uma circunferência de raio 5','Uma elipse'], 2,
   'Equação canônica de circunferência centrada na origem com r² = 25.', 1),
  (v_m2,
   'O coeficiente angular da reta que passa por (0, 1) e (2, 5) é:',
   ARRAY['1','2','3','4'], 1,
   'm = (5−1)/(2−0) = 4/2 = 2.', 2),
  (v_m2,
   'Duas retas são perpendiculares quando o produto de seus coeficientes angulares é:',
   ARRAY['0','1','−1','2'], 2,
   'Retas perpendiculares → m₁ · m₂ = −1.', 3),
  (v_m2,
   'O ponto médio do segmento com extremos (2, 8) e (6, 4) é:',
   ARRAY['(4, 6)','(3, 5)','(8, 12)','(2, 2)'], 0,
   'M = ((2+6)/2, (8+4)/2) = (4, 6).', 4);

  -- ▸ Matemática — Fase 3: Probabilidade e Estatística
  INSERT INTO public.questions (phase_id, text, options, correct_answer, explanation, sort_order) VALUES
  (v_m3,
   'Ao lançar dois dados, a probabilidade de a soma ser 7 é:',
   ARRAY['1/12','1/6','1/4','1/3'], 1,
   'São 6 combinações favoráveis em 36 possíveis: 6/36 = 1/6.', 0),
  (v_m3,
   'A mediana do conjunto {3, 7, 1, 9, 5} é:',
   ARRAY['3','5','7','9'], 1,
   'Ordenando: {1,3,5,7,9}. Elemento central = 5.', 1),
  (v_m3,
   'Se P(A) = 0,4 e P(B) = 0,3 (eventos independentes), P(A ∩ B) é:',
   ARRAY['0,7','0,12','0,1','0,52'], 1,
   'Eventos independentes: P(A∩B) = P(A)·P(B) = 0,4·0,3 = 0,12.', 2),
  (v_m3,
   'A moda do conjunto {2, 3, 3, 5, 7, 7, 7, 8} é:',
   ARRAY['3','5','7','8'], 2,
   'Moda = valor mais frequente = 7 (aparece 3 vezes).', 3),
  (v_m3,
   'O desvio padrão mede:',
   ARRAY['A média dos valores','A dispersão dos dados em relação à média','O valor mais frequente','A diferença entre máximo e mínimo'], 1,
   'O desvio padrão quantifica a dispersão (variabilidade) dos dados.', 4);

  -- ── 7 · Resultados por aluno por fase ─────────────────────────────
  FOR i IN 1..30 LOOP
    -- Turma Português: fases p1, p2, p3
    INSERT INTO public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers, completed_at)
    VALUES
      (v_c1, v_student_ids[i], v_p1, 5, v_scores[i][1],
       now() - interval '12 days' + (i * interval '3 hours')),
      (v_c1, v_student_ids[i], v_p2, 5, v_scores[i][2],
       now() - interval '8 days'  + (i * interval '2 hours')),
      (v_c1, v_student_ids[i], v_p3, 5, v_scores[i][3],
       now() - interval '3 days'  + (i * interval '1 hour'));

    -- Turma Matemática: fases m1, m2, m3
    INSERT INTO public.classroom_results
      (classroom_id, student_id, phase_id, total_questions, correct_answers, completed_at)
    VALUES
      (v_c2, v_student_ids[i], v_m1, 5, v_scores[i][4],
       now() - interval '11 days' + (i * interval '3 hours')),
      (v_c2, v_student_ids[i], v_m2, 5, v_scores[i][5],
       now() - interval '7 days'  + (i * interval '2 hours')),
      (v_c2, v_student_ids[i], v_m3, 5, v_scores[i][6],
       now() - interval '2 days'  + (i * interval '1 hour'));
  END LOOP;

  -- ── 8 · Atividades de timeline ────────────────────────────────────
  -- Atividades de entrada dos alunos
  FOR i IN 1..30 LOOP
    INSERT INTO public.classroom_activities (classroom_id, type, description, created_at) VALUES
      (v_c1, 'student_joined',
       v_names[i] || ' entrou na turma',
       now() - interval '25 days' + (i * interval '2 hours')),
      (v_c2, 'student_joined',
       v_names[i] || ' entrou na turma',
       now() - interval '23 days' + (i * interval '2 hours'));
  END LOOP;

  -- Atividades de conclusão de fase (apenas dos primeiros 25 alunos para variar)
  FOR i IN 1..25 LOOP
    INSERT INTO public.classroom_activities (classroom_id, type, description, created_at) VALUES
      (v_c1, 'student_completed',
       v_names[i] || ' concluiu a fase "Interpretação de Texto"',
       now() - interval '12 days' + (i * interval '3 hours')),
      (v_c1, 'student_completed',
       v_names[i] || ' concluiu a fase "Gramática Aplicada"',
       now() - interval '8 days' + (i * interval '2 hours')),
      (v_c2, 'student_completed',
       v_names[i] || ' concluiu a fase "Funções e Gráficos"',
       now() - interval '11 days' + (i * interval '3 hours')),
      (v_c2, 'student_completed',
       v_names[i] || ' concluiu a fase "Geometria Analítica"',
       now() - interval '7 days' + (i * interval '2 hours'));
  END LOOP;

  RAISE NOTICE '✅ Seed concluído: 30 alunos, 2 turmas, 6 fases, 30 questões, 180 resultados';
END;
$$;
