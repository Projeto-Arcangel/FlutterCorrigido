const axios = require("axios").default;
const logger = require("firebase-functions/logger");

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const REQUEST_TIMEOUT_MS = 60_000;

const ALLOWED_MODELS = {
  "gemini-flash": "google/gemini-3.1-flash-lite",
  "gpt-mini": "openai/gpt-5.4-mini",
  "claude-haiku": "~anthropic/claude-haiku-latest",
};

const FALLBACK_ORDER = ["gemini-flash", "gpt-mini", "claude-haiku"];

const DIFFICULTY_LABELS = {
  easy: "Fácil — conceitos introdutórios, sem necessidade de análise profunda",
  medium: "Médio — exige compreensão e relacionamento de conceitos",
  hard: "Difícil — exige análise crítica e relacionamento entre eventos",
  expert: "Expert — exige interpretação avançada, fontes primárias e raciocínio histórico complexo",
};

function buildPrompt({ subject, topic, difficulty, quantity, description }) {
  const difficultyLabel = DIFFICULTY_LABELS[difficulty] || difficulty;
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

async function callOpenRouter({ modelId, prompt, apiKey }) {
  const response = await axios.post(
    OPENROUTER_URL,
    {
      model: modelId,
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
      temperature: 0.7,
    },
    {
      timeout: REQUEST_TIMEOUT_MS,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://arcangel-4c066.web.app",
        "X-Title": "Arcangel",
      },
    },
  );

  const content = response.data?.choices?.[0]?.message?.content;
  if (!content) {
    throw new Error("Resposta da IA veio vazia.");
  }
  return content;
}

function parseAndValidate(raw) {
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (e) {
    throw new Error("A IA retornou um JSON inválido.");
  }

  const questions = parsed?.questions;
  if (!Array.isArray(questions) || questions.length === 0) {
    throw new Error("A IA não retornou nenhuma questão.");
  }

  return questions.map((q, idx) => {
    if (typeof q.text !== "string" || q.text.trim().length === 0) {
      throw new Error(`Questão ${idx + 1} sem enunciado válido.`);
    }
    if (!Array.isArray(q.options) || q.options.length !== 4) {
      throw new Error(`Questão ${idx + 1} não tem exatamente 4 alternativas.`);
    }
    if (q.options.some((o) => typeof o !== "string" || o.trim().length === 0)) {
      throw new Error(`Questão ${idx + 1} tem alternativa vazia.`);
    }
    const correct = Number(q.correctAnswer);
    if (!Number.isInteger(correct) || correct < 0 || correct > 3) {
      throw new Error(`Questão ${idx + 1} tem correctAnswer inválido (esperado 0-3).`);
    }
    return {
      text: q.text.trim(),
      options: q.options.map((o) => o.trim()),
      correctAnswer: correct,
      explanation: typeof q.explanation === "string" ? q.explanation.trim() : "",
    };
  });
}

async function tryGenerateWith(modelKey, promptArgs, apiKey) {
  const modelId = ALLOWED_MODELS[modelKey];
  if (!modelId) {
    throw new Error(`Modelo "${modelKey}" não é permitido.`);
  }
  const prompt = buildPrompt(promptArgs);
  const raw = await callOpenRouter({ modelId, prompt, apiKey });
  const questions = parseAndValidate(raw);
  return { questions, modelKey, modelId };
}

function buildAttemptQueue(preferredModelKey) {
  const queue = [preferredModelKey];
  for (const m of FALLBACK_ORDER) {
    if (!queue.includes(m)) queue.push(m);
  }
  return queue;
}

async function generateQuestionsWithFallback(input, apiKey) {
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

  const queue = buildAttemptQueue(modelKey);
  const attempts = [];
  let lastError = null;

  for (const candidate of queue) {
    try {
      logger.info(`[ia_quiz] Tentando modelo "${candidate}"...`);
      const result = await tryGenerateWith(candidate, promptArgs, apiKey);
      attempts.push({ model: candidate, status: "success" });
      logger.info(`[ia_quiz] Sucesso com "${candidate}".`);
      return {
        questions: result.questions,
        modelUsed: candidate,
        modelIdUsed: result.modelId,
        attempts,
      };
    } catch (err) {
      lastError = err;
      attempts.push({
        model: candidate,
        status: "error",
        message: err.message,
      });
      logger.warn(
        `[ia_quiz] Falha com "${candidate}": ${err.message}. Tentando próximo...`,
      );
    }
  }

  const finalMessage = lastError
    ? `Todos os modelos falharam. Último erro: ${lastError.message}`
    : "Todos os modelos falharam.";
  const aggregated = new Error(finalMessage);
  aggregated.attempts = attempts;
  throw aggregated;
}

module.exports = {
  generateQuestionsWithFallback,
  ALLOWED_MODELS,
  FALLBACK_ORDER,
};
