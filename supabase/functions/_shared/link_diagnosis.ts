// Diagnóstico dos problemas ao ler um link, com uma mensagem para cada caso:
// o que aconteceu e o que o professor pode fazer. Tudo aqui é heurística
// sobre a URL e o HTML — sem acesso extra à rede.

import { isYouTube } from "./youtube.ts";

export interface LinkProblem {
  code: string;
  message: string;
}

const COPY_TIP = "Copie o texto da página para um DOCX e anexe.";

export const MESSAGES = {
  login: `Não consigo acessar páginas que exigem login. ${COPY_TIP}`,
  paywall:
    "Esta página é exclusiva para assinantes e não consigo ler o conteúdo " +
    "completo. Se você tem acesso, copie o texto para um DOCX e anexe.",
  needsJs:
    "Esta página só mostra o conteúdo depois de carregar com JavaScript, e " +
    `não consigo ler esse tipo de página. ${COPY_TIP}`,
  botBlocked:
    `Este site bloqueia leitores automáticos como o nosso. ${COPY_TIP}`,
  rateLimited:
    "O site está recebendo muitos acessos e pediu para esperar. Tente de " +
    "novo em alguns minutos.",
  pageNotFound:
    "Não encontrei esta página — ela pode ter sido removida ou o link está " +
    "incompleto. Confira o endereço.",
  siteNotFound: "Não encontrei esse site. Confira se o endereço está correto.",
  siteDown: (status: number) =>
    `O site está com problemas no momento (erro ${status}). Tente de novo mais tarde.`,
  timeout: "O site demorou demais para responder. Tente de novo.",
  unavailable: "Não consegui acessar o site agora. Tente de novo em instantes.",
  blocked:
    "Por segurança, não acesso endereços internos ou de rede local. Use o " +
    "link público da página.",
  invalidUrl: "Link inválido. Confira o endereço.",
  redirects: "O link redireciona vezes demais e não consegui chegar à página.",
  noText: `Não encontrei texto nesta página. ${COPY_TIP}`,
  tooLarge:
    "Esta página tem conteúdo demais para ler de uma vez. Salve só a parte " +
    "desejada em DOCX ou PDF e anexe.",
  // Vídeos são lidos pela função extract-video; aqui só chega um link que
  // redireciona para o YouTube (ex.: link encurtado).
  youtube:
    "Este link leva a um vídeo do YouTube. Cole o endereço do próprio vídeo " +
    "(youtube.com/watch?v=… ou youtu.be/…).",
  pdf: "Este link é um arquivo PDF. Baixe o arquivo e anexe como material.",
  officeFile:
    "Este link é um arquivo do Word ou PowerPoint. Baixe o arquivo e anexe " +
    "como material.",
  image:
    "Este link é uma imagem, e eu só leio texto. Use o link de uma página " +
    "com o conteúdo escrito.",
  media:
    "Este link é um vídeo ou áudio, e eu só leio texto. Use o link de uma " +
    "página com o conteúdo escrito.",
  unsupported:
    "Este link não é uma página de texto. Use o link de um artigo ou página.",
  googleDoc:
    "Não consigo abrir documentos do Google Docs pelo link (eles exigem " +
    "login). No Google Docs, use Arquivo > Fazer download > Microsoft Word " +
    "(.docx) e anexe o arquivo.",
  googleSlides:
    "Não consigo abrir apresentações do Google Slides pelo link (elas exigem " +
    "login). No Google Slides, use Arquivo > Fazer download > Microsoft " +
    "PowerPoint (.pptx) e anexe o arquivo.",
  googleSheets:
    "Não leio planilhas. Copie o conteúdo que interessa para um DOCX e anexe.",
  googleDrive:
    "Não consigo abrir arquivos do Google Drive pelo link (eles exigem " +
    "login). Baixe o arquivo e anexe como material.",
  social:
    "Não consigo ler publicações de redes sociais (elas exigem login). " +
    COPY_TIP,
  paywallWarning:
    "Parte deste conteúdo pode ser exclusiva para assinantes: confira se o " +
    "texto lido está completo.",
};

function host(url: URL): string {
  return url.hostname.toLowerCase().replace(/^(www|m|mobile)\./, "");
}

const SOCIAL_HOSTS = [
  "instagram.com", "facebook.com", "fb.com", "x.com", "twitter.com",
  "tiktok.com", "linkedin.com", "threads.net", "pinterest.com",
];

/** Sites que sabidamente não dá para ler pelo link, antes de acessá-los. */
export function knownSiteProblem(url: URL): LinkProblem | null {
  const h = host(url);
  const path = url.pathname;
  if (isYouTube(url)) return { code: "youtube", message: MESSAGES.youtube };
  if (h === "docs.google.com") {
    if (path.startsWith("/document")) return { code: "google_doc", message: MESSAGES.googleDoc };
    if (path.startsWith("/presentation")) {
      return { code: "google_slides", message: MESSAGES.googleSlides };
    }
    if (path.startsWith("/spreadsheets")) {
      return { code: "google_sheets", message: MESSAGES.googleSheets };
    }
    return { code: "google_drive", message: MESSAGES.googleDrive };
  }
  if (h === "drive.google.com") return { code: "google_drive", message: MESSAGES.googleDrive };
  if (SOCIAL_HOSTS.some((s) => h === s || h.endsWith(`.${s}`))) {
    return { code: "social", message: MESSAGES.social };
  }
  return null;
}

const LOGIN_HOSTS = [
  "accounts.google.com", "login.microsoftonline.com", "login.live.com",
  "auth0.com", "okta.com",
];
const LOGIN_PATH =
  /(^|\/)(login|log-in|signin|sign-in|sign_in|entrar|logon|acesso|acessar|auth|sso|oauth2?|cas\/login|conta\/entrar|account\/login|minha-conta\/login)(\/|$|\.|\?)/i;

/** A URL é de uma tela de login (destino de redirecionamento, p.ex.). */
export function looksLikeLoginUrl(url: URL): boolean {
  const h = url.hostname.toLowerCase();
  if (LOGIN_HOSTS.some((l) => h === l || h.endsWith(`.${l}`))) return true;
  return LOGIN_PATH.test(url.pathname) ||
    (/[?&](returnurl|redirect_uri|return_to|next)=/i.test(url.search) &&
      /login|signin|auth/i.test(url.pathname));
}

/** Bloqueio anti-robô (desafio da Cloudflare e afins) num 403/503. */
export function looksLikeBotChallenge(headers: Headers, bodyStart: string): boolean {
  if (headers.get("cf-mitigated") === "challenge") return true;
  const server = (headers.get("server") ?? "").toLowerCase();
  const text = bodyStart.toLowerCase();
  const protectedServer = server.includes("cloudflare") ||
    server.includes("akamai") || server.includes("ddos-guard");
  const challengePage = text.includes("just a moment") ||
    text.includes("challenge") || text.includes("checking your browser") ||
    text.includes("captcha");
  return (protectedServer && challengePage) ||
    text.includes("cf-browser-verification") ||
    text.includes("/cdn-cgi/challenge-platform");
}

function paywalled(html: string): boolean {
  return /"isAccessibleForFree"\s*:\s*"?false"?/i.test(html) ||
    /\b(class|id)=["'][^"']*\b(paywall|piano-offer|tp-modal|regwall|meter-wall)\b/i
      .test(html);
}

/** Porque uma página veio sem texto aproveitável. */
export function diagnoseEmptyPage(html: string): LinkProblem {
  if (/<input[^>]+type=["']?password/i.test(html)) {
    return { code: "login", message: MESSAGES.login };
  }
  if (paywalled(html)) return { code: "paywall", message: MESSAGES.paywall };

  // Aplicação montada por JavaScript: muitos scripts, um contêiner raiz vazio
  // ou um aviso em <noscript>.
  const scripts = (html.match(/<script\b/gi) ?? []).length;
  const emptyRoot =
    /<div[^>]+id=["'](root|app|__next|__nuxt|svelte|main-app)["'][^>]*>\s*<\/div>/i
      .test(html);
  const noscriptWarning = /<noscript[^>]*>[\s\S]{0,400}?javascript[\s\S]*?<\/noscript>/i
    .test(html);
  if (emptyRoot || noscriptWarning || scripts >= 15) {
    return { code: "needs_js", message: MESSAGES.needsJs };
  }
  return { code: "no_text", message: MESSAGES.noText };
}

/** Aviso (sem impedir o uso) quando o texto lido pode ser só uma prévia. */
export function paywallWarning(html: string): string | null {
  return paywalled(html) ? MESSAGES.paywallWarning : null;
}
