// Edge Function: billing-checkout
//
// O professor pede um plano pago pelo app. Desligada até a conta do Asaas
// existir (sem ASAAS_API_KEY responde 503 "em breve"; o app só mostra o
// botão com BILLING_ENABLED).
//
// Casos:
//   - Sem assinatura paga (Free ou plano manual): cria a assinatura mensal no
//     Asaas e devolve a página de pagamento do 1º mês. O plano vale quando o
//     pagamento é confirmado (billing-webhook).
//   - Assinatura paga, plano MAIOR: cobra só a diferença proporcional aos
//     dias que faltam; paga, o plano novo vale na hora e as renovações
//     passam para o preço novo.
//   - Assinatura paga, plano MENOR: agenda a mudança para a renovação (o
//     plano atual vale até o fim do período pago). Nada é cobrado agora.
//   - Mesmo plano com redução agendada: desfaz a redução.
//
// Respostas: 200 { invoiceUrl?, message? } · 4xx/5xx { error, code }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  asaas,
  asaasConfig,
  type AsaasConfig,
  AsaasError,
  BILLING_MESSAGES,
  reais,
  todaySaoPaulo,
  upgradeCents,
  validCpfCnpj,
} from "../_shared/asaas.ts";

type AdminClient = ReturnType<typeof createClient>;

interface PlanRow {
  id: string;
  name: string;
  price_cents: number;
  sort_order: number;
}

interface SubscriptionRow {
  id: string;
  plan_id: string;
  next_plan_id: string | null;
  status: string;
  provider: string;
  provider_customer_id: string | null;
  provider_subscription_id: string | null;
  current_period_end: string | null;
}

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

function money(cents: number): string {
  return `R$ ${(cents / 100).toFixed(2).replace(".", ",")}`;
}

/** Cliente do professor no Asaas: cria na 1ª vez, atualiza nome/documento. */
async function ensureCustomer(
  cfg: AsaasConfig,
  admin: AdminClient,
  teacher: { id: string; email: string },
  name: string,
  cpfCnpj: string,
): Promise<string> {
  const { data: existing } = await admin
    .from("billing_customers")
    .select("provider_customer_id")
    .eq("teacher_id", teacher.id)
    .maybeSingle();
  if (existing?.provider_customer_id) {
    const id = existing.provider_customer_id as string;
    await asaas(cfg, "POST", `/customers/${id}`, { name, cpfCnpj });
    return id;
  }
  const customer = await asaas<{ id: string }>(cfg, "POST", "/customers", {
    name,
    cpfCnpj,
    email: teacher.email,
    externalReference: teacher.id,
  });
  const { error } = await admin.from("billing_customers").insert({
    teacher_id: teacher.id,
    provider_customer_id: customer.id,
  });
  if (error) {
    // Outro pedido simultâneo criou primeiro: fica o que está no banco.
    const { data: again } = await admin
      .from("billing_customers")
      .select("provider_customer_id")
      .eq("teacher_id", teacher.id)
      .single();
    return again!.provider_customer_id as string;
  }
  return customer.id;
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
  const { data: profile } = await userClient
    .from("profiles").select("role").eq("id", user.id).single();
  if (!profile || (profile.role !== "teacher" && profile.role !== "admin")) {
    return fail(403, "forbidden", "Apenas professores podem assinar planos.");
  }

  const cfg = asaasConfig();
  if (!cfg) return fail(503, "billing_disabled", BILLING_MESSAGES.disabled);

  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const billingType = body.billingType;
  if (billingType !== "PIX" && billingType !== "CREDIT_CARD") {
    return fail(400, "billing_type", "Escolha Pix ou cartão de crédito.");
  }
  const name = typeof body.name === "string" ? body.name.trim().replace(/\s+/g, " ") : "";
  if (name.length < 3 || name.length > 120) {
    return fail(400, "name", "Informe o nome que vai na cobrança.");
  }
  const cpfCnpj = validCpfCnpj(typeof body.cpfCnpj === "string" ? body.cpfCnpj : "");
  if (!cpfCnpj) return fail(400, "cpf_cnpj", "CPF ou CNPJ inválido. Confira os números.");

  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: plans } = await admin
    .from("plans").select("id, name, price_cents, sort_order");
  const planById = new Map((plans as PlanRow[] ?? []).map((p) => [p.id, p]));
  const plan = planById.get(String(body.planId));
  if (!plan || plan.price_cents <= 0) return fail(400, "plan", "Plano inválido.");

  const { data: subsData } = await admin
    .from("subscriptions")
    .select("id, plan_id, next_plan_id, status, provider, provider_customer_id, provider_subscription_id, current_period_end")
    .eq("teacher_id", user.id)
    .in("status", ["pending", "active", "past_due"]);
  const subs = (subsData ?? []) as SubscriptionRow[];
  const live = subs.find((s) => s.status === "active" || s.status === "past_due");
  const pending = subs.find((s) => s.status === "pending");

  try {
    // ── Mudança de plano numa assinatura paga ──────────────────────────
    if (live && live.provider === "asaas" && live.provider_subscription_id) {
      const current = planById.get(live.plan_id)!;
      const subPath = `/subscriptions/${live.provider_subscription_id}`;

      if (plan.id === live.plan_id) {
        if (!live.next_plan_id) {
          return fail(409, "same_plan", `Você já assina o plano ${plan.name}.`);
        }
        await asaas(cfg, "POST", subPath, {
          value: reais(current.price_cents),
          updatePendingPayments: true,
        });
        await admin.from("subscriptions").update({ next_plan_id: null }).eq("id", live.id);
        return json(200, {
          message: `Mudança cancelada: você continua no plano ${plan.name}.`,
        });
      }

      if (plan.sort_order < current.sort_order) {
        await asaas(cfg, "POST", subPath, {
          value: reais(plan.price_cents),
          description: `Arcangel — plano ${plan.name}`,
          updatePendingPayments: true,
        });
        await admin.from("subscriptions").update({ next_plan_id: plan.id }).eq("id", live.id);
        return json(200, {
          message: `Combinado: na renovação de ${dateBr(live.current_period_end)}, ` +
            `sua assinatura muda para o plano ${plan.name}. Até lá, o ` +
            `${current.name} continua valendo.`,
        });
      }

      const cents = upgradeCents(
        current.price_cents,
        plan.price_cents,
        new Date(live.current_period_end ?? Date.now()),
      );
      const customer = live.provider_customer_id ??
        await ensureCustomer(cfg, admin, { id: user.id, email: user.email ?? "" }, name, cpfCnpj);
      const payment = await asaas<{ invoiceUrl: string }>(cfg, "POST", "/payments", {
        customer,
        billingType,
        value: reais(cents),
        dueDate: todaySaoPaulo(),
        description: `Arcangel — mudança para o plano ${plan.name} (proporcional)`,
        externalReference: `upgrade:${live.id}:${plan.id}`,
      });
      await admin.from("subscriptions").update({ invoice_url: payment.invoiceUrl }).eq("id", live.id);
      return json(200, {
        invoiceUrl: payment.invoiceUrl,
        message: `Pague ${money(cents)} (diferença proporcional) e o plano ` +
          `${plan.name} vale assim que o pagamento for confirmado.`,
      });
    }

    // ── Nova assinatura (Free ou plano manual) ─────────────────────────
    // Um pedido em aberto é trocado pelo novo (outro plano ou forma de
    // pagamento).
    if (pending) {
      if (pending.provider_subscription_id) {
        await asaas(cfg, "DELETE", `/subscriptions/${pending.provider_subscription_id}`)
          .catch((e) => console.error("billing-checkout: cancelar pendente", e));
      }
      const now = new Date().toISOString();
      await admin.from("subscriptions")
        .update({ status: "canceled", canceled_at: now, current_period_end: now, invoice_url: null })
        .eq("id", pending.id).eq("status", "pending");
    }

    const customer = await ensureCustomer(
      cfg, admin, { id: user.id, email: user.email ?? "" }, name, cpfCnpj,
    );
    const { data: row, error: insertErr } = await admin
      .from("subscriptions")
      .insert({
        teacher_id: user.id,
        plan_id: plan.id,
        status: "pending",
        provider: "asaas",
        billing_type: billingType,
        provider_customer_id: customer,
      })
      .select("id")
      .single();
    if (insertErr || !row) {
      return fail(409, "pending_exists", "Já existe um pagamento em andamento. Recarregue a página.");
    }

    let subscriptionId: string | null = null;
    try {
      const sub = await asaas<{ id: string }>(cfg, "POST", "/subscriptions", {
        customer,
        billingType,
        value: reais(plan.price_cents),
        nextDueDate: todaySaoPaulo(),
        cycle: "MONTHLY",
        description: `Arcangel — plano ${plan.name}`,
        externalReference: row.id,
      });
      subscriptionId = sub.id;
      const payments = await asaas<{ data?: Array<{ invoiceUrl?: string }> }>(
        cfg, "GET", `/subscriptions/${sub.id}/payments`,
      );
      const invoiceUrl = payments.data?.[0]?.invoiceUrl ?? null;
      await admin.from("subscriptions").update({
        provider_subscription_id: sub.id,
        invoice_url: invoiceUrl,
      }).eq("id", row.id);
      return json(200, { invoiceUrl });
    } catch (e) {
      // Sem assinatura completa, nada fica pela metade.
      if (subscriptionId) {
        await asaas(cfg, "DELETE", `/subscriptions/${subscriptionId}`).catch(() => {});
      }
      await admin.from("subscriptions").delete().eq("id", row.id);
      throw e;
    }
  } catch (e) {
    console.error("billing-checkout:", e);
    if (e instanceof AsaasError && e.status === 400 && e.description) {
      return fail(400, "asaas", e.description);
    }
    return fail(502, "asaas", BILLING_MESSAGES.failed);
  }
});
