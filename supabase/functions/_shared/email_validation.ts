// Validação de "e-mail real" no cadastro (usada pelo hook before-user-created).
//
// Camadas, da mais barata para a mais cara:
//   1. Formato do endereço.
//   2. Domínio de e-mail temporário/descartável (lista em disposable_domains.ts).
//   3. DNS: o domínio precisa existir e aceitar e-mail (registro MX, ou A/AAAA
//      como fallback — RFC 5321 §5.1). "Null MX" (RFC 7505) = não recebe e-mail.
//
// Não dá para provar que a CAIXA existe sem enviar uma mensagem: isso é o que o
// link de confirmação faz (enable_confirmations = true). Esta validação barra
// antes o que certamente não é um e-mail utilizável.
//
// DNS via DNS-over-HTTPS (Cloudflare, com Google de reserva) para funcionar
// igual no Edge Runtime local e no de produção. Se o DNS falhar por
// instabilidade (timeout, erro de servidor), o cadastro é LIBERADO (fail-open):
// a confirmação por e-mail continua protegendo, e um problema de rede nosso
// não pode impedir todo mundo de se cadastrar.

import { isDisposableDomain } from "./disposable_domains.ts";
import { resolve, RR_A, RR_AAAA, RR_MX } from "./dns.ts";

export type EmailCheck =
  | { ok: true; reason?: string }
  | { ok: false; code: string; message: string };

const EMAIL_PATTERN =
  /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,}$/;

export async function checkSignupEmail(rawEmail: string): Promise<EmailCheck> {
  const email = rawEmail.trim().toLowerCase();
  if (!EMAIL_PATTERN.test(email) || email.includes("..")) {
    return {
      ok: false,
      code: "email_invalid_format",
      message: "E-mail inválido. Confira o endereço digitado.",
    };
  }

  const domain = email.slice(email.lastIndexOf("@") + 1);

  if (isDisposableDomain(domain)) {
    return {
      ok: false,
      code: "email_disposable",
      message: "E-mails temporários não são aceitos. Use um e-mail pessoal " +
        "ou institucional.",
    };
  }

  const mx = await resolve(domain, "MX");
  if (mx.status === "unknown") return { ok: true, reason: "dns_unavailable" };

  if (mx.status === "ok") {
    const mxRecords = mx.answers.filter((a) => a.type === RR_MX);
    if (mxRecords.length > 0) {
      // Null MX: "0 ." declara explicitamente que o domínio não recebe e-mail.
      const nullMx = mxRecords.every((r) => r.data.trim().endsWith(" ."));
      return nullMx ? noMail() : { ok: true };
    }
  }

  // Sem MX (ou domínio inexistente): RFC 5321 permite entregar no A/AAAA.
  if (mx.status === "nxdomain") return noMail();
  const [a, aaaa] = await Promise.all([
    resolve(domain, "A"),
    resolve(domain, "AAAA"),
  ]);
  if (a.status === "unknown" || aaaa.status === "unknown") {
    return { ok: true, reason: "dns_unavailable" };
  }
  const hasAddress = [a, aaaa].some((r) =>
    r.status === "ok" &&
    r.answers.some((x) => x.type === RR_A || x.type === RR_AAAA)
  );
  return hasAddress ? { ok: true } : noMail();
}

function noMail(): EmailCheck {
  return {
    ok: false,
    code: "email_domain_invalid",
    message: "Este domínio de e-mail não existe ou não recebe mensagens. " +
      "Confira o endereço digitado.",
  };
}
