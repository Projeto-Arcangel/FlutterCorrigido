// Auth Hook (HTTP): before-user-created
//
// O Supabase Auth chama esta função ANTES de criar cada usuário. Para
// cadastros por e-mail/senha, recusa e-mails que certamente não são reais
// (formato inválido, domínio temporário, domínio inexistente ou sem e-mail —
// ver ../_shared/email_validation.ts). Logins sociais (Google) já vêm com
// e-mail verificado pelo provedor e passam direto.
//
// Segurança: a requisição é assinada pelo Auth (Standard Webhooks). Sem
// assinatura válida → 401, então ninguém de fora consegue usar a função.
// Segredo: BEFORE_USER_CREATED_HOOK_SECRET ("v1,whsec_...") — o MESMO valor
// configurado no hook (config.toml local / painel ou Management API em prod).
//
// Deploy: supabase functions deploy before-user-created --no-verify-jwt
// (o Auth não manda JWT de usuário; a proteção é a assinatura acima).

import { Webhook } from "npm:standardwebhooks@1.0.0";
import { checkSignupEmail } from "../_shared/email_validation.ts";

type HookPayload = {
  user?: {
    email?: string;
    app_metadata?: { provider?: string };
  };
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// Recusa o cadastro. O status HTTP TEM de ser 200: o Auth só lê o objeto
// `error` em respostas 200/202 (com outro status ele responde "Invalid payload
// sent to hook", erro 500). O app recebe `message` com error_code "unknown",
// por isso o motivo vai como prefixo "[codigo]": o app traduz pelo código
// (ErrorMessages.auth) e o texto depois dele serve de reserva.
function reject(code: string, message: string): Response {
  return json(200, { error: { http_code: 400, message: `[${code}] ${message}` } });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Método não permitido." });

  const secret = Deno.env.get("BEFORE_USER_CREATED_HOOK_SECRET");
  if (!secret) {
    // Mal configurado: não bloqueia cadastros por um erro nosso.
    console.error("BEFORE_USER_CREATED_HOOK_SECRET ausente — validação ignorada.");
    return json(200, {});
  }

  const raw = await req.text();
  let payload: HookPayload;
  try {
    const wh = new Webhook(secret.replace("v1,whsec_", ""));
    payload = wh.verify(raw, Object.fromEntries(req.headers)) as HookPayload;
  } catch (_e) {
    return json(401, { error: "Assinatura inválida." });
  }

  const user = payload.user ?? {};
  const provider = user.app_metadata?.provider ?? "email";
  if (provider !== "email" || !user.email) return json(200, {});

  const check = await checkSignupEmail(user.email);
  if (check.ok) {
    if (check.reason) {
      console.warn(`email check inconclusivo (${check.reason}) — liberado.`);
    }
    return json(200, {});
  }

  console.log(`cadastro recusado: ${check.code}`);
  return reject(check.code, check.message);
});
