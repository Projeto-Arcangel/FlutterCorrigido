// Cliente mínimo da API do Asaas (cobranças recorrentes por Pix e cartão).
//
// Configuração (supabase secrets set / supabase/functions/.env):
//   ASAAS_API_KEY        chave da conta (sem ela, o pagamento pelo app fica
//                        desligado e as funções respondem "em breve")
//   ASAAS_BASE_URL       https://api.asaas.com/v3 (produção) ou
//                        https://api-sandbox.asaas.com/v3 (testes; padrão)
//   ASAAS_WEBHOOK_TOKEN  token configurado no webhook do painel do Asaas
//
// Os dados do cartão nunca passam por aqui: o professor paga na página de
// cobrança do Asaas (invoiceUrl), que também guarda o cartão para as
// renovações.

export const BILLING_MESSAGES = {
  disabled:
    "O pagamento pelo app chega em breve. Por enquanto, peça seu plano pelo " +
    "e-mail arcangel.admin@gmail.com, informando o e-mail da sua conta.",
  failed:
    "Não foi possível falar com o serviço de pagamentos agora. Tente de novo " +
    "em instantes.",
};

export interface AsaasConfig {
  apiKey: string;
  baseUrl: string;
}

/** null = pagamento pelo app desligado (conta do Asaas ainda não existe). */
export function asaasConfig(): AsaasConfig | null {
  const apiKey = Deno.env.get("ASAAS_API_KEY")?.trim();
  if (!apiKey) return null;
  const baseUrl = (Deno.env.get("ASAAS_BASE_URL")?.trim() ||
    "https://api-sandbox.asaas.com/v3").replace(/\/+$/, "");
  return { apiKey, baseUrl };
}

export class AsaasError extends Error {
  constructor(public status: number, public detail: string) {
    super(`Asaas HTTP ${status}: ${detail.slice(0, 300)}`);
    this.name = "AsaasError";
  }

  /** Primeira descrição de erro do Asaas (já vem em português). */
  get description(): string | null {
    try {
      const body = JSON.parse(this.detail) as {
        errors?: Array<{ description?: string }>;
      };
      return body.errors?.[0]?.description ?? null;
    } catch (_e) {
      return null;
    }
  }
}

export async function asaas<T = Record<string, unknown>>(
  cfg: AsaasConfig,
  method: "GET" | "POST" | "DELETE",
  path: string,
  body?: unknown,
): Promise<T> {
  const resp = await fetch(`${cfg.baseUrl}${path}`, {
    method,
    signal: AbortSignal.timeout(20_000),
    headers: {
      "access_token": cfg.apiKey,
      "Content-Type": "application/json",
      // O Asaas exige User-Agent nas contas novas.
      "User-Agent": "Arcangel",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await resp.text();
  if (!resp.ok) throw new AsaasError(resp.status, text);
  return (text ? JSON.parse(text) : {}) as T;
}

/** "AAAA-MM-DD" de hoje no fuso de SP (vencimentos do Asaas). */
export function todaySaoPaulo(now = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Reais com 2 casas a partir de centavos (o Asaas recebe reais). */
export function reais(cents: number): number {
  return Math.round(cents) / 100;
}

/** Só dígitos; valida os dígitos verificadores de CPF (11) e CNPJ (14). */
export function validCpfCnpj(value: string): string | null {
  const d = value.replace(/\D/g, "");
  if (/^(\d)\1+$/.test(d)) return null;
  const n = (i: number) => Number(d[i]);
  if (d.length === 11) {
    const check = (len: number) => {
      let sum = 0;
      for (let i = 0; i < len; i++) sum += n(i) * (len + 1 - i);
      const rest = (sum * 10) % 11;
      return rest === 10 ? 0 : rest;
    };
    return check(9) === n(9) && check(10) === n(10) ? d : null;
  }
  if (d.length === 14) {
    const check = (weights: number[]) => {
      const sum = weights.reduce((acc, w, i) => acc + n(i) * w, 0);
      const rest = sum % 11;
      return rest < 2 ? 0 : 11 - rest;
    };
    const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const w2 = [6, ...w1];
    return check(w1) === n(12) && check(w2) === n(13) ? d : null;
  }
  return null;
}

/**
 * Diferença a pagar para subir de plano no meio do período: proporcional
 * aos dias que faltam (período de 30 dias), com mínimo de R$ 5,00 (menor
 * cobrança aceita pelo Asaas).
 */
export function upgradeCents(
  currentCents: number,
  newCents: number,
  periodEnd: Date,
  now = new Date(),
): number {
  const msLeft = Math.max(0, periodEnd.getTime() - now.getTime());
  const fraction = Math.min(1, msLeft / (30 * 24 * 60 * 60 * 1000));
  return Math.max(500, Math.round((newCents - currentCents) * fraction));
}

/** Comparação em tempo constante (token do webhook). */
export function safeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  let diff = ea.length ^ eb.length;
  for (let i = 0; i < Math.max(ea.length, eb.length); i++) {
    diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0);
  }
  return diff === 0;
}
