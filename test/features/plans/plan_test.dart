import 'package:arcangel_o_oficial/features/plans/domain/cpf_cnpj.dart';
import 'package:arcangel_o_oficial/features/plans/domain/entities/plan.dart';
import 'package:arcangel_o_oficial/features/plans/domain/plan_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

MyPlan _plan(
  Plan plan, {
  int topic = 0,
  int materials = 0,
  int video = 0,
  int stored = 0,
}) =>
    MyPlan(
      plan: plan,
      usage: PlanUsage(
        topic: topic,
        materials: materials,
        videoMinutes: video,
        stored: stored,
      ),
      // Plano começou em 12/10 às 15h04 (SP): renova em 12/11 às 15h04.
      periodStart: DateTime.utc(2026, 10, 12, 18, 4),
      periodEnd: DateTime.utc(2026, 11, 12, 18, 4),
    );

String? _block(
  MyPlan p, {
  GenerationSource source = GenerationSource.topic,
  int quantity = 10,
  String model = 'gemini-flash',
}) =>
    p.generationBlock(
      source: source,
      quantity: quantity,
      modelKey: model,
      modelLabel: model == 'gpt-mini' ? 'GPT Mini' : 'Gemini Flash',
    );

void main() {
  group('limites da geração (mesmas regras do servidor)', () {
    test('dentro do limite, gera', () {
      expect(_block(_plan(PlanCatalog.free, topic: 40)), isNull);
    });

    test('GPT Mini só nos planos pagos', () {
      expect(
        _block(_plan(PlanCatalog.free), model: 'gpt-mini'),
        contains('Pro e Premium'),
      );
      expect(_block(_plan(PlanCatalog.pro), model: 'gpt-mini'), isNull);
    });

    test('pedir mais do que resta → diz quanto pedir', () {
      expect(
        _block(_plan(PlanCatalog.free, topic: 45), quantity: 10),
        'Restam 5 questões por tema até 12 de novembro às 15h04. Peça 5 ou '
        'menos.',
      );
    });

    test('esgotado → diz quando renova', () {
      expect(
        _block(_plan(PlanCatalog.free, topic: 50)),
        contains('renovam em 12 de novembro às 15h04'),
      );
    });

    test('materiais: cada geração conta no mínimo 5', () {
      final p = _plan(PlanCatalog.free, materials: 11);
      expect(p.chargeFor(GenerationSource.materials, 1), 5);
      expect(p.chargeFor(GenerationSource.materials, 8), 8);
      expect(p.chargeFor(GenerationSource.topic, 1), 1);
      // Restam 4: nem uma geração de 1 questão cabe.
      expect(
        _block(p, source: GenerationSource.materials, quantity: 1),
        contains('no mínimo 5'),
      );
      expect(p.maxQuantity(GenerationSource.materials), 0);
      expect(
        _plan(PlanCatalog.free, materials: 10)
            .maxQuantity(GenerationSource.materials),
        5,
      );
    });

    test('armazenamento: não gera o que não dá para salvar', () {
      expect(
        _block(_plan(PlanCatalog.free, stored: 195), quantity: 10),
        contains('Só cabem mais 5'),
      );
      expect(
        _block(_plan(PlanCatalog.free, stored: 200), quantity: 1),
        contains('Apague questões'),
      );
    });
  });

  group('avisos depois de mudar de plano', () {
    test('nada perto do limite → sem aviso', () {
      expect(_plan(PlanCatalog.pro, topic: 10, stored: 50).notices, isEmpty);
    });

    test('downgrade com mais questões guardadas que o limite', () {
      final p = _plan(PlanCatalog.free, stored: 350);
      expect(p.storageOverflow, 150);
      final notice = p.notices.single;
      expect(notice.reached, isTrue);
      expect(notice.title, contains('350'));
      expect(notice.tip, contains('Nada foi apagado'));
      expect(notice.tip, contains('151'));
    });

    test('limite esgotado e quase esgotado, com dicas', () {
      final notices = _plan(PlanCatalog.free, topic: 50, video: 28).notices;
      expect(notices, hasLength(2));
      expect(notices[0].reached, isTrue);
      expect(notices[0].tip, contains('12 de novembro às 15h04'));
      expect(notices[1].reached, isFalse);
      expect(notices[1].tip, contains('PDF, Word ou PowerPoint'));
    });
  });

  group('my_plan', () {
    test('lê o JSON da RPC', () {
      final p = MyPlan.fromMap(const {
        'plan': {
          'id': 'pro',
          'name': 'Pro',
          'price_cents': 1999,
          'topic_questions': 300,
          'material_questions': 60,
          'video_minutes': 180,
          'stored_questions': 400,
          'material_min_charge': 5,
          'allowed_models': ['gemini-flash', 'gpt-mini', 'claude-haiku'],
          'pdf_export': true,
          'priority_support': false,
          'sort_order': 1,
        },
        'usage': {
          'topic': 12,
          'materials': 5,
          'video_minutes': 7,
          'stored': 30,
        },
        'subscription': {
          'plan_id': 'pro',
          'status': 'past_due',
          'provider': 'asaas',
          'billing_type': 'PIX',
          'current_period_end': '2026-11-13T03:00:00+00:00',
          'invoice_url': 'https://sandbox.asaas.com/i/x',
        },
        'pending': null,
        'period_start': '2026-10-03T00:17:00+00:00',
        'period_end': '2026-11-03T00:17:00+00:00',
      });
      expect(p.plan, PlanCatalog.pro);
      expect(p.topicRemaining, 288);
      expect(p.subscription!.status, SubscriptionStatus.pastDue);
      expect(p.subscription!.invoiceUrl, isNotNull);
      expect(p.pending, isNull);
      // 03/11 00:17 UTC = 02/11 21h17 em SP.
      expect(p.resetLabel, '2 de novembro às 21h17');
    });
  });

  group('formatação', () {
    test('preço', () {
      expect(PlanFormat.price(0), 'Grátis');
      expect(PlanFormat.price(1999), r'R$ 19,99');
      expect(PlanFormat.price(4000), r'R$ 40,00');
    });

    test('minutos', () {
      expect(PlanFormat.minutes(30), '30 minutos');
      expect(PlanFormat.minutes(180), '3 horas');
      expect(PlanFormat.minutes(60), '1 hora');
      expect(PlanFormat.minutes(90), '1 h 30 min');
    });

    test('renovação no fuso de SP', () {
      // Meia-noite de 1º de janeiro em SP = 03:00 UTC.
      expect(
        PlanFormat.resetLabel(DateTime.utc(2027, 1, 1, 3)),
        '1º de janeiro às 0h00',
      );
      expect(
        PlanFormat.resetLabel(DateTime.utc(2026, 11, 12, 18, 4)),
        '12 de novembro às 15h04',
      );
      expect(
        PlanFormat.period(
          DateTime.utc(2026, 10, 12, 18, 4),
          DateTime.utc(2026, 11, 12, 18, 4),
        ),
        '12/10 a 12/11',
      );
      expect(PlanFormat.date(DateTime.utc(2026, 11, 13, 2, 59)), '12/11/2026');
    });

    test('itens dos cards: GPT Mini riscado no Free', () {
      final free = PlanCatalog.features(PlanCatalog.free);
      final pro = PlanCatalog.features(PlanCatalog.pro);
      expect(free.length, pro.length);
      expect(free.firstWhere((f) => f.label.contains('GPT')).included, isFalse);
      expect(pro.firstWhere((f) => f.label.contains('GPT')).included, isTrue);
      expect(free[2].label, '30 minutos de vídeos do YouTube por mês');
      expect(pro[2].label, '3 horas de vídeos do YouTube por mês');
    });
  });

  group('CPF e CNPJ', () {
    test('válidos', () {
      expect(CpfCnpj.isValid('529.982.247-25'), isTrue);
      expect(CpfCnpj.isValid('52998224725'), isTrue);
      expect(CpfCnpj.isValid('11.222.333/0001-81'), isTrue);
    });

    test('inválidos', () {
      expect(CpfCnpj.isValid('529.982.247-24'), isFalse);
      expect(CpfCnpj.isValid('111.111.111-11'), isFalse);
      expect(CpfCnpj.isValid('11.222.333/0001-80'), isFalse);
      expect(CpfCnpj.isValid('123'), isFalse);
      expect(CpfCnpj.isValid(''), isFalse);
    });

    test('formata', () {
      expect(CpfCnpj.format('52998224725'), '529.982.247-25');
      expect(CpfCnpj.format('11222333000181'), '11.222.333/0001-81');
    });
  });
}
