// Busca de páginas da web a pedido do professor (links de artigos), com
// proteção contra SSRF: o servidor nunca acessa endereços internos.
//
// - Só http/https, sem usuário/senha na URL e só nas portas padrão.
// - O nome do site é resolvido (DNS-over-HTTPS) e TODOS os IPs precisam ser
//   públicos: nada de localhost, redes privadas, link-local (metadados de
//   nuvem em 169.254.169.254), CGNAT, multicast, reservados.
// - Redirecionamentos são seguidos à mão, revalidando cada destino.
// - Tempo total e tamanho máximo da resposta limitados.
//
// Limitação conhecida: entre a checagem do DNS e o fetch o nome é resolvido
// de novo (DNS rebinding). A janela é mínima e a resposta só vira texto para
// o professor — não há credenciais nem efeitos colaterais no pedido.

import { resolve, RR_A, RR_AAAA } from "./dns.ts";
import {
  looksLikeBotChallenge,
  looksLikeLoginUrl,
  MESSAGES,
} from "./link_diagnosis.ts";

export class LinkError extends Error {
  constructor(public code: string, message: string) {
    super(message);
    this.name = "LinkError";
  }
}

const BLOCKED_SUFFIXES = [
  ".localhost",
  ".local",
  ".internal",
  ".intranet",
  ".lan",
  ".home",
  ".corp",
  ".arpa",
];

const MAX_REDIRECTS = 5;

function ipv4ToInt(ip: string): number | null {
  const parts = ip.split(".");
  if (parts.length !== 4) return null;
  let value = 0;
  for (const part of parts) {
    if (!/^\d{1,3}$/.test(part)) return null;
    const n = Number(part);
    if (n > 255) return null;
    value = value * 256 + n;
  }
  return value;
}

function inRange(ip: number, base: string, bits: number): boolean {
  const start = ipv4ToInt(base)!;
  const size = 2 ** (32 - bits);
  return ip >= start && ip < start + size;
}

/** IPv4 que não é endereço público da internet. */
export function isNonPublicIPv4(ip: string): boolean {
  const n = ipv4ToInt(ip);
  if (n === null) return true;
  return [
    ["0.0.0.0", 8], // "esta rede"
    ["10.0.0.0", 8], // privada
    ["100.64.0.0", 10], // CGNAT
    ["127.0.0.0", 8], // loopback
    ["169.254.0.0", 16], // link-local (metadados de nuvem)
    ["172.16.0.0", 12], // privada
    ["192.0.0.0", 24], // reservada (IETF)
    ["192.0.2.0", 24], // documentação
    ["192.168.0.0", 16], // privada
    ["198.18.0.0", 15], // testes de desempenho
    ["198.51.100.0", 24], // documentação
    ["203.0.113.0", 24], // documentação
    ["224.0.0.0", 4], // multicast
    ["240.0.0.0", 4], // reservada + broadcast
  ].some(([base, bits]) => inRange(n, base as string, bits as number));
}

/** IPv6 que não é endereço público da internet. */
export function isNonPublicIPv6(raw: string): boolean {
  const ip = raw.toLowerCase().replace(/^\[|\]$/g, "");
  if (ip === "::" || ip === "::1") return true;
  // IPv4 embutido (::ffff:a.b.c.d, 64:ff9b::a.b.c.d): vale a regra do IPv4.
  const embedded = ip.match(/(\d{1,3}(?:\.\d{1,3}){3})$/);
  if (embedded) return isNonPublicIPv4(embedded[1]);
  if (/^::ffff:/.test(ip)) return true; // mapeado em hexa: bloqueia por garantia
  const first = parseInt(ip.split(":")[0] || "0", 16);
  if (Number.isNaN(first)) return true;
  return (
    (first & 0xfe00) === 0xfc00 || // fc00::/7 privada (ULA)
    (first & 0xffc0) === 0xfe80 || // fe80::/10 link-local
    (first & 0xff00) === 0xff00 || // ff00::/8 multicast
    ip.startsWith("2001:db8:") || // documentação
    ip.startsWith("64:ff9b:") // NAT64
  );
}

function isIPv4Literal(host: string): boolean {
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(host);
}

async function assertPublicUrl(url: URL): Promise<void> {
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new LinkError("invalid_url", MESSAGES.invalidUrl);
  }
  if (url.username || url.password) {
    throw new LinkError("invalid_url", MESSAGES.invalidUrl);
  }
  if (url.port && url.port !== "80" && url.port !== "443") {
    throw new LinkError("blocked", MESSAGES.blocked);
  }

  const host = url.hostname.toLowerCase();
  if (host.startsWith("[")) {
    if (isNonPublicIPv6(host)) {
      throw new LinkError("blocked", MESSAGES.blocked);
    }
    return;
  }
  if (isIPv4Literal(host)) {
    if (isNonPublicIPv4(host)) {
      throw new LinkError("blocked", MESSAGES.blocked);
    }
    return;
  }
  if (
    !host.includes(".") || host === "localhost" ||
    BLOCKED_SUFFIXES.some((suffix) => host.endsWith(suffix))
  ) {
    throw new LinkError("blocked", MESSAGES.blocked);
  }

  const [a, aaaa] = await Promise.all([resolve(host, "A"), resolve(host, "AAAA")]);
  if (a.status === "nxdomain" && aaaa.status !== "ok") {
    throw new LinkError("not_found", MESSAGES.siteNotFound);
  }
  if (a.status === "unknown" && aaaa.status === "unknown") {
    // Sem DNS não dá para garantir que o destino é público: não acessa.
    throw new LinkError("unavailable", MESSAGES.unavailable);
  }
  const ips = [a, aaaa].flatMap((r) =>
    r.status === "ok"
      ? r.answers.filter((x) => x.type === RR_A || x.type === RR_AAAA).map((x) => x.data)
      : []
  );
  if (ips.length === 0) {
    throw new LinkError("not_found", MESSAGES.siteNotFound);
  }
  if (ips.some((ip) => (ip.includes(":") ? isNonPublicIPv6(ip) : isNonPublicIPv4(ip)))) {
    throw new LinkError("blocked", MESSAGES.blocked);
  }
}

export interface FetchedPage {
  finalUrl: URL;
  contentType: string;
  /** Vazio quando o conteúdo não é texto (não é baixado). */
  bytes: Uint8Array;
}

/** Tipos que valem a pena baixar: páginas e texto. */
function isTextual(contentType: string): boolean {
  return contentType === "" || contentType.includes("text/html") ||
    contentType.includes("application/xhtml") || contentType.includes("text/plain");
}

/** Lê até [limit] bytes do corpo (para diagnosticar páginas de erro). */
async function readStart(response: Response, limit = 32 * 1024): Promise<string> {
  const reader = response.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (size < limit) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    size += value.byteLength;
  }
  await reader.cancel().catch(() => {});
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/** Erro para uma resposta HTTP de falha, com o motivo mais provável. */
async function httpProblem(response: Response, url: URL): Promise<LinkError> {
  const status = response.status;
  if (status === 401) return new LinkError("login", MESSAGES.login);
  if (status === 404 || status === 410) {
    await response.body?.cancel();
    return new LinkError("page_not_found", MESSAGES.pageNotFound);
  }
  if (status === 429) {
    await response.body?.cancel();
    return new LinkError("rate_limited", MESSAGES.rateLimited);
  }
  if (status === 403 || status === 503) {
    const start = await readStart(response);
    if (looksLikeBotChallenge(response.headers, start)) {
      return new LinkError("bot_blocked", MESSAGES.botBlocked);
    }
    if (status === 403) {
      return looksLikeLoginUrl(url) || /type=["']?password/i.test(start)
        ? new LinkError("login", MESSAGES.login)
        // 403 sem sinal de login: o site recusou robôs (o caso mais comum).
        : new LinkError("bot_blocked", MESSAGES.botBlocked);
    }
    return new LinkError("site_down", MESSAGES.siteDown(status));
  }
  await response.body?.cancel();
  return status >= 500
    ? new LinkError("site_down", MESSAGES.siteDown(status))
    : new LinkError("http", MESSAGES.siteDown(status));
}

/** Baixa uma página pública. Lança [LinkError] com mensagem para o professor. */
export async function safeFetch(
  rawUrl: string,
  { timeoutMs = 12_000, maxBytes = 3 * 1024 * 1024 } = {},
): Promise<FetchedPage> {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch (_e) {
    throw new LinkError("invalid_url", MESSAGES.invalidUrl);
  }

  const signal = AbortSignal.timeout(timeoutMs);
  try {
    let response: Response | null = null;
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      await assertPublicUrl(url);
      response = await fetch(url, {
        redirect: "manual",
        signal,
        headers: {
          "User-Agent": "Mozilla/5.0 (compatible; ArcangelBot/1.0; +https://arcangels.uk)",
          "Accept": "text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5",
          "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.6",
        },
      });
      const location = response.headers.get("location");
      if (response.status >= 300 && response.status < 400 && location) {
        await response.body?.cancel();
        url = new URL(location, url);
        // Mandou para a tela de login: a página exige estar logado.
        if (looksLikeLoginUrl(url)) throw new LinkError("login", MESSAGES.login);
        response = null;
        continue;
      }
      break;
    }
    if (!response) throw new LinkError("redirects", MESSAGES.redirects);
    if (!response.ok) throw await httpProblem(response, url);

    const contentType = (response.headers.get("content-type") ?? "").toLowerCase();
    // Imagem, vídeo, PDF...: o tipo basta para responder; não baixa o arquivo.
    if (!isTextual(contentType)) {
      await response.body?.cancel();
      return { finalUrl: url, contentType, bytes: new Uint8Array() };
    }

    // Lê em partes para parar assim que passar do limite.
    const reader = response.body?.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    if (reader) {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > maxBytes) {
          await reader.cancel();
          throw new LinkError("too_large", MESSAGES.tooLarge);
        }
        chunks.push(value);
      }
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }

    return { finalUrl: url, contentType, bytes };
  } catch (e) {
    if (e instanceof LinkError) throw e;
    if (signal.aborted) throw new LinkError("timeout", MESSAGES.timeout);
    throw new LinkError("unavailable", MESSAGES.unavailable);
  }
}
