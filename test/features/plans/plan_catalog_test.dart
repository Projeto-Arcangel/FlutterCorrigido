import 'dart:io';

import 'package:arcangel_o_oficial/features/plans/domain/plan_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Os planos da landing e dos cards ([PlanCatalog]) precisam ser os mesmos
/// da tabela `plans` (o que o servidor cobra e limita). Lê o seed da
/// migration e compara campo a campo.
void main() {
  test('PlanCatalog é igual ao seed da tabela plans', () {
    final sql = File(
      'supabase/migrations/20261012120000_plans_and_limits.sql',
    ).readAsStringSync();
    // ('id', 'Nome', preço, tema, materiais, vídeo, guardadas,
    //  array['modelo', ...], pdf, suporte, ordem)
    // \x27 = aspas simples.
    final row = RegExp(
      r'\(\x27(\w+)\x27,\s*\x27(\w+)\x27,\s*(\d+),\s*(\d+),\s*(\d+),'
      r'\s*(\d+),\s*(\d+),\s*array\[([^\]]*)\],'
      r'\s*(true|false),\s*(true|false),\s*(\d+)\)',
    );
    final rows = row.allMatches(sql).toList();
    expect(rows, hasLength(PlanCatalog.all.length));

    for (final m in rows) {
      final plan = PlanCatalog.byId(m.group(1)!);
      expect(plan, isNotNull, reason: 'plano ${m.group(1)} fora do catálogo');
      expect(plan!.name, m.group(2));
      expect(plan.priceCents, int.parse(m.group(3)!));
      expect(plan.topicQuestions, int.parse(m.group(4)!));
      expect(plan.materialQuestions, int.parse(m.group(5)!));
      expect(plan.videoMinutes, int.parse(m.group(6)!));
      expect(plan.storedQuestions, int.parse(m.group(7)!));
      expect(
        plan.allowedModels,
        RegExp("'([^']+)'")
            .allMatches(m.group(8)!)
            .map((x) => x.group(1))
            .toList(),
      );
      expect(plan.pdfExport, m.group(9) == 'true');
      expect(plan.prioritySupport, m.group(10) == 'true');
      expect(PlanCatalog.all.indexOf(plan), int.parse(m.group(11)!));
    }
  });

  test('valores aprovados: preços, limites e GPT Mini só nos pagos', () {
    expect(
      PlanCatalog.all.map((p) => p.priceCents),
      [0, 1999, 3999],
    );
    expect(
      PlanCatalog.all.map((p) => p.storedQuestions),
      [200, 400, 600],
    );
    expect(PlanCatalog.free.allowsModel('gpt-mini'), isFalse);
    expect(PlanCatalog.pro.allowsModel('gpt-mini'), isTrue);
    expect(PlanCatalog.premium.allowsModel('gpt-mini'), isTrue);
  });

  test('os modelos dos planos existem no app e no servidor', () {
    final server =
        File('supabase/functions/_shared/openrouter.ts').readAsStringSync();
    for (final plan in PlanCatalog.all) {
      for (final model in plan.allowedModels) {
        expect(server, contains('"$model":'), reason: model);
      }
    }
  });
}
