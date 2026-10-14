import 'entities/plan.dart';

/// Os planos à venda, para quem ainda não entrou (landing) e para os cards
/// de comparação. O app logado usa o plano vindo do banco (`my_plan`); estes
/// valores DEVEM ser iguais aos da tabela `plans` — o teste
/// test/features/plans/plan_catalog_test.dart compara com a migration.
abstract final class PlanCatalog {
  static const free = Plan(
    id: 'free',
    name: 'Free',
    priceCents: 0,
    topicQuestions: 50,
    materialQuestions: 15,
    videoMinutes: 30,
    storedQuestions: 200,
    allowedModels: ['gemini-flash', 'claude-haiku'],
    pdfExport: false,
    prioritySupport: false,
  );

  static const pro = Plan(
    id: 'pro',
    name: 'Pro',
    priceCents: 1999,
    topicQuestions: 300,
    materialQuestions: 60,
    videoMinutes: 180,
    storedQuestions: 400,
    allowedModels: ['gemini-flash', 'gpt-mini', 'claude-haiku'],
    pdfExport: true,
    prioritySupport: false,
  );

  static const premium = Plan(
    id: 'premium',
    name: 'Premium',
    priceCents: 3999,
    topicQuestions: 600,
    materialQuestions: 120,
    videoMinutes: 480,
    storedQuestions: 600,
    allowedModels: ['gemini-flash', 'gpt-mini', 'claude-haiku'],
    pdfExport: true,
    prioritySupport: true,
  );

  static const all = [free, pro, premium];

  static Plan? byId(String id) {
    for (final plan in all) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  /// Para quem é cada plano (cards de comparação).
  static String description(Plan plan) => switch (plan.id) {
        'free' => 'Para conhecer a plataforma e começar com suas turmas.',
        'pro' => 'Para o professor que usa o Arcangel toda semana.',
        _ => 'Para quem produz muito conteúdo e quer atendimento '
            'prioritário.',
      };

  /// Itens comparáveis, na mesma ordem em todos os planos: dá para comparar
  /// linha a linha. `included: false` aparece riscado.
  static List<({String label, bool included})> features(Plan plan) {
    final gpt = plan.allowsModel('gpt-mini');
    return [
      (
        label: '${plan.topicQuestions} questões por mês com IA a partir de '
            'um tema',
        included: true,
      ),
      (
        label: '${plan.materialQuestions} questões por mês com IA a partir '
            'dos seus materiais',
        included: true,
      ),
      (
        label: '${PlanFormat.minutes(plan.videoMinutes)} de vídeos do '
            'YouTube por mês',
        included: true,
      ),
      (
        label: 'Armazenamento de até ${plan.storedQuestions} questões',
        included: true,
      ),
      (
        label: gpt ? 'Gemini, Claude e GPT Mini' : 'Modelo GPT Mini',
        included: gpt,
      ),
      (label: 'Banco de questões do ENEM', included: true),
      (label: 'Exportar notas em planilha (.xlsx)', included: true),
      (label: 'Exportar atividades em PDF', included: plan.pdfExport),
      (label: 'Suporte prioritário', included: plan.prioritySupport),
    ];
  }
}

/// Cobrança pelo app (Asaas). Desligada até a conta existir: enquanto isso,
/// os planos pagos são pedidos por e-mail e liberados pela equipe
/// (admin_grant_plan). Ligar no build com --dart-define=BILLING_ENABLED=true.
abstract final class BillingConfig {
  static const enabled = bool.fromEnvironment('BILLING_ENABLED');
}
