// Edge Function: generate-questions
// Substitui a Cloud Function `generateQuestionsAI` (firebase/functions/index.js).
//
// Fluxo:
//   1. Valida o JWT do usuário (header Authorization).
//   2. Exige role 'teacher' (ou 'admin') em public.profiles.
//   3. Valida o input e chama o OpenRouter com fallback (../_shared/openrouter.ts).
//   4. Audita o resultado em ai_generation_logs (via service_role, ignora RLS).
//
// Segredo: OPENROUTER_API_KEY (supabase secrets set / .env local).
// SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY são injetados
// automaticamente pelo runtime do Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  generateQuestionsWithFallback,
  GenerationError,
  type GenerateResult,
} from "../_shared/openrouter.ts";

// Teto diário de questões geradas por IA por professor (controle de custo no
// OpenRouter). A contagem do uso de hoje vem da RPC ai_questions_today
// (migration 20260607120000) — aqui fica só o valor do teto.
const DAILY_QUESTION_LIMIT = 20;

type AdminClient = ReturnType<typeof createClient>;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function logGeneration(
  admin: AdminClient,
  teacherId: string,
  body: Record<string, unknown>,
  result: GenerateResult | null,
  status: "success" | "error",
  errMessage: string | null,
  attempts: unknown,
): Promise<void> {
  try {
    await admin.from("ai_generation_logs").insert({
      teacher_id: teacherId,
      subject: (body.subject as string) ?? null,
      topic: (body.topic as string) ?? "",
      difficulty: (body.difficulty as string) ?? null,
      quantity: body.quantity != null ? Number(body.quantity) : null,
      model_requested: (body.modelKey as string) ?? null,
      model_used: result?.modelUsed ?? null,
      status,
      attempts: result?.attempts ?? attempts ?? null,
      error_message: errMessage,
    });
  } catch (_e) {
    // Auditoria é best-effort: nunca derruba a request por causa do log.
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json(405, { error: "Método não permitido." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // 1. Autenticação — cliente com o JWT do chamador.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return json(401, { error: "Não autenticado." });

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return json(401, { error: "Não autenticado." });

  // 2. Só professores.
  const { data: profile } = await userClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile || (profile.role !== "teacher" && profile.role !== "admin")) {
    return json(403, { error: "Apenas professores podem gerar questões com IA." });
  }

  // 3. Validação superficial do input.
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  if (!body.topic || typeof body.topic !== "string") {
    return json(400, { error: "O tema é obrigatório." });
  }

  // Quantidade precisa ser conhecida ANTES de gerar para checar a cota diária.
  // (a validação completa do payload ainda ocorre em generateQuestionsWithFallback)
  const requested = Number(body.quantity);
  if (!Number.isInteger(requested) || requested < 1 || requested > 20) {
    return json(400, { error: "A quantidade deve ser um inteiro entre 1 e 20." });
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return json(500, { error: "OPENROUTER_API_KEY não configurada no servidor." });
  }

  // Cliente service_role (ignora RLS): usado para a cota diária e a auditoria.
  const admin = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 4. Rate-limit: teto diário de questões por professor (custo no OpenRouter).
  // Em caso de falha na consulta, deixamos passar (fail-open) — o limite é um
  // controle de custo, não uma fronteira de segurança; preferimos não derrubar
  // a geração por um erro transitório de leitura do contador.
  const { data: usedToday, error: quotaErr } = await admin.rpc(
    "ai_questions_today",
    { p_teacher: user.id },
  );
  if (!quotaErr && typeof usedToday === "number") {
    const remaining = DAILY_QUESTION_LIMIT - usedToday;
    if (requested > remaining) {
      return json(429, {
        error: remaining > 0
          ? `Limite diário de IA: ${DAILY_QUESTION_LIMIT} questões/dia. Você já gerou ${usedToday} hoje e ainda pode gerar ${remaining}. Reduza a quantidade ou tente amanhã.`
          : `Limite diário de IA atingido (${DAILY_QUESTION_LIMIT} questões/dia). Você já gerou ${usedToday} hoje. Tente novamente amanhã.`,
        limit: DAILY_QUESTION_LIMIT,
        used: usedToday,
        remaining: Math.max(0, remaining),
      });
    }
  }

  // 5. Geração com fallback + auditoria.
  try {
    const result = await generateQuestionsWithFallback({
      subject: body.subject as string | undefined,
      topic: body.topic,
      difficulty: body.difficulty as string | undefined,
      quantity: Number(body.quantity),
      alternatives: body.alternatives != null ? Number(body.alternatives) : undefined,
      description: body.description as string | undefined,
      modelKey: body.modelKey as string | undefined,
    }, apiKey);

    await logGeneration(admin, user.id, body, result, "success", null, null);
    return json(200, result);
  } catch (err) {
    const attempts = err instanceof GenerationError ? err.attempts : null;
    const message = err instanceof Error ? err.message : "Falha ao gerar questões.";
    await logGeneration(admin, user.id, body, null, "error", message, attempts);
    return json(500, { error: message, attempts });
  }
});
