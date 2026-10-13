import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/infrastructure/supabase_providers.dart';
import '../../data/billing_datasource.dart';
import '../../data/plan_datasource.dart';
import '../../domain/entities/plan.dart';

final planDatasourceProvider = Provider<PlanDatasource>(
  (ref) => PlanDatasource(ref.watch(supabaseClientProvider)),
);

final billingDatasourceProvider = Provider<BillingDatasource>(
  (ref) => BillingDatasource(ref.watch(supabaseClientProvider)),
);

/// Plano em vigor e uso do mês do professor logado. Invalidar depois de
/// gerar, ler um vídeo ou salvar/apagar questões.
final myPlanProvider = FutureProvider.autoDispose<MyPlan>(
  (ref) => ref.watch(planDatasourceProvider).fetchMyPlan(),
);
