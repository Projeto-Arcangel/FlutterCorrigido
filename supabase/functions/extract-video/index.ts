// Edge Function: extract-video
//
// Lê um vídeo do YouTube (fala + texto que aparece na tela) a partir do link
// que o professor colou em "Questões com IA > Dos meus materiais" e devolve
// anotações de aula completas (_shared/gemini_video). O texto volta para o
// app e é tratado como os outros materiais: entra no recorte e na geração
// (generate-questions). Nada é armazenado além dos metadados da leitura
// (material_extractions), para o teto diário.
//
// - Só professores logados (JWT verificado + papel em profiles).
// - Só vídeos públicos; lidos até MAX_VIDEO_SECONDS (o resto é avisado).
// - Teto diário de vídeos por professor (custo no Gemini).
//
// Segredo: GEMINI_API_KEY (supabase secrets set / supabase/functions/.env).
//
// Respostas:
//   200 { title, siteName, url, chars, segments, seconds, duration, warning? }
//   4xx/5xx { error: "<mensagem para o professor>", code: "<motivo>" }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  describeClips,
  MAX_VIDEO_SECONDS,
  readVideo,
  VIDEO_MESSAGES,
  VideoError,
  type VideoNotes,
} from "../_shared/gemini_video.ts";
import { toSegments } from "../_shared/text_segments.ts";
import { parseYouTube } from "../_shared/youtube.ts";

/** Vídeos lidos (inteiros ou em parte) por professor por dia (custo no Gemini). */
const DAILY_VIDEO_LIMIT = 10;
const MAX_URL_LENGTH = 2048;

type AdminClient = ReturnType<typeof createClient>;

const LINK_MESSAGES = {
  invalid: "Link inválido. Confira o endereço.",
  playlist:
    "Este é o link de uma playlist. Abra o vídeo desejado e cole o link dele.",
  channel:
    "Este é o link de um canal. Abra o vídeo desejado e cole o link dele.",
  other:
    "Este link do YouTube não aponta para um vídeo. Abra o vídeo e cole o " +
    "link dele.",
  notFound:
    "Não encontrei este vídeo. Confira o link — o vídeo pode ter sido removido.",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, code: string, message: string): Response {
  return json(status, { error: message, code });
}

/**
 * Título e canal pelo oEmbed do YouTube (leve, sem chave). Também separa o
 * vídeo inexistente (404) logo de início, sem gastar tokens. Outras falhas
 * não impedem a leitura: o Gemini dá a palavra final.
 */
async function videoInfo(
  url: string,
): Promise<{ title: string | null; channel: string | null; missing: boolean }> {
  try {
    const resp = await fetch(
      `https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(url)}`,
      { signal: AbortSignal.timeout(5000) },
    );
    if (resp.status === 404 || resp.status === 400) {
      await resp.body?.cancel();
      return { title: null, channel: null, missing: true };
    }
    if (!resp.ok) {
      await resp.body?.cancel();
      return { title: null, channel: null, missing: false };
    }
    const data = await resp.json() as { title?: string; author_name?: string };
    return {
      title: data.title?.trim() || null,
      channel: data.author_name?.trim() || null,
      missing: false,
    };
  } catch (_e) {
    return { title: null, channel: null, missing: false };
  }
}

async function logExtraction(
  admin: AdminClient,
  row: {
    teacherId: string;
    source: string;
    title: string | null;
    notes: VideoNotes | null;
    status: "success" | "partial" | "error";
    error: string | null;
  },
): Promise<void> {
  try {
    await admin.from("material_extractions").insert({
      teacher_id: row.teacherId,
      kind: "video",
      source: row.source,
      title: row.title?.slice(0, 300) ?? null,
      seconds: row.notes?.seconds ?? null,
      model: row.notes?.models.join(",") ?? null,
      input_tokens: row.notes?.inputTokens ?? null,
      output_tokens: row.notes?.outputTokens ?? null,
      status: row.status,
      error_message: row.error,
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
    return fail(405, "method", "Método não permitido.");
  }

  // 1. Só professores.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return fail(401, "auth", "Não autenticado.");
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return fail(401, "auth", "Não autenticado.");
  const { data: profile } = await userClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();
  if (!profile || (profile.role !== "teacher" && profile.role !== "admin")) {
    return fail(403, "forbidden", "Apenas professores podem usar este recurso.");
  }

  // 2. O link precisa apontar para um vídeo.
  const body = await req.json().catch(() => ({})) as { url?: unknown };
  const raw = typeof body.url === "string" ? body.url.trim() : "";
  let url: URL;
  try {
    if (!raw || raw.length > MAX_URL_LENGTH) throw new Error();
    url = new URL(raw);
  } catch (_e) {
    return fail(400, "invalid_url", LINK_MESSAGES.invalid);
  }
  const link = parseYouTube(url);
  if (!link) return fail(400, "not_youtube", LINK_MESSAGES.invalid);
  if (link.type !== "video") return fail(422, link.type, LINK_MESSAGES[link.type]);

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("extract-video: GEMINI_API_KEY não configurada");
    return fail(500, "not_configured", VIDEO_MESSAGES.failed);
  }

  // 3. Teto diário. Falha na consulta deixa passar (fail-open): o teto é
  // controle de custo, não fronteira de segurança.
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: readToday, error: quotaErr } = await admin.rpc(
    "videos_read_today",
    { p_teacher: user.id },
  );
  if (!quotaErr && typeof readToday === "number" && readToday >= DAILY_VIDEO_LIMIT) {
    return fail(
      429,
      "daily_limit",
      `Você já leu ${readToday} vídeos hoje, o limite diário. Amanhã você ` +
        "pode ler mais — ou anexe o conteúdo em PDF, Word ou PowerPoint.",
    );
  }

  // 4. Título (e vídeo inexistente) antes de gastar tokens.
  const info = await videoInfo(link.url);
  if (info.missing) return fail(422, "not_found", LINK_MESSAGES.notFound);

  // 5. Leitura do vídeo (anotações por trecho).
  let notes: VideoNotes;
  try {
    notes = await readVideo(link.url, apiKey);
  } catch (e) {
    const err = e instanceof VideoError
      ? e
      : new VideoError("failed", VIDEO_MESSAGES.failed);
    if (!(e instanceof VideoError)) console.error("extract-video: falha inesperada", e);
    await logExtraction(admin, {
      teacherId: user.id,
      source: link.url,
      title: info.title,
      notes: null,
      status: "error",
      error: err.code,
    });
    const status = err.code === "busy" || err.code === "quota"
      ? 429
      : err.code === "timeout"
      ? 504
      : 422;
    return fail(status, err.code, err.message);
  }

  await logExtraction(admin, {
    teacherId: user.id,
    source: link.url,
    title: info.title,
    notes,
    status: notes.missing.length ? "partial" : "success",
    error: notes.missing.length
      ? `faltou: ${notes.missing.map((c) => `${c.start}-${c.end}s`).join(", ")}`
      : null,
  });

  const paragraphs = notes.text
    .split(/\n\s*\n/)
    .map((p) => p.replace(/[ \t]+/g, " ").trim())
    .filter(Boolean);
  const warnings = [
    notes.duration > MAX_VIDEO_SECONDS
      ? VIDEO_MESSAGES.clipped(Math.round(notes.duration / 60), MAX_VIDEO_SECONDS / 60)
      : null,
    notes.missing.length ? VIDEO_MESSAGES.missing(describeClips(notes.missing)) : null,
    notes.truncated ? VIDEO_MESSAGES.truncated : null,
  ].filter(Boolean);

  return json(200, {
    title: (info.title ?? "Vídeo do YouTube").slice(0, 200),
    siteName: info.channel,
    url: link.url,
    chars: paragraphs.reduce((sum, p) => sum + p.length, 0),
    segments: toSegments(paragraphs),
    seconds: notes.seconds,
    duration: notes.duration,
    ...(warnings.length ? { warning: warnings.join(" ") } : {}),
  });
});
