// Edge Function: generate-questions
// Gera questões com IA para o professor, por tema ou a partir dos materiais.
//
// Fluxo:
//   1. Valida o JWT do usuário (header Authorization).
//   2. Exige role 'teacher' (ou 'admin') em public.profiles.
//   3. Valida o input e chama o OpenRouter com fallback (../_shared/openrouter.ts).
//      Dois modos: por tema (`topic`) ou a partir dos materiais do professor
//      (`materials`: texto já extraído no navegador — o arquivo não vem).
//   4. Reserva o uso no limite mensal do plano (_shared/plan_limits.ts) —
//      inclui o modelo: GPT Mini só nos planos pagos.
//   5. Audita o resultado em ai_generation_logs (via service_role, ignora RLS),
//      com a origem (`source`) e só metadados dos materiais; depois libera a
//      reserva (o uso passa a contar pelo log).
//
// Segredo: OPENROUTER_API_KEY (supabase secrets set / .env local).
// SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_SERVICE_ROLE_KEY são injetados
// automaticamente pelo runtime do Supabase.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  ALLOWED_MODELS,
  generateQuestionsWithFallback,
  GenerationError,
  type GenerateResult,
  planWeight,
  QUESTION_TYPES,
  type QuestionType,
  type MaterialInput,
  type Usage,
  validateMaterials,
} from "../_shared/openrouter.ts";
import {
  PlanCheckError,
  type PlanReservation,
  questionLimitMessage,
  releasePlanUsage,
  reservePlanUsage,
} from "../_shared/plan_limits.ts";

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
  usage: Usage | null,
): Promise<void> {
  const materials = Array.isArray(body.materials)
    ? (body.materials as Array<Partial<MaterialInput> & { coverage?: unknown }>)
    : null;
  const topic = typeof body.topic === "string" ? body.topic.trim() : "";
  try {
    await admin.from("ai_generation_logs").insert({
      teacher_id: teacherId,
      subject: (body.subject as string) ?? null,
      // Com materiais não há tema: registra os nomes dos arquivos.
      topic: topic ||
        (materials
          ? `Materiais: ${materials.map((m) => String(m.name ?? "")).join(", ")}`
            .slice(0, 300)
          : ""),
      source: materials ? "materials" : "topic",
      // Só metadados — o conteúdo dos materiais nunca é gravado.
      materials: materials?.map((m) => ({
        name: String(m.name ?? "").slice(0, 200),
        kind: m.kind ?? null,
        chars: typeof m.text === "string" ? m.text.length : 0,
        coverage: typeof m.coverage === "number" ? m.coverage : null,
      })) ?? null,
      difficulty: (body.difficulty as string) ?? null,
      quantity: body.quantity != null ? Number(body.quantity) : null,
      // Quanto contou no limite (cruzadinha = 3 por questão).
      question_type: typeof body.questionType === "string" ? body.questionType : "multiple_choice",
      charged: body.quantity != null
        ? Number(body.quantity) * planWeight(String(body.questionType ?? ""))
        : null,
      model_requested: (body.modelKey as string) ?? null,
      model_used: result?.modelUsed ?? null,
      status,
      attempts: result?.attempts ?? attempts ?? null,
      error_message: errMessage,
      // Consumo real (tokens e custo em US$) — base para dimensionar planos.
      input_tokens: usage?.inputTokens ?? null,
      output_tokens: usage?.outputTokens ?? null,
      cost_usd: usage ? Number(usage.costUsd.toFixed(6)) : null,
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

  // 3. Validação superficial do input (antes de gastar cota).
  const body = await req.json().catch(() => ({})) as Record<string, unknown>;
  const fromMaterials = body.materials !== undefined;
  if (fromMaterials) {
    try {
      validateMaterials(body.materials);
    } catch (e) {
      return json(400, { error: (e as Error).message });
    }
  } else if (!body.topic || typeof body.topic !== "string") {
    return json(400, { error: "O tema é obrigatório." });
  }

  // Quantidade e modelo precisam ser conhecidos ANTES de gerar, para a
  // reserva no plano. (a validação completa do payload ainda ocorre em
  // generateQuestionsWithFallback)
  const requested = Number(body.quantity);
  if (!Number.isInteger(requested) || requested < 1 || requested > 20) {
    return json(400, { error: "A quantidade deve ser um inteiro entre 1 e 20." });
  }
  const modelKey = body.modelKey === undefined ? "gemini-flash" : body.modelKey;
  if (typeof modelKey !== "string" || !ALLOWED_MODELS[modelKey]) {
    return json(400, { error: `Modelo "${String(modelKey)}" não é permitido.` });
  }
  // Tipo das questões (um dos seis do app).
  const questionType = body.questionType === undefined ? "multiple_choice" : body.questionType;
  if (
    typeof questionType !== "string" ||
    !(QUESTION_TYPES as readonly string[]).includes(questionType)
  ) {
    return json(400, { error: `Tipo de questão "${String(questionType)}" não é permitido.` });
  }
  // Cruzadinha é a mais pesada: conta 3 no limite e vai até 5 por vez.
  const weight = planWeight(questionType);
  if (questionType === "crossword" && requested > 5) {
    return json(400, { error: "Gere até 5 cruzadinhas por vez." });
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) {
    return json(500, { error: "OPENROUTER_API_KEY não configurada no servidor." });
  }

  // Cliente service_role (ignora RLS): usado para o plano e a auditoria.
  const admin = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 4. Limite mensal do plano. Sem conseguir consultar, recusa: o limite
  // protege o custo da IA.
  const resource = fromMaterials ? "materials" : "topic";
  let reservation: PlanReservation;
  try {
    reservation = await reservePlanUsage(admin, user.id, resource, requested * weight, modelKey);
  } catch (e) {
    if (e instanceof PlanCheckError) return json(503, { error: e.message, code: "plan_unavailable" });
    throw e;
  }
  if (!reservation.ok) {
    return json(reservation.reason === "model" ? 403 : 429, {
      error: questionLimitMessage(reservation, resource, modelKey, weight),
      code: reservation.reason === "model" ? "plan_model" : "plan_limit",
      plan: reservation.plan,
      limit: reservation.limit,
      used: reservation.used,
      remaining: reservation.remaining,
    });
  }

  // 5. Geração com fallback (só modelos do plano) + auditoria. A reserva sai
  // depois do log: até lá, o uso conta pela reserva.
  try {
    const result = await generateQuestionsWithFallback({
      subject: body.subject as string | undefined,
      topic: typeof body.topic === "string" ? body.topic : "",
      difficulty: body.difficulty as string | undefined,
      quantity: Number(body.quantity),
      alternatives: body.alternatives != null ? Number(body.alternatives) : undefined,
      description: body.description as string | undefined,
      modelKey,
      questionType: questionType as QuestionType,
      // Só nome, tipo e texto vão para o prompt (coverage é só para o log).
      materials: fromMaterials
        ? (body.materials as MaterialInput[]).map(({ name, kind, text }) => ({
          name,
          kind,
          text,
        }))
        : undefined,
    }, apiKey, reservation.allowed_models);

    await logGeneration(admin, user.id, body, result, "success", null, null, result.usage);
    return json(200, result);
  } catch (err) {
    const attempts = err instanceof GenerationError ? err.attempts : null;
    const usage = err instanceof GenerationError ? err.usage : null;
    const message = err instanceof Error ? err.message : "Falha ao gerar questões.";
    await logGeneration(admin, user.id, body, null, "error", message, attempts, usage);
    return json(500, { error: message, attempts });
  } finally {
    await releasePlanUsage(admin, reservation.hold);
  }
});
