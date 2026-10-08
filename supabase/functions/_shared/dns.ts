// Consulta DNS via DNS-over-HTTPS (Cloudflare, com Google de reserva).
// Funciona igual no Edge Runtime local e no de produção, sem depender de
// Deno.resolveDns. Usado na validação de e-mail (MX) e na checagem de links
// (o endereço precisa ser público).

const DNS_TIMEOUT_MS = 3000;

const DOH_RESOLVERS = [
  (name: string, type: string) =>
    `https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(name)}&type=${type}`,
  (name: string, type: string) =>
    `https://dns.google/resolve?name=${encodeURIComponent(name)}&type=${type}`,
];

// Tipos de registro DNS (RFC 1035 / 3596).
export const RR_A = 1;
export const RR_CNAME = 5;
export const RR_MX = 15;
export const RR_AAAA = 28;

export type DnsAnswer = { type: number; data: string };
export type DnsResult =
  | { status: "ok"; answers: DnsAnswer[] }
  | { status: "nxdomain" }
  | { status: "unknown" };

/** "unknown" = nenhum resolvedor respondeu de forma conclusiva. */
export async function resolve(name: string, type: string): Promise<DnsResult> {
  for (const url of DOH_RESOLVERS) {
    try {
      const res = await fetch(url(name, type), {
        headers: { accept: "application/dns-json" },
        signal: AbortSignal.timeout(DNS_TIMEOUT_MS),
      });
      if (!res.ok) continue;
      const body = await res.json() as {
        Status: number;
        Answer?: DnsAnswer[];
      };
      // 0 = NOERROR, 3 = NXDOMAIN; o resto (SERVFAIL...) é inconclusivo.
      if (body.Status === 3) return { status: "nxdomain" };
      if (body.Status === 0) return { status: "ok", answers: body.Answer ?? [] };
    } catch (_e) {
      // Timeout ou erro de rede: tenta o próximo resolvedor.
    }
  }
  return { status: "unknown" };
}
