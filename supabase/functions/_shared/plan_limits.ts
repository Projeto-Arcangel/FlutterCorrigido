// Limites mensais dos planos nas Edge Functions.
//
// Antes de gastar com a IA, a função reserva o uso (RPC plan_reserve, com
// trava por professor: pedidos simultâneos não passam do limite). Depois de
// registrar o resultado no log, libera a reserva (plan_release). Se a função
// cair no meio, a reserva expira sozinha em 5 minutos.
//
// Sem conseguir consultar o plano, a função RECUSA (fail-closed): o limite
// protege o custo da IA.

import type { createClient } from "jsr:@supabase/supabase-js@2";

type AdminClient = ReturnType<typeof createClient>;

export type PlanResource = "topic" | "materials" | "video_minutes";

export interface PlanReservation {
  ok: boolean;
  reason?: "limit" | "model";
  hold?: string;
  plan: string;
  plan_name: string;
  allowed_models?: string[];
  limit?: number;
  used?: number;
  remaining?: number;
  /** Quando o período de uso renova (um mês depois do início do plano). */
  period_end?: string;
}

/** Rótulos dos modelos (iguais aos do app, IaModelOption). */
export const MODEL_LABELS: Record<string, string> = {
  "gemini-flash": "Gemini Flash",
  "gpt-mini": "GPT Mini",
  "claude-haiku": "Claude Haiku",
};

export const PLAN_MESSAGES = {
  unavailable:
    "Não consegui conferir os limites do seu plano agora. Tente de novo em instantes.",
};

export class PlanCheckError extends Error {
  constructor() {
    super(PLAN_MESSAGES.unavailable);
    this.name = "PlanCheckError";
  }
}

/** Lança [PlanCheckError] se a consulta falhar. */
export async function reservePlanUsage(
  admin: AdminClient,
  teacherId: string,
  resource: PlanResource,
  amount: number,
  model?: string,
): Promise<PlanReservation> {
  const { data, error } = await admin.rpc("plan_reserve", {
    p_teacher: teacherId,
    p_resource: resource,
    p_amount: amount,
    p_model: model ?? null,
  });
  if (error || !data || typeof data !== "object") {
    console.error("plan_reserve falhou:", error?.message ?? data);
    throw new PlanCheckError();
  }
  return data as PlanReservation;
}

/** Best-effort: a reserva expira sozinha se isto falhar. */
export async function releasePlanUsage(
  admin: AdminClient,
  hold: string | undefined,
): Promise<void> {
  if (!hold) return;
  try {
    const { error } = await admin.rpc("plan_release", { p_hold: hold });
    if (error) console.error("plan_release falhou:", error.message);
  } catch (e) {
    console.error("plan_release falhou:", e);
  }
}

const MONTHS = [
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
];

/**
 * "12 de novembro às 15h04": quando o período de uso renova (um mês depois
 * do início do plano, fuso de SP).
 */
export function resetLabel(periodEnd: string | undefined): string {
  const date = periodEnd ? new Date(periodEnd) : null;
  if (!date || Number.isNaN(date.getTime())) return "no próximo período";
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Sao_Paulo",
      day: "numeric",
      month: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hourCycle: "h23",
    }).formatToParts(date).map((p) => [p.type, p.value]),
  );
  const day = parts.day === "1" ? "1º" : parts.day;
  return `${day} de ${MONTHS[Number(parts.month) - 1]} às ${Number(parts.hour)}h${parts.minute}`;
}

const RESOURCE_TEXT: Record<"topic" | "materials", string> = {
  topic: "questões por tema",
  materials: "questões com materiais",
};

/** Mensagem para o professor quando a geração de questões é recusada. */
export function questionLimitMessage(
  r: PlanReservation,
  resource: "topic" | "materials",
  model: string,
  /** Quanto cada questão pedida conta (cruzadinha = 3). */
  weight = 1,
): string {
  if (r.reason === "model") {
    return `O ${MODEL_LABELS[model] ?? model} está disponível nos planos Pro e Premium. ` +
      "Escolha outro modelo para gerar no seu plano.";
  }
  const what = RESOURCE_TEXT[resource];
  const remaining = r.remaining ?? 0;
  const when = resetLabel(r.period_end);
  const renew = `Elas renovam em ${when} — ou mude de plano para gerar mais.`;
  if (remaining <= 0) {
    return `Você usou as ${r.limit} ${what} do plano ${r.plan_name}. ${renew}`;
  }
  if (weight > 1) {
    const fits = Math.floor(remaining / weight);
    return `Restam ${remaining} ${what} no plano ${r.plan_name} até ${when}, e cada ` +
      `cruzadinha conta ${weight}. ` +
      (fits > 0 ? `Peça ${fits} cruzadinha${fits > 1 ? "s" : ""} ou menos.` : renew);
  }
  return `Restam ${remaining} ${what} no plano ${r.plan_name} até ${when}. ` +
    `Peça ${remaining} ou menos.`;
}

/** Mensagem quando o vídeo não cabe nos minutos que restam. */
export function videoLimitMessage(r: PlanReservation, minutesNeeded: number): string {
  const remaining = r.remaining ?? 0;
  const when = resetLabel(r.period_end);
  const head = remaining <= 0
    ? `Você usou os ${r.limit} minutos de vídeo do plano ${r.plan_name}.`
    : `Ler este vídeo usa ${minutesNeeded} min e restam ${remaining} min de vídeo ` +
      `no seu plano ${r.plan_name}.`;
  return `${head} Os minutos renovam em ${when} — ou mude de plano, ou anexe o ` +
    "conteúdo em PDF, Word ou PowerPoint.";
}
