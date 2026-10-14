import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Um plano e seus limites mensais. Espelha a tabela `plans`
/// (supabase/migrations/20261012120000_plans_and_limits.sql).
class Plan extends Equatable {
  const Plan({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.topicQuestions,
    required this.materialQuestions,
    required this.videoMinutes,
    required this.storedQuestions,
    required this.allowedModels,
    required this.pdfExport,
    required this.prioritySupport,
  });

  factory Plan.fromMap(Map<String, dynamic> map) => Plan(
        id: map['id'] as String,
        name: map['name'] as String,
        priceCents: (map['price_cents'] as num).toInt(),
        topicQuestions: (map['topic_questions'] as num).toInt(),
        materialQuestions: (map['material_questions'] as num).toInt(),
        videoMinutes: (map['video_minutes'] as num).toInt(),
        storedQuestions: (map['stored_questions'] as num).toInt(),
        allowedModels: [
          for (final m in (map['allowed_models'] as List? ?? const [])) '$m',
        ],
        pdfExport: (map['pdf_export'] as bool?) ?? false,
        prioritySupport: (map['priority_support'] as bool?) ?? false,
      );

  final String id;
  final String name;

  /// Preço mensal em centavos (0 = gratuito).
  final int priceCents;

  /// Questões por mês com IA a partir de um tema.
  final int topicQuestions;

  /// Questões por mês com IA a partir dos materiais do professor.
  final int materialQuestions;

  /// Minutos de vídeo do YouTube lidos por mês.
  final int videoMinutes;

  /// Questões guardadas, somando todas as turmas.
  final int storedQuestions;

  /// Chaves dos modelos de IA (IaModelOption.key).
  final List<String> allowedModels;
  final bool pdfExport;
  final bool prioritySupport;

  bool get isFree => priceCents == 0;

  bool allowsModel(String key) => allowedModels.contains(key);

  @override
  List<Object?> get props => [
        id,
        name,
        priceCents,
        topicQuestions,
        materialQuestions,
        videoMinutes,
        storedQuestions,
        allowedModels,
        pdfExport,
        prioritySupport,
      ];
}

/// Uso do período atual: um mês contado do início do plano (no Free, do
/// cadastro ou do fim do último plano pago).
class PlanUsage extends Equatable {
  const PlanUsage({
    required this.topic,
    required this.materials,
    required this.videoMinutes,
    required this.stored,
  });

  factory PlanUsage.fromMap(Map<String, dynamic> map) => PlanUsage(
        topic: (map['topic'] as num?)?.toInt() ?? 0,
        materials: (map['materials'] as num?)?.toInt() ?? 0,
        videoMinutes: (map['video_minutes'] as num?)?.toInt() ?? 0,
        stored: (map['stored'] as num?)?.toInt() ?? 0,
      );

  final int topic;

  /// Já com o mínimo por geração aplicado.
  final int materials;
  final int videoMinutes;
  final int stored;

  @override
  List<Object?> get props => [topic, materials, videoMinutes, stored];
}

enum SubscriptionStatus {
  pending,
  active,
  pastDue,
  canceled;

  static SubscriptionStatus fromDb(String? value) => switch (value) {
        'pending' => pending,
        'past_due' => pastDue,
        'canceled' => canceled,
        _ => active,
      };
}

/// Assinatura mais relevante do professor (a viva, senão a última).
class PlanSubscription extends Equatable {
  const PlanSubscription({
    required this.planId,
    required this.status,
    required this.provider,
    this.nextPlanId,
    this.billingType,
    this.currentPeriodEnd,
    this.canceledAt,
    this.invoiceUrl,
  });

  factory PlanSubscription.fromMap(Map<String, dynamic> map) =>
      PlanSubscription(
        planId: map['plan_id'] as String,
        nextPlanId: map['next_plan_id'] as String?,
        status: SubscriptionStatus.fromDb(map['status'] as String?),
        provider: (map['provider'] as String?) ?? 'manual',
        billingType: map['billing_type'] as String?,
        currentPeriodEnd: _date(map['current_period_end']),
        canceledAt: _date(map['canceled_at']),
        invoiceUrl: map['invoice_url'] as String?,
      );

  final String planId;
  final String? nextPlanId;
  final SubscriptionStatus status;

  /// 'asaas' (cobrança automática) ou 'manual' (liberado pela equipe).
  final String provider;

  /// 'PIX' ou 'CREDIT_CARD'.
  final String? billingType;

  /// Pago até aqui. Nulo numa assinatura manual sem prazo.
  final DateTime? currentPeriodEnd;
  final DateTime? canceledAt;

  /// Cobrança em aberto no Asaas (1º pagamento ou mudança de plano).
  final String? invoiceUrl;

  bool get isManual => provider == 'manual';

  @override
  List<Object?> get props =>
      [planId, nextPlanId, status, provider, billingType, currentPeriodEnd];
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// De onde vem a geração: o limite e o mínimo por geração mudam.
enum GenerationSource { topic, materials }

/// Um limite do plano atingido (ou quase), com a dica do que fazer.
class PlanLimitNotice extends Equatable {
  const PlanLimitNotice({
    required this.title,
    required this.tip,
    required this.reached,
  });

  final String title;
  final String tip;

  /// true = esgotado; false = perto do fim (90% ou mais).
  final bool reached;

  @override
  List<Object?> get props => [title, tip, reached];
}

/// Plano em vigor, uso do período e assinatura do professor logado
/// (RPC `my_plan`).
class MyPlan extends Equatable {
  const MyPlan({
    required this.plan,
    required this.usage,
    required this.periodStart,
    required this.periodEnd,
    this.subscription,
    this.pending,
  });

  factory MyPlan.fromMap(Map<String, dynamic> map) => MyPlan(
        plan: Plan.fromMap(Map<String, dynamic>.from(map['plan'] as Map)),
        usage: PlanUsage.fromMap(
          Map<String, dynamic>.from((map['usage'] as Map?) ?? const {}),
        ),
        subscription: map['subscription'] is Map
            ? PlanSubscription.fromMap(
                Map<String, dynamic>.from(map['subscription'] as Map),
              )
            : null,
        pending: map['pending'] is Map
            ? PlanSubscription.fromMap(
                Map<String, dynamic>.from(map['pending'] as Map),
              )
            : null,
        periodStart: _date(map['period_start']) ?? DateTime.now(),
        periodEnd: _date(map['period_end']) ?? DateTime.now(),
      );

  final Plan plan;
  final PlanUsage usage;

  /// Assinatura em vigor (ou cancelada que vale até o fim do período).
  final PlanSubscription? subscription;

  /// Assinatura aguardando o 1º pagamento.
  final PlanSubscription? pending;
  final DateTime periodStart;

  /// Quando os limites renovam: um mês depois do início do período (mesmo
  /// dia e hora em que o plano começou).
  final DateTime periodEnd;

  int get topicRemaining => math.max(0, plan.topicQuestions - usage.topic);
  int get materialsRemaining =>
      math.max(0, plan.materialQuestions - usage.materials);
  int get videoMinutesRemaining =>
      math.max(0, plan.videoMinutes - usage.videoMinutes);
  int get storageRemaining => math.max(0, plan.storedQuestions - usage.stored);

  /// Questões guardadas acima do limite (depois de mudar para um plano
  /// menor). Nada é apagado; só não dá para adicionar novas.
  int get storageOverflow => math.max(0, usage.stored - plan.storedQuestions);

  int remainingFor(GenerationSource source) =>
      source == GenerationSource.materials
          ? materialsRemaining
          : topicRemaining;

  /// Por que a geração não pode sair agora (null = pode). Mesmas regras do
  /// servidor (plan_reserve), que dá a palavra final.
  String? generationBlock({
    required GenerationSource source,
    required int quantity,
    required String modelKey,
    required String modelLabel,
  }) {
    if (!plan.allowsModel(modelKey)) {
      return 'O $modelLabel está disponível nos planos Pro e Premium. '
          'Escolha outro modelo para gerar no seu plano.';
    }
    final remaining = remainingFor(source);
    final what = source == GenerationSource.materials
        ? 'questões com materiais'
        : 'questões por tema';
    final renew = 'Elas renovam em $resetLabel.';
    if (remaining <= 0) {
      return 'Você usou as ${_limitFor(source)} $what do plano ${plan.name}. '
          '$renew';
    }
    if (quantity > remaining) {
      return 'Restam $remaining $what até $resetLabel. Peça $remaining ou '
          'menos.';
    }
    if (quantity > storageRemaining) {
      return storageRemaining == 0
          ? 'Você já guarda ${usage.stored} questões, o limite do plano '
              '${plan.name}. Apague questões que não usa mais para salvar '
              'novas.'
          : 'Só cabem mais $storageRemaining questões no seu plano. Peça '
              '$storageRemaining ou menos, ou apague questões que não usa '
              'mais.';
    }
    return null;
  }

  int _limitFor(GenerationSource source) => source == GenerationSource.materials
      ? plan.materialQuestions
      : plan.topicQuestions;

  /// "12 de novembro às 15h04".
  String get resetLabel => PlanFormat.resetLabel(periodEnd);

  /// Limites atingidos ou quase (90%), com dicas — para o aviso depois de
  /// mudar de plano e para a tela "Meu plano".
  List<PlanLimitNotice> get notices {
    final notices = <PlanLimitNotice>[];
    void check(int used, int limit, String what, String tip) {
      if (limit <= 0) return;
      if (used >= limit) {
        notices.add(
          PlanLimitNotice(
            title: 'Você usou todas as $what do período.',
            tip: tip,
            reached: true,
          ),
        );
      } else if (used >= limit * 0.9) {
        notices.add(
          PlanLimitNotice(
            title: 'Restam ${limit - used} $what neste período.',
            tip: tip,
            reached: false,
          ),
        );
      }
    }

    final renew = 'O limite renova em $resetLabel.';
    check(
      usage.topic,
      plan.topicQuestions,
      'questões por tema',
      '$renew Até lá, reutilize questões que você já criou ou crie questões '
          'manualmente.',
    );
    check(
      usage.materials,
      plan.materialQuestions,
      'questões com materiais',
      '$renew Até lá, gere questões por tema, reutilize questões que você '
          'já criou ou crie questões manualmente.',
    );
    check(
      usage.videoMinutes,
      plan.videoMinutes,
      'minutos de vídeo',
      '$renew Até lá, anexe o conteúdo do vídeo em PDF, Word ou PowerPoint.',
    );
    if (storageOverflow > 0) {
      notices.add(
        PlanLimitNotice(
          title: 'Você guarda ${usage.stored} questões e o plano '
              '${plan.name} guarda até ${plan.storedQuestions}.',
          tip: 'Nada foi apagado: suas turmas seguem funcionando. Para '
              'adicionar questões novas, apague pelo menos '
              '${storageOverflow + 1} que você não usa mais.',
          reached: true,
        ),
      );
    } else {
      check(
        usage.stored,
        plan.storedQuestions,
        'vagas de questões guardadas',
        'Apague questões que você não usa mais para liberar espaço.',
      );
    }
    return notices;
  }

  @override
  List<Object?> get props =>
      [plan, usage, subscription, pending, periodStart, periodEnd];
}

/// Formatação de preços, minutos e datas dos planos.
abstract final class PlanFormat {
  static const _months = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  /// "R$ 19,99"; "Grátis" para 0.
  static String price(int cents) {
    if (cents == 0) return 'Grátis';
    final reais = cents ~/ 100;
    final centavos = (cents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$centavos';
  }

  /// "30 minutos", "3 horas", "1 h 30 min".
  static String minutes(int minutes) {
    if (minutes < 60) return '$minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours ${hours == 1 ? 'hora' : 'horas'}';
    return '$hours h $rest min';
  }

  /// "12 de novembro às 15h04": quando o período renova, no horário de SP
  /// (UTC−3, sem horário de verão desde 2019).
  static String resetLabel(DateTime periodEnd) {
    final sp = _sp(periodEnd);
    final minute = sp.minute.toString().padLeft(2, '0');
    return '${sp.day == 1 ? '1º' : '${sp.day}'} de ${_months[sp.month - 1]} '
        'às ${sp.hour}h$minute';
  }

  /// "12/10 a 12/11": o período de uso.
  static String period(DateTime start, DateTime end) {
    String dm(DateTime d) {
      final sp = _sp(d);
      return '${sp.day.toString().padLeft(2, '0')}/'
          '${sp.month.toString().padLeft(2, '0')}';
    }

    return '${dm(start)} a ${dm(end)}';
  }

  static DateTime _sp(DateTime value) =>
      value.toUtc().subtract(const Duration(hours: 3));

  /// "12/11/2026" (data no fuso de SP).
  static String date(DateTime value) {
    final sp = _sp(value);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(sp.day)}/${two(sp.month)}/${sp.year}';
  }
}
