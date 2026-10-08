// Edge Function: extract-url
//
// Lê o texto principal de uma página (artigo, notícia, verbete) a partir do
// link que o professor colou em "Questões com IA > Dos meus materiais". O
// texto volta para o app, que o trata como os arquivos: entra no recorte e na
// geração (generate-questions). Nada é armazenado.
//
// Segurança:
//   - Só professores logados (JWT verificado + papel em profiles).
//   - Só endereços públicos; redirecionamentos revalidados (_shared/safe_fetch).
//   - Tempo e tamanho de resposta limitados; conteúdo que não é texto nem é
//     baixado.
//
// Cada problema tem uma mensagem própria (_shared/link_diagnosis): login,
// assinantes, página montada por JavaScript, bloqueio anti-robô, Google Docs,
// redes sociais, arquivo em vez de página...
//
// Respostas:
//   200 { title, siteName, url, chars, segments, warning? }
//   4xx/5xx { error: "<mensagem para o professor>", code: "<motivo>" }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { decodeHtml, extractPageText } from "../_shared/html_text.ts";
import {
  diagnoseEmptyPage,
  knownSiteProblem,
  type LinkProblem,
  looksLikeLoginUrl,
  MESSAGES,
  paywallWarning,
} from "../_shared/link_diagnosis.ts";
import { LinkError, safeFetch } from "../_shared/safe_fetch.ts";
import { toSegments } from "../_shared/text_segments.ts";

/** Página com menos texto que isso não tem conteúdo aproveitável. */
const MIN_CHARS = 300;
/** Texto máximo devolvido (o app ainda recorta para a IA). */
const MAX_CHARS = 1_000_000;
const MAX_URL_LENGTH = 2048;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(status: number, problem: LinkProblem): Response {
  return json(status, { error: problem.message, code: problem.code });
}

/** Link que leva a um arquivo ou mídia em vez de uma página de texto. */
function contentTypeProblem(type: string): LinkProblem | null {
  if (type.includes("application/pdf")) return { code: "pdf", message: MESSAGES.pdf };
  if (
    type.includes("officedocument") || type.includes("msword") ||
    type.includes("ms-powerpoint")
  ) {
    return { code: "office_file", message: MESSAGES.officeFile };
  }
  if (type.startsWith("image/")) return { code: "image", message: MESSAGES.image };
  if (type.startsWith("video/") || type.startsWith("audio/")) {
    return { code: "media", message: MESSAGES.media };
  }
  if (
    type !== "" && !type.includes("text/html") &&
    !type.includes("application/xhtml") && !type.includes("text/plain")
  ) {
    return { code: "unsupported", message: MESSAGES.unsupported };
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return fail(405, { code: "method", message: "Método não permitido." });
  }

  // 1. Só professores.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return fail(401, { code: "auth", message: "Não autenticado." });
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return fail(401, { code: "auth", message: "Não autenticado." });
  const { data: profile } = await userClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();
  if (!profile || (profile.role !== "teacher" && profile.role !== "admin")) {
    return fail(403, {
      code: "forbidden",
      message: "Apenas professores podem usar este recurso.",
    });
  }

  // 2. Link e sites que sabidamente não dá para ler.
  const body = await req.json().catch(() => ({})) as { url?: unknown };
  const raw = typeof body.url === "string" ? body.url.trim() : "";
  let url: URL;
  try {
    if (!raw || raw.length > MAX_URL_LENGTH) throw new Error();
    url = new URL(raw);
  } catch (_e) {
    return fail(400, { code: "invalid_url", message: MESSAGES.invalidUrl });
  }
  const known = knownSiteProblem(url);
  if (known) return fail(422, known);

  // 3. Busca e extração.
  try {
    const page = await safeFetch(url.href);
    const finalProblem = knownSiteProblem(page.finalUrl);
    if (finalProblem) return fail(422, finalProblem);
    if (looksLikeLoginUrl(page.finalUrl)) {
      return fail(422, { code: "login", message: MESSAGES.login });
    }

    const typeProblem = contentTypeProblem(page.contentType);
    if (typeProblem) return fail(422, typeProblem);

    const text = decodeHtml(page.bytes, page.contentType);
    let title: string;
    let siteName: string | null = null;
    let paragraphs: string[];
    let warning: string | null = null;

    if (page.contentType.includes("text/plain")) {
      title = page.finalUrl.pathname.split("/").pop() || page.finalUrl.hostname;
      paragraphs = text.split(/\n\s*\n/).map((p) => p.replace(/\s+/g, " ").trim())
        .filter(Boolean);
    } else {
      const extracted = extractPageText(text, page.finalUrl.href);
      title = extracted.title;
      siteName = extracted.siteName;
      paragraphs = extracted.paragraphs;
      warning = paywallWarning(text);
    }

    const chars = paragraphs.reduce((sum, p) => sum + p.length, 0);
    if (chars < MIN_CHARS) return fail(422, diagnoseEmptyPage(text));
    if (chars > MAX_CHARS) return fail(422, { code: "too_large", message: MESSAGES.tooLarge });

    return json(200, {
      title: title.slice(0, 200),
      siteName,
      url: page.finalUrl.href,
      chars,
      segments: toSegments(paragraphs),
      // Ex.: conteúdo para assinantes do qual só a prévia veio.
      ...(warning ? { warning } : {}),
    });
  } catch (e) {
    if (e instanceof LinkError) {
      return fail(e.code === "blocked" ? 403 : 422, { code: e.code, message: e.message });
    }
    console.error("extract-url: falha inesperada", e);
    return fail(500, { code: "unknown", message: "Não consegui ler esta página." });
  }
});
