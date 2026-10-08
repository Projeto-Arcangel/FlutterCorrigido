// Leitura de vídeos do YouTube com o Gemini (API do Google, chamada direta).
// O OpenRouter também aceita links do YouTube, mas não permite recortar o
// vídeo nem reduzir os quadros analisados: sem isso, o custo de um vídeo
// longo não tem teto.
//
// Como funciona:
//   1. A duração exata vem da contagem de tokens (gratuita, < 2 s): áudio é
//      sempre 32 tokens/s. A contagem também barra vídeo privado/removido
//      antes de gastar qualquer coisa.
//   2. O vídeo é dividido em trechos de até 10 min, lidos EM PARALELO. O
//      recorte é feito pelo próprio Gemini, então cada parte do vídeo tem a
//      sua resposta: a cobertura não depende do modelo "lembrar" de tudo.
//   3. Cada trecho vira anotações de aula completas, com as palavras do
//      modelo. Transcrição literal é bloqueada pelo filtro de "recitation"
//      do Google em muitos vídeos (testado: aula de 5 min recusada).
//   4. Trecho lento ou com erro: dispara o mesmo trecho no próximo modelo e
//      fica com quem responder primeiro (o serviço oscila sob demanda).
//   5. Trecho que falhar mesmo assim é AVISADO ao professor, com os minutos.
//
// O texto volta para o app e segue o caminho dos outros materiais (recorte +
// generate-questions com o modelo escolhido pelo professor).

const API_URL = "https://generativelanguage.googleapis.com/v1beta/models";

/**
 * Em ordem de preferência (custo). Cada modelo tem capacidade própria no
 * Google: quando um está sobrecarregado, o seguinte costuma responder.
 */
export const VIDEO_MODELS = [
  { id: "gemini-3.5-flash-lite", thinking: "minimal" },
  { id: "gemini-3.1-flash-lite", thinking: "minimal" },
  { id: "gemini-3.8-flash", thinking: "low" },
] as const;

/** Trecho máximo lido de cada vídeo: limita custo e tempo de resposta. */
export const MAX_VIDEO_SECONDS = 60 * 60;

/** Tamanho máximo de cada trecho lido em paralelo. */
const CLIP_SECONDS = 10 * 60;

/**
 * Quadros analisados por segundo. A fala — o conteúdo principal de uma aula
 * — é ouvida inteira; da imagem basta pegar slides e quadro, que ficam
 * vários segundos na tela.
 */
const FPS = 0.25;

/** Tokens de áudio por segundo de vídeo (fixo, pela documentação do Gemini). */
const AUDIO_TOKENS_PER_SECOND = 32;

/** Tokens de imagem por segundo com FPS e resolução baixa acima (medido). */
const FRAME_TOKENS_PER_SECOND = 17.8;

/** Um trecho de 10 min rende ~1–2 mil tokens de anotações; folga de 4x. */
const MAX_OUTPUT_TOKENS = 8192;

/** A contagem de tokens responde em ~1 s; acima disso, próximo modelo. */
const COUNT_TIMEOUT_MS = 15_000;

/** Trecho sem resposta depois disso: dispara o mesmo trecho no próximo modelo. */
const HEDGE_AFTER_MS = 30_000;

/** Abaixo do limite de tempo de parede das Edge Functions (150 s). */
const DEADLINE_MS = 130_000;

/** Resposta combinada para "o trecho não tem nada a anotar". */
const NO_CONTENT = "SEM_CONTEUDO";

const PROMPT = `Escreva anotações de aula completas sobre este trecho de vídeo, para que um professor gere questões de prova a partir delas.

Regras:
- Cubra o trecho do início ao fim, na ordem em que o conteúdo aparece, sem pular nenhum assunto.
- NÃO resuma: registre tudo o que é ensinado — conceitos, definições, explicações, exemplos, dados, datas, nomes, fórmulas e conclusões —, com o mesmo nível de detalhe do vídeo.
- Inclua o conteúdo mostrado na tela (slides, quadro, fórmulas, tabelas) junto com o que é falado.
- Escreva com suas próprias palavras, em frases completas, em português do Brasil. Não copie a fala literalmente.
- Não acrescente nada que não esteja no vídeo, não opine e não descreva cenas, pessoas ou músicas.
- Separe em parágrafos, com uma linha em branco entre eles: um parágrafo por assunto.
- Não use markdown nem marcações de tempo.
- Se o trecho não tiver fala nem texto com conteúdo, responda apenas: ${NO_CONTENT}`;

export class VideoError extends Error {
  constructor(public code: string, message: string) {
    super(message);
    this.name = "VideoError";
  }
}

export const VIDEO_MESSAGES = {
  unavailable:
    "Não consegui abrir este vídeo. Só leio vídeos públicos: vídeos " +
    "privados, não listados ou com restrição de idade ficam de fora.",
  busy:
    "O serviço de vídeos do Google está sobrecarregado agora. Tente de novo " +
    "em alguns minutos.",
  quota:
    "A leitura de vídeos atingiu o limite diário do serviço do Google. Tente " +
    "de novo amanhã ou anexe o conteúdo em PDF, Word ou PowerPoint.",
  blocked:
    "Não consegui ler este vídeo: o conteúdo foi barrado pelo filtro de " +
    "segurança do serviço.",
  noSpeech:
    "Não encontrei fala nem texto com conteúdo neste vídeo para gerar questões.",
  timeout:
    "O serviço de vídeos demorou demais para responder. Tente de novo em " +
    "alguns minutos.",
  failed: "Não consegui ler o vídeo agora. Tente de novo em instantes.",
  clipped: (totalMinutes: number, readMinutes: number) =>
    `Este vídeo tem ${totalMinutes} minutos: li só os primeiros ${readMinutes}.`,
  missing: (ranges: string) =>
    `Não consegui ler ${ranges} do vídeo, então as questões vão cobrir só o ` +
    "resto. Para tentar ler tudo, remova o vídeo e adicione de novo.",
  truncated:
    "Parte das anotações foi cortada por tamanho: confira se o conteúdo lido " +
    "basta.",
};

/** Um trecho do vídeo, em segundos. */
export interface Clip {
  start: number;
  end: number;
}

export interface VideoNotes {
  text: string;
  /** Modelos que responderam (pode haver mais de um, por trecho). */
  models: string[];
  /** Duração total do vídeo. */
  duration: number;
  /** Segundos efetivamente lidos (trechos que responderam). */
  seconds: number;
  inputTokens: number;
  outputTokens: number;
  /** Trechos que não puderam ser lidos (avisados ao professor). */
  missing: Clip[];
  /** Alguma anotação foi cortada pelo limite de tamanho da resposta. */
  truncated: boolean;
}

type GeminiResponse = {
  candidates?: Array<{
    content?: { parts?: Array<{ text?: string; thought?: boolean }> };
    finishReason?: string;
  }>;
  promptFeedback?: { blockReason?: string };
  usageMetadata?: {
    promptTokenCount?: number;
    candidatesTokenCount?: number;
    promptTokensDetails?: ModalityTokens[];
  };
  /** Na contagem de tokens (countTokens) os detalhes vêm na raiz. */
  promptTokensDetails?: ModalityTokens[];
  error?: { code?: number; message?: string; status?: string };
};

type ModalityTokens = { modality?: string; tokenCount?: number };

type Model = (typeof VIDEO_MODELS)[number];

/**
 * Falha que vale tentar no próximo modelo (sobrecarga, cota do modelo,
 * instabilidade, resposta sem o vídeo). As outras ([VideoError]) dizem
 * respeito ao próprio vídeo e encerram a leitura.
 */
class RetryableError extends Error {
  constructor(public code: "busy" | "quota" | "failed", message: string) {
    super(message);
  }
}

function videoPart(videoUrl: string, clip?: Clip) {
  return {
    file_data: { file_uri: videoUrl },
    video_metadata: {
      fps: FPS,
      ...(clip ? { start_offset: `${clip.start}s`, end_offset: `${clip.end}s` } : {}),
    },
  };
}

function modalityTokens(data: GeminiResponse, ...modalities: string[]): number {
  return (data.usageMetadata?.promptTokensDetails ?? data.promptTokensDetails ?? [])
    .filter((d) => modalities.includes(d.modality ?? ""))
    .reduce((sum, d) => sum + (d.tokenCount ?? 0), 0);
}

async function post(
  model: string,
  method: "generateContent" | "countTokens",
  body: unknown,
  apiKey: string,
  signal: AbortSignal,
): Promise<GeminiResponse> {
  let resp: Response;
  try {
    resp = await fetch(`${API_URL}/${model}:${method}`, {
      method: "POST",
      signal,
      headers: { "x-goog-api-key": apiKey, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (e) {
    if (signal.aborted) throw e;
    throw new RetryableError("failed", "rede");
  }

  const data = await resp.json().catch(() => ({})) as GeminiResponse;
  if (resp.ok) return data;

  const message = data.error?.message ?? "";
  console.error(`extract-video: ${model} ${method} HTTP ${resp.status}: ${message.slice(0, 300)}`);
  if (resp.status === 429) {
    throw /per ?day|daily|PerDay/i.test(message)
      ? new RetryableError("quota", message)
      : new RetryableError("busy", message);
  }
  // Sobrecarga/instabilidade, modelo indisponível ou pedido que este modelo
  // não aceita: o próximo modelo pode responder.
  if (
    resp.status >= 500 || (resp.status === 404 && /models\//i.test(message)) ||
    /Unknown name|Invalid JSON payload|thinking|not supported/i.test(message)
  ) {
    throw new RetryableError(resp.status >= 500 ? "busy" : "failed", message);
  }
  // 400/403/404 sobre o vídeo: privado, removido, ao vivo, restrito...
  throw new VideoError("unavailable", VIDEO_MESSAGES.unavailable);
}

/** Duração exata do vídeo, em segundos, pela contagem de tokens. */
async function videoDuration(
  videoUrl: string,
  apiKey: string,
  signal: AbortSignal,
): Promise<number> {
  let lastError: RetryableError | null = null;
  for (const model of VIDEO_MODELS) {
    // Responde em ~1 s; travou, passa para o próximo modelo.
    const attempt = AbortSignal.any([signal, AbortSignal.timeout(COUNT_TIMEOUT_MS)]);
    try {
      const data = await post(model.id, "countTokens", {
        generateContentRequest: {
          model: `models/${model.id}`,
          contents: [{ role: "user", parts: [videoPart(videoUrl), { text: "." }] }],
          generationConfig: { mediaResolution: "MEDIA_RESOLUTION_LOW" },
        },
      }, apiKey, attempt);
      const audio = modalityTokens(data, "AUDIO");
      // Vídeo sem faixa de áudio: estima pelos quadros.
      const seconds = audio > 0
        ? audio / AUDIO_TOKENS_PER_SECOND
        : modalityTokens(data, "VIDEO") / FRAME_TOKENS_PER_SECOND;
      if (seconds < 1) throw new VideoError("unavailable", VIDEO_MESSAGES.unavailable);
      return Math.round(seconds);
    } catch (e) {
      if (e instanceof RetryableError) lastError = e;
      else if (attempt.aborted && !signal.aborted) {
        lastError = new RetryableError("busy", "contagem sem resposta");
      } else throw e;
    }
  }
  throw new VideoError(lastError?.code ?? "failed", VIDEO_MESSAGES[lastError?.code ?? "failed"]);
}

/** Divide os primeiros [seconds] em trechos iguais de até CLIP_SECONDS. */
export function clipsFor(seconds: number): Clip[] {
  const count = Math.max(1, Math.ceil(seconds / CLIP_SECONDS));
  return Array.from({ length: count }, (_, i) => ({
    start: Math.round((i * seconds) / count),
    end: Math.round(((i + 1) * seconds) / count),
  }));
}

interface ClipNotes {
  text: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  truncated: boolean;
}

async function readClip(
  model: Model,
  videoUrl: string,
  clip: Clip,
  apiKey: string,
  signal: AbortSignal,
): Promise<ClipNotes> {
  const data = await post(model.id, "generateContent", {
    contents: [{ role: "user", parts: [videoPart(videoUrl, clip), { text: PROMPT }] }],
    generationConfig: {
      mediaResolution: "MEDIA_RESOLUTION_LOW",
      maxOutputTokens: MAX_OUTPUT_TOKENS,
      thinkingConfig: { thinkingLevel: model.thinking },
    },
  }, apiKey, signal);

  if (data.promptFeedback?.blockReason) {
    throw new VideoError("blocked", VIDEO_MESSAGES.blocked);
  }
  const candidate = data.candidates?.[0];
  const finish = candidate?.finishReason ?? "";
  if (["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII"].includes(finish)) {
    throw new VideoError("blocked", VIDEO_MESSAGES.blocked);
  }
  // Integridade: sem tokens de mídia o modelo não assistiu ao trecho, e o
  // "texto" seria inventado.
  if (modalityTokens(data, "VIDEO", "AUDIO") === 0) {
    console.error(`extract-video: ${model.id} respondeu sem tokens de mídia`);
    throw new RetryableError("failed", "sem mídia");
  }
  const text = (candidate?.content?.parts ?? [])
    .filter((p) => !p.thought && typeof p.text === "string")
    .map((p) => p.text)
    .join("")
    .trim();
  // Recusa por "recitation" depende do texto gerado: outro modelo pode passar.
  if (finish === "RECITATION" && !text) throw new RetryableError("failed", "recitation");

  return {
    text: text === NO_CONTENT ? "" : text,
    model: model.id,
    inputTokens: data.usageMetadata?.promptTokenCount ?? 0,
    outputTokens: data.usageMetadata?.candidatesTokenCount ?? 0,
    truncated: finish === "MAX_TOKENS" || finish === "RECITATION",
  };
}

/**
 * Lê um trecho, disputando entre modelos: começa no preferido; se ele falhar
 * ou demorar mais que HEDGE_AFTER_MS, dispara o próximo sem cancelar o
 * anterior, e fica com a primeira resposta válida.
 */
function readClipHedged(
  videoUrl: string,
  clip: Clip,
  apiKey: string,
  deadline: AbortSignal,
): Promise<ClipNotes> {
  return new Promise((resolve, reject) => {
    const attempts: AbortController[] = [];
    let next = 0;
    let running = 0;
    let settled = false;
    let lastError: unknown = null;
    let hedgeTimer: number | undefined;

    const settle = (done: () => void) => {
      if (settled) return;
      settled = true;
      clearTimeout(hedgeTimer);
      deadline.removeEventListener("abort", onDeadline);
      for (const attempt of attempts) attempt.abort();
      done();
    };
    const onDeadline = () =>
      settle(() => reject(new VideoError("timeout", VIDEO_MESSAGES.timeout)));

    const launch = () => {
      if (settled) return;
      clearTimeout(hedgeTimer);
      if (next >= VIDEO_MODELS.length) {
        if (running === 0) {
          settle(() => reject(lastError ?? new VideoError("failed", VIDEO_MESSAGES.failed)));
        }
        return;
      }
      const model = VIDEO_MODELS[next++];
      const attempt = new AbortController();
      attempts.push(attempt);
      running++;
      hedgeTimer = setTimeout(launch, HEDGE_AFTER_MS);
      readClip(model, videoUrl, clip, apiKey, AbortSignal.any([attempt.signal, deadline]))
        .then((notes) => settle(() => resolve(notes)))
        .catch((e) => {
          running--;
          if (settled) return;
          // Problema do vídeo (privado, bloqueado): outro modelo não resolve.
          if (e instanceof VideoError) return settle(() => reject(e));
          // A cota diária é a causa mais informativa para o professor.
          if (!(lastError instanceof RetryableError && lastError.code === "quota")) {
            lastError = e;
          }
          launch();
        });
    };

    if (deadline.aborted) return onDeadline();
    deadline.addEventListener("abort", onDeadline, { once: true });
    launch();
  });
}

function minutes(seconds: number): number {
  return Math.round(seconds / 60);
}

/** "o trecho de 20 a 30 min" / "os trechos de 0 a 10 min e de 40 a 50 min". */
export function describeClips(clips: Clip[]): string {
  const parts = clips.map((c) => `de ${minutes(c.start)} a ${minutes(c.end)} min`);
  const list = parts.length > 1
    ? `${parts.slice(0, -1).join(", ")} e ${parts[parts.length - 1]}`
    : parts[0];
  return `${clips.length > 1 ? "os trechos" : "o trecho"} ${list}`;
}

/** Lança [VideoError] com a mensagem para o professor. */
export async function readVideo(videoUrl: string, apiKey: string): Promise<VideoNotes> {
  const deadline = AbortSignal.timeout(DEADLINE_MS);
  let duration: number;
  try {
    duration = await videoDuration(videoUrl, apiKey, deadline);
  } catch (e) {
    if (deadline.aborted) throw new VideoError("timeout", VIDEO_MESSAGES.timeout);
    throw e;
  }

  const clips = clipsFor(Math.min(duration, MAX_VIDEO_SECONDS));
  const results = await Promise.allSettled(
    clips.map((clip) => readClipHedged(videoUrl, clip, apiKey, deadline)),
  );

  const read = results.flatMap((r, i) =>
    r.status === "fulfilled" ? [{ clip: clips[i], notes: r.value }] : []
  );
  const failures = results.flatMap((r) => r.status === "rejected" ? [r.reason] : []);
  if (read.length === 0) {
    // Nenhum trecho: a causa vai para o professor (vídeo, cota, sobrecarga).
    const cause = failures.find((e) => e instanceof VideoError) ??
      failures.find((e) => e instanceof RetryableError && e.code === "quota") ??
      failures[0];
    if (cause instanceof VideoError) throw cause;
    const code = cause instanceof RetryableError ? cause.code : "failed";
    throw new VideoError(code, VIDEO_MESSAGES[code]);
  }
  // Os trechos lidos valem mesmo que outro falhe: o que faltou é avisado.
  const text = read.map((r) => r.notes.text).filter(Boolean).join("\n\n");
  if (!text) throw new VideoError("no_speech", VIDEO_MESSAGES.noSpeech);

  return {
    text,
    models: [...new Set(read.map((r) => r.notes.model))],
    duration,
    seconds: read.reduce((sum, r) => sum + (r.clip.end - r.clip.start), 0),
    inputTokens: read.reduce((sum, r) => sum + r.notes.inputTokens, 0),
    outputTokens: read.reduce((sum, r) => sum + r.notes.outputTokens, 0),
    missing: clips.filter((_, i) => results[i].status === "rejected"),
    truncated: read.some((r) => r.notes.truncated),
  };
}
