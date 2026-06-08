# Configuração da autenticação (Google · verificação de e-mail · reset de senha)

O **código** já está pronto. O que falta é **configuração** (Supabase, Google Cloud, SMTP)
e o **deploy**. Este guia cobre tudo, passo a passo.

- Projeto Supabase (nuvem): `https://vowloulfqfvgvqzazuea.supabase.co`
- Substitua `https://SEU-APP.pages.dev` pelo **domínio real do seu app no Cloudflare**.

> Como o app é **web**, os redirects usam `Uri.base.origin` automaticamente — funciona
> em `localhost` e no Cloudflare sem hardcode. Só é preciso **liberar** o domínio no Supabase.

---

## 0. O que o código faz agora

- **Google**: `signInWithOAuth` (redirect de página inteira). Na volta, a sessão é detectada
  e o router decide o destino. Usuário novo (sem nome no perfil) cai na tela "Complete seu perfil".
- **Verificação de e-mail**: o cadastro manda nome + prontuário no metadata; o trigger
  `handle_new_user` grava o perfil. Com a confirmação ligada, o aluno só entra **após clicar
  no link do e-mail**.
- **Reset de senha**: o link do e-mail abre o app numa sessão de recuperação → tela
  "Definir nova senha" → `updateUser`.

---

## 1. Aplicar a migration nova

A migration `20260608120000_handle_new_user_student_id.sql` faz o trigger gravar o prontuário.

```powershell
# Local (para testar):
npx supabase migration up

# Nuvem (produção):
npx supabase db push
```

---

## 2. Supabase — dashboard da nuvem (Authentication)

Acesse **Authentication** no dashboard do projeto.

### 2.1 URL Configuration
- **Site URL**: `https://SEU-APP.pages.dev`
- **Redirect URLs** (adicione todas):
  - `https://SEU-APP.pages.dev`
  - `https://SEU-APP.pages.dev/**`
  - `http://localhost:3000` e `http://localhost:8080` (para testar build web local)

### 2.2 Confirmação de e-mail
- **Providers → Email**: deixe **Confirm email = ON** (ligado).
  (No local isso já está em `config.toml`: `enable_confirmations = true`.)

### 2.3 Provider Google
- **Providers → Google → Enable**.
- Cole o **Client ID** e o **Client Secret** do seu OAuth Client (você já tem).
- Salve. A URL de callback que o Supabase mostra é:
  `https://vowloulfqfvgvqzazuea.supabase.co/auth/v1/callback`
  → essa URL precisa estar no Google Cloud (passo 3).

---

## 3. Google Cloud Console (o OAuth Client que você já criou)

No seu **OAuth 2.0 Client ID (tipo Web application)**:

- **Authorized JavaScript origins**:
  - `https://SEU-APP.pages.dev`
  - `https://vowloulfqfvgvqzazuea.supabase.co`
  - `http://localhost:3000` (opcional, para testar local)
- **Authorized redirect URIs**:
  - `https://vowloulfqfvgvqzazuea.supabase.co/auth/v1/callback`

> ⚠️ O redirect do Google aponta para o **Supabase** (não para o seu app). O Supabase é
> quem recebe o callback do Google e depois manda o usuário de volta ao app.

---

## 4. SMTP (e-mails de verdade em produção)

Sem SMTP próprio, o Supabase usa um servidor de teste limitado (poucos e-mails/hora, cai em
spam). Para confirmação + reset funcionarem de verdade, configure um SMTP. **Resend** tem
plano grátis e é simples:

1. Crie conta em **resend.com** → verifique um domínio (ou use o domínio de teste deles no começo).
2. Gere uma **API key**.
3. No Supabase: **Authentication → Emails (SMTP Settings) → Enable Custom SMTP**:
   - Host: `smtp.resend.com`
   - Port: `465` (SSL) ou `587`
   - User: `resend`
   - Password: a **API key** do Resend
   - Sender email: um endereço do domínio verificado (ex.: `nao-responda@seudominio.com`)
   - Sender name: `Arcangel`
4. (Opcional) Suba o **rate limit** de e-mails em **Auth → Rate Limits**.

> SendGrid/Mailgun funcionam igual — só trocam host/credenciais.

---

## 5. Cloudflare Pages — fallback de SPA (recomendado)

Para os redirects de e-mail/OAuth abrirem qualquer rota sem dar 404, adicione um arquivo
`web/_redirects` (vai junto no build) com:

```
/*    /index.html   200
```

Isso garante que `https://SEU-APP.pages.dev/...` sempre carregue o app.

---

## 6. Testar localmente (antes de subir)

1. Aplique config + migration no stack local:
   ```powershell
   npx supabase stop
   npx supabase start   # relê o config.toml (enable_confirmations) e aplica migrations
   ```
2. Rode o app web local:
   ```powershell
   flutter run -d chrome --web-port 3000 --dart-define-from-file=env/local.json
   ```
3. **Verificação de e-mail**: cadastre-se → o e-mail aparece no **Inbucket**
   (`http://127.0.0.1:54324`) → clique no link → você entra.
4. **Reset de senha**: "Esqueci minha senha" → veja o e-mail no Inbucket → link → defina a nova.
5. **Google local** (opcional): em `config.toml` troque `[auth.external.google] enabled = true`
   e exporte `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` / `_SECRET` antes do `supabase start`.

---

## 7. Subir para produção

```powershell
npx supabase db push          # migration do trigger na nuvem
flutter build web --dart-define-from-file=env/prod.json
# publique a pasta build/web no Cloudflare Pages (com o web/_redirects incluso)
```

E confirme no dashboard do Supabase: Site/Redirect URLs com o domínio Cloudflare, Google
habilitado, Confirm email ON e SMTP configurado.

---

## Checklist rápido

- [ ] `supabase db push` (migration do trigger)
- [ ] Supabase: Site URL + Redirect URLs com o domínio Cloudflare
- [ ] Supabase: Email → Confirm email ON
- [ ] Supabase: Google provider habilitado (Client ID/Secret colados)
- [ ] Google Cloud: origin do app + redirect `.../auth/v1/callback`
- [ ] Supabase: SMTP custom (Resend) habilitado
- [ ] `web/_redirects` com fallback de SPA
- [ ] Rebuild + redeploy do web no Cloudflare