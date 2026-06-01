// Port de firebase/functions/openrouter.js para Deno/TypeScript.
// Mantém ALLOWED_MODELS, FALLBACK_ORDER, o prompt e a validação idênticos.

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const REQUEST_TIMEOUT_MS = 60_000;

// A whitelist DEVE espelhar IaModelOption (lib/.../ia_model_option.dart).
export const ALLOWED_MODELS: Record<string, string> = {
  "gemini-flash": "google/gemini-3.1-flash-lite",
  "gpt-mini": "openai/gpt-5.4-mini",
  "claude-haiku": "~anthropic/claude-haiku-latest",
};

export const FALLBACK_ORDER = ["gemini-flash", "gpt-mini", "claude-haiku"];

const DIFFICULTY_LABELS: Record<string, string> = {
  easy: "Fácil — conceitos introdutórios, sem necessidade de análise profunda",
  medium: "Médio — exige compreensão e relacionamento de conceitos",
  hard: "Difícil — exige análise crítica e relacionamento entre eventos",
  expert:
    "Expert — exige interpretação avançada, fontes primárias e raciocínio histórico complexo",
};

export interface GenerateInput {
  subject?: string;
  topic: string;
  difficulty?: string;
  quantity?: number;
  description?: string;
  modelKey?: string;
}

export interface GeneratedQuestion {
  text: string;
  options: string[];
  correctAnswer: number;
  explanation: string;
}

export interface Attempt {
  model: string;
  status: "success" | "error";
  message?: string;
}

export interface GenerateResult {
  questions: GeneratedQuestion[];
  modelUsed: string;
  modelIdUsed: string;
  attempts: Attempt[];
}

export class GenerationError extends Error {
  attempts: Attempt[];
  constructor(message: string, attempts: Attempt[]) {
    super(message);
    this.name = "GenerationError";
    this.attempts = attempts;
  }
}

function buildPrompt(
  { subject, topic, difficulty, quantity, description }: Required<
    Pick<GenerateInput, "subject" | "topic" | "quantity">
  > & { difficulty: string; description: string },
): string {
  const difficultyLabel = DIFFICULTY_LABELS[difficulty] ?? difficulty;
  const extraInstructions = description && description.trim().length > 0
    ? `\n\nInstruções adicionais do professor:\n${description.trim()}`
    : "";

  return `Você é um professor especialista em ${subject} para o ensino fundamental e médio brasileiro.

Gere exatamente ${quantity} questões de múltipla escolha sobre o tema: "${topic}".

Nível de dificuldade: ${difficultyLabel}.${extraInstructions}

Regras obrigatórias:
- Cada questão deve ter exatamente 4 alternativas.
- Apenas 1 alternativa correta por questão.
- O índice da resposta correta vai de 0 a 3 (0 = primeira alternativa).
- A explicação deve justificar a resposta correta de forma pedagógica, em até 2 frases.
- Todo o conteúdo deve estar em português do Brasil.
- Evite ambiguidades e questões com mais de uma resposta defensável.

Responda APENAS com um JSON válido no formato exato:
{
  "questions": [
    {
      "text": "enunciado da questão",
      "options": ["alternativa A", "alternativa B", "alternativa C", "alternativa D"],
      "correctAnswer": 0,
      "explanation": "justificativa pedagógica da resposta correta"
    }
  ]
}

Não inclua texto antes nem depois do JSON. Não use markdown.`;
}

async function callOpenRouter(
  { modelId, prompt, apiKey }: { modelId: string; prompt: string; apiKey: string },
): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const resp = await fetch(OPENROUTER_URL, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://arcangel-4c066.web.app",
        "X-Title": "Arcangel",
      },
      body: JSON.stringify({
        model: modelId,
        messages: [{ role: "user", content: prompt }],
        response_format: { type: "json_object" },
        temperature: 0.7,
      }),
    });

    if (!resp.ok) {
      const errBody = await resp.text().catch(() => "");
      throw new Error(`OpenRouter HTTP ${resp.status}: ${errBody.slice(0, 200)}`);
    }

    const data = await resp.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) throw new Error("Resposta da IA veio vazia.");
    return content as string;
  } finally {
    clearTimeout(timer);
  }
}

function parseAndValidate(raw: string): GeneratedQuestion[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (_e) {
    throw new Error("A IA retornou um JSON inválido.");
  }

  const questions = (parsed as { questions?: unknown })?.questions;
  if (!Array.isArray(questions) || questions.length === 0) {
    throw new Error("A IA não retornou nenhuma questão.");
  }

  return questions.map((q: any, idx: number): GeneratedQuestion => {
    if (typeof q.text !== "string" || q.text.trim().length === 0) {
      throw new Error(`Questão ${idx + 1} sem enunciado válido.`);
    }
    if (!Array.isArray(q.options) || q.options.length !== 4) {
      throw new Error(`Questão ${idx + 1} não tem exatamente 4 alternativas.`);
    }
    if (q.options.some((o: unknown) => typeof o !== "string" || o.trim().length === 0)) {
      throw new Error(`Questão ${idx + 1} tem alternativa vazia.`);
    }
    const correct = Number(q.correctAnswer);
    if (!Number.isInteger(correct) || correct < 0 || correct > 3) {
      throw new Error(`Questão ${idx + 1} tem correctAnswer inválido (esperado 0-3).`);
    }
    return {
      text: q.text.trim(),
      options: q.options.map((o: string) => o.trim()),
      correctAnswer: correct,
      explanation: typeof q.explanation === "string" ? q.explanation.trim() : "",
    };
  });
}

function buildAttemptQueue(preferredModelKey: string): string[] {
  const queue = [preferredModelKey];
  for (const m of FALLBACK_ORDER) {
    if (!queue.includes(m)) queue.push(m);
  }
  return queue;
}

export async function generateQuestionsWithFallback(
  input: GenerateInput,
  apiKey: string,
): Promise<GenerateResult> {
  const {
    subject = "História do Brasil",
    topic,
    difficulty = "medium",
    quantity = 5,
    description = "",
    modelKey = "gemini-flash",
  } = input;

  if (!topic || typeof topic !== "string" || topic.trim().length === 0) {
    throw new Error("O tema é obrigatório.");
  }
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 20) {
    throw new Error("A quantidade deve ser um inteiro entre 1 e 20.");
  }
  if (!ALLOWED_MODELS[modelKey]) {
    throw new Error(`Modelo "${modelKey}" não é permitido.`);
  }

  const promptArgs = {
    subject,
    topic: topic.trim(),
    difficulty,
    quantity,
    description,
  };
  const prompt = buildPrompt(promptArgs);

  const queue = buildAttemptQueue(modelKey);
  const attempts: Attempt[] = [];
  let lastError: Error | null = null;

  for (const candidate of queue) {
    const modelId = ALLOWED_MODELS[candidate];
    try {
      const raw = await callOpenRouter({ modelId, prompt, apiKey });
      const questions = parseAndValidate(raw);
      attempts.push({ model: candidate, status: "success" });
      return { questions, modelUsed: candidate, modelIdUsed: modelId, attempts };
    } catch (err) {
      lastError = err as Error;
      attempts.push({ model: candidate, status: "error", message: (err as Error).message });
    }
  }

  throw new GenerationError(
    lastError
      ? `Todos os modelos falharam. Último erro: ${lastError.message}`
      : "Todos os modelos falharam.",
    attempts,
  );
}
