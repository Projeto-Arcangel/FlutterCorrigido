// Edge Function: billing-cancel
//
// Cancela a renovação da assinatura do Asaas do professor logado. Não há
// novas cobranças; o plano vale até o fim do período pago e depois a conta
// volta ao Free (nada é apagado). Um pagamento ainda em aberto (1º mês) é
// simplesmente desfeito.
//
// Respostas: 200 { message } · 4xx/5xx { error, code }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { asaas, asaasConfig, AsaasError, BILLING_MESSAGES } from "../_shared/asaas.ts";

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, code: string, message: string): Response {
  return json(status, { error: message, code });
}

function dateBr(iso: string | null): string {
  if (!iso) return "o fim do período pago";
  const [y, m, d] = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
  }).format(new Date(iso)).split("-");
  return `${d}/${m}/${y}`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return fail(405, "method", "Método não permitido.");

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return fail(401, "auth", "Não autenticado.");
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return fail(401, "auth", "Não autenticado.");

  const cfg = asaasConfig();
  if (!cfg) return fail(503, "billing_disabled", BILLING_MESSAGES.disabled);

  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: subs, error: subsErr } = await admin
    .from("subscriptions")
    .select("id, plan_id, status, provider_subscription_id, current_period_end")
    .eq("teacher_id", user.id)
    .eq("provider", "asaas")
    .in("status", ["pending", "active", "past_due"]);
  if (subsErr) {
    console.error("billing-cancel: leitura das assinaturas", subsErr);
    return fail(502, "read", BILLING_MESSAGES.failed);
  }
  const targets = (subs ?? []).filter((s) => s.provider_subscription_id);
  if (targets.length === 0) {
    return fail(404, "no_subscription", "Você não tem assinatura com renovação automática.");
  }

  try {
    for (const sub of targets) {
      try {
        await asaas(cfg, "DELETE", `/subscriptions/${sub.provider_subscription_id}`);
      } catch (e) {
        // Já removida no Asaas: segue para encerrar aqui também.
        if (!(e instanceof AsaasError && e.status === 404)) throw e;
      }
      const { error } = await admin.rpc("billing_subscription_ended", {
        p_provider_subscription: sub.provider_subscription_id,
        p_revoke: false,
      });
      if (error) throw error;
    }
  } catch (e) {
    console.error("billing-cancel:", e);
    return fail(502, "asaas", BILLING_MESSAGES.failed);
  }

  const live = targets.find((s) => s.status !== "pending");
  const { data: planRow } = live
    ? await admin.from("plans").select("name").eq("id", live.plan_id).maybeSingle()
    : { data: null };
  const planName = (planRow?.name as string | undefined) ?? "";
  return json(200, {
    message: live
      ? `Renovação cancelada. O plano ${planName} vale até ` +
        `${dateBr(live.current_period_end as string | null)}; depois, sua conta volta ao Free.`
      : "Pagamento em aberto cancelado.",
  });
});
