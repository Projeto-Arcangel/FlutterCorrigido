import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/plan.dart';

/// Plano e uso do professor logado (RPC `my_plan`, que usa `auth.uid()`:
/// cada professor vê só o próprio).
class PlanDatasource {
  PlanDatasource(this._client);

  final SupabaseClient _client;

  Future<MyPlan> fetchMyPlan() async {
    final data = await _client.rpc<dynamic>('my_plan');
    if (data is! Map) {
      throw const PostgrestException(message: 'Plano não encontrado.');
    }
    return MyPlan.fromMap(Map<String, dynamic>.from(data));
  }
}
