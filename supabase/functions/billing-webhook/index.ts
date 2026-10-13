// Edge Function: billing-webhook
//
// Recebe os eventos do Asaas (configurado no painel do Asaas, com o token
// ASAAS_WEBHOOK_TOKEN). Sem JWT (verify_jwt = false em config.toml): a
// autenticação é o token no header `asaas-access-token`.
//
// Cada evento é gravado em billing_events pelo id: o Asaas reenvia até
// receber 200, e um evento já aplicado não é aplicado de novo. As mudanças
// de estado são feitas por funções do banco (uma transação cada).
//
//   PAYMENT_CONFIRMED / PAYMENT_RECEIVED  → ativa ou renova (ou aplica a
//                                           diferença paga para subir de plano)
//   PAYMENT_OVERDUE                       → atrasada (vale mais 3 dias)
//   PAYMENT_REFUNDED / PAYMENT_CHARGEBACK_REQUESTED → perde o plano na hora
//   SUBSCRIPTION_DELETED / SUBSCRIPTION_INACTIVATED → vale até o fim do período
//
// Respostas: 200 (aplicado, repetido ou ignorado) · 401 token · 500 falha
// (o Asaas tenta de novo).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { asaas, asaasConfig, reais, safeEqual } from "../_shared/asaas.ts";

type AdminClient = ReturnType<typeof createClient>;

interface AsaasPayment {
  id?: string;
  subscription?: string | null;
  dueDate?: string;
  externalReference?: string | null;
}

interface AsaasEvent {
  id?: string;
  event?: string;
  dateCreated?: string;
  payment?: AsaasPayment;
  subscription?: { id?: string };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** O mesmo pagamento já ativou/renovou (CONFIRMED e depois RECEIVED). */
async function paymentAlreadyApplied(
  admin: AdminClient,
  paymentId: string,
  eventId: string,
): Promise<boolean> {
  const { data } = await admin
    .from("billing_events")
    .select("id")
    .in("event", ["PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"])
    .eq("payload->payment->>id", paymentId)
    .not("processed_at", "is", null)
    .neq("id", eventId)
    .limit(1);
  return (data ?? []).length > 0;
}

/** Aplica o evento. Devolve uma observação (vai para billing_events.error). */
async function apply(admin: AdminClient, evt: AsaasEvent, eventId: string): Promise<string | null> {
  const cfg = asaasConfig();
  const payment = evt.payment ?? {};
  switch (evt.event) {
    case "PAYMENT_CONFIRMED":
    case "PAYMENT_RECEIVED": {
      if (payment.id && await paymentAlreadyApplied(admin, payment.id, eventId)) {
        return null;
      }
      const ref = payment.externalReference ?? "";
      if (ref.startsWith("upgrade:")) {
        const [, subscriptionRow, planId] = ref.split(":");
        const { data, error } = await admin.rpc("billing_upgrade_paid", {
          p_subscription: subscriptionRow,
          p_plan: planId,
        });
        if (error) throw error;
        const result = data as { ok: boolean; reason?: string; provider_subscription_id?: string; price_cents?: number };
        if (!result.ok) return `upgrade ignorado: ${result.reason}`;
        // As próximas renovações passam para o preço do plano novo.
        if (cfg && result.provider_subscription_id) {
          await asaas(cfg, "POST", `/subscriptions/${result.provider_subscription_id}`, {
            value: reais(result.price_cents ?? 0),
            updatePendingPayments: true,
          });
        }
        return null;
      }
      if (!payment.subscription || !payment.dueDate) return "pagamento avulso ignorado";
      const { data, error } = await admin.rpc("billing_payment_confirmed", {
        p_provider_subscription: payment.subscription,
        p_due_date: payment.dueDate,
      });
      if (error) throw error;
      const result = data as { ok: boolean; reason?: string; superseded?: string[] };
      if (!result.ok) return `pagamento não aplicado: ${result.reason}`;
      // Assinaturas antigas do Asaas substituídas por esta: param de cobrar.
      for (const old of result.superseded ?? []) {
        if (!cfg) break;
        await asaas(cfg, "DELETE", `/subscriptions/${old}`)
          .catch((e) => console.error(`billing-webhook: cancelar ${old}`, e));
      }
      return null;
    }
    case "PAYMENT_OVERDUE": {
      if (!payment.subscription) return null;
      const { error } = await admin.rpc("billing_payment_overdue", {
        p_provider_subscription: payment.subscription,
      });
      if (error) throw error;
      return null;
    }
    case "PAYMENT_REFUNDED":
    case "PAYMENT_CHARGEBACK_REQUESTED": {
      if (!payment.subscription) return "estorno de pagamento avulso: revisar à mão";
      const { error } = await admin.rpc("billing_subscription_ended", {
        p_provider_subscription: payment.subscription,
        p_revoke: true,
      });
      if (error) throw error;
      return null;
    }
    case "SUBSCRIPTION_DELETED":
    case "SUBSCRIPTION_INACTIVATED": {
      const id = evt.subscription?.id;
      if (!id) return null;
      const { error } = await admin.rpc("billing_subscription_ended", {
        p_provider_subscription: id,
        p_revoke: false,
      });
      if (error) throw error;
      return null;
    }
    default:
      return "evento ignorado";
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json(405, { error: "Método não permitido." });

  const expected = Deno.env.get("ASAAS_WEBHOOK_TOKEN") ?? "";
  if (!expected) {
    console.error("billing-webhook: ASAAS_WEBHOOK_TOKEN não configurado");
    return json(503, { error: "Webhook não configurado." });
  }
  const token = req.headers.get("asaas-access-token") ?? "";
  if (!safeEqual(token, expected)) return json(401, { error: "Token inválido." });

  const evt = await req.json().catch(() => null) as AsaasEvent | null;
  if (!evt?.event) return json(400, { error: "Evento inválido." });
  const eventId = evt.id ??
    `${evt.event}:${evt.payment?.id ?? evt.subscription?.id ?? ""}:${evt.dateCreated ?? ""}`;

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Registra (ou reencontra) o evento: aplicado uma vez só.
  const { error: insertErr } = await admin
    .from("billing_events")
    .insert({ id: eventId, event: evt.event, payload: evt });
  if (insertErr) {
    const { data: seen } = await admin
      .from("billing_events").select("processed_at").eq("id", eventId).maybeSingle();
    if (!seen) {
      console.error("billing-webhook: falha ao registrar evento", insertErr);
      return json(500, { error: "Falha ao registrar o evento." });
    }
    if (seen.processed_at) return json(200, { ok: true, duplicate: true });
  }

  try {
    const note = await apply(admin, evt, eventId);
    await admin.from("billing_events")
      .update({ processed_at: new Date().toISOString(), error: note })
      .eq("id", eventId);
    return json(200, { ok: true, note });
  } catch (e) {
    console.error(`billing-webhook: ${evt.event} ${eventId}`, e);
    await admin.from("billing_events")
      .update({ error: String((e as Error)?.message ?? e).slice(0, 500) })
      .eq("id", eventId);
    return json(500, { error: "Falha ao aplicar o evento." });
  }
});
