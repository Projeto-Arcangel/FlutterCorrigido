# Configuração da autenticação (Google · verificação de e-mail · reset de senha)

Guia de referência para conferir a configuração de produção ou montar um ambiente novo.
O código já trata tudo; o que fica fora do repositório é **configuração** (Supabase,
Google Cloud e SMTP).

- App em produção: `https://arcangels.uk` (Cloudflare Pages)
- Projeto Supabase (nuvem): `https://vowloulfqfvgvqzazuea.supabase.co`

> Se o endereço `*.pages.dev` do Cloudflare também for usado, libere os dois domínios nos
> passos abaixo. Como o app é **web**, os redirects usam `Uri.base.origin` — funciona em
> `localhost` e em produção sem endereço fixo no código.

---

## 0. Como funciona

- **Google**: `signInWithOAuth` (redirect de página inteira). Na volta, a sessão é detectada
  e o router decide o destino. Usuário novo (sem nome no perfil) cai na tela "Complete seu perfil"
  e depois escolhe se é aluno ou professor.
- **Verificação de e-mail**: o cadastro manda nome + prontuário no metadata; o trigger
  `handle_new_user` grava o perfil. Com a confirmação ligada, a pessoa só entra **após clicar
  no link do e-mail**.
- **Reset de senha**: o link do e-mail abre o app numa sessão de recuperação → tela
  "Definir nova senha" → `updateUser`.

---

## 1. Banco

O trigger `handle_new_user` (grava nome e prontuário do cadastro) vem nas migrations, junto
com o resto do schema:

```powershell
npx supabase db push
```

---

## 2. Supabase — dashboard da nuvem (Authentication)

### 2.1 URL Configuration
- **Site URL**: `https://arcangels.uk`
- **Redirect URLs** (adicione todas):
  - `https://arcangels.uk`
  - `https://arcangels.uk/**`
  - `http://localhost:3000` e `http://localhost:8080` (para testar o build web local)

### 2.2 Confirmação de e-mail
- **Providers → Email**: **Confirm email = ON**.
  (No local isso já está em `config.toml`: `enable_confirmations = true`.)

### 2.3 Provider Google
- **Providers → Google → Enable**.
- Cole o **Client ID** e o **Client Secret** do OAuth Client do Google Cloud.
- A URL de callback que o Supabase mostra é
  `https://vowloulfqfvgvqzazuea.supabase.co/auth/v1/callback`
  → ela precisa estar no Google Cloud (passo 3).

---

## 3. Google Cloud Console (OAuth 2.0 Client ID, tipo Web application)

- **Authorized JavaScript origins**:
  - `https://arcangels.uk`
  - `https://vowloulfqfvgvqzazuea.supabase.co`
  - `http://localhost:3000` (opcional, para testar local)
- **Authorized redirect URIs**:
  - `https://vowloulfqfvgvqzazuea.supabase.co/auth/v1/callback`

> ⚠️ O redirect do Google aponta para o **Supabase** (não para o app). O Supabase recebe o
> callback do Google e depois manda a pessoa de volta ao app.

---

## 4. SMTP (e-mails de verdade em produção)

Sem SMTP próprio, o Supabase usa um servidor de teste limitado (poucos e-mails por hora, cai
em spam). Para confirmação e reset funcionarem de verdade, configure um SMTP. **Resend** tem
plano grátis e é simples:

1. Crie conta em **resend.com** → verifique um domínio.
2. Gere uma **API key**.
3. No Supabase: **Authentication → Emails (SMTP Settings) → Enable Custom SMTP**:
   - Host: `smtp.resend.com`
   - Port: `465` (SSL) ou `587`
   - User: `resend`
   - Password: a **API key** do Resend
   - Sender email: um endereço do domínio verificado (ex.: `nao-responda@arcangels.uk`)
   - Sender name: `Arcangel`
4. (Opcional) Suba o **rate limit** de e-mails em **Auth → Rate Limits**.

> SendGrid e Mailgun funcionam igual — só trocam host e credenciais.

---

## 5. Cloudflare Pages — fallback de SPA

O repositório já tem `web/_redirects`, que o `flutter build web` copia para `build/web/`:

```
/*    /index.html   200
```

Ele faz qualquer rota abrir o app (sem 404), para os links do OAuth e dos e-mails
funcionarem. Confira que o arquivo foi junto ao publicar a pasta `build/web`.

---

## 6. Testar localmente

1. Suba o stack local (relê o `config.toml` e aplica as migrations):
   ```powershell
   npx supabase stop
   npx supabase start
   ```
2. Rode o app web local numa porta liberada no passo 2.1:
   ```powershell
   fvm flutter run -d edge --web-port 3000 --dart-define-from-file=env/local.json
   ```
3. **Verificação de e-mail**: cadastre-se → o e-mail aparece no **Inbucket**
   (`http://127.0.0.1:54324`) → clique no link → você entra.
4. **Reset de senha**: "Esqueci minha senha" → veja o e-mail no Inbucket → link → defina a nova.
5. **Google local** (opcional): em `config.toml` troque `[auth.external.google] enabled = true`
   e exporte `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` / `_SECRET` antes do `supabase start`.

---

## 7. Subir para produção

```powershell
npx supabase db push
fvm flutter build web --dart-define-from-file=env/prod.json
# publique a pasta build/web no Cloudflare Pages (com o _redirects incluso)
```

E confirme no dashboard do Supabase: Site/Redirect URLs com o domínio de produção, Google
habilitado, Confirm email ON e SMTP configurado.

---

## 8. Senha forte e e-mail real (hook `before-user-created`)

O app orienta e bloqueia antes de enviar; o servidor garante a regra mesmo se alguém
contornar o app.

| Regra | Onde é aplicada |
|---|---|
| Senha: 8+ caracteres, maiúscula, minúscula, número e símbolo | App (`PasswordPolicy`) + Auth (`password_min_length` / `password_required_characters`) |
| E-mail com formato válido e sem erro de digitação no domínio (`gmial.com`) | App (`AuthValidators.signupEmail`) |
| E-mail temporário (mailinator, yopmail…) recusado | Hook → `supabase/functions/before-user-created` |
| Domínio precisa existir e receber e-mail (MX, ou A/AAAA) | Hook (DNS-over-HTTPS) |
| A caixa de e-mail existe de fato | Link de confirmação (**Confirm email ON**) |

O hook só verifica cadastros por e-mail e senha (login com Google passa direto). Se o DNS
estiver instável, ele **libera** o cadastro (a confirmação por e-mail continua protegendo),
para que uma falha de rede não impeça todo mundo de se cadastrar.

**Local:** já vem ligado em `supabase/config.toml`; o segredo fica em `supabase/.env`
(gitignored). O edge runtime local nem sempre recarrega a função sozinho no Windows —
depois de editar o código: `docker restart supabase_edge_runtime_ArcangelCorrigido`.

**Produção** — um comando aplica tudo na ordem segura (segredo → deploy da função → config
do Auth) e testa no final que um e-mail temporário é recusado:

```powershell
# Token pessoal: supabase.com/dashboard/account/tokens (vale só nesta janela)
$env:SUPABASE_ACCESS_TOKEN = "<seu token>"
powershell -ExecutionPolicy Bypass -File .\scripts\apply-auth-hardening.ps1
```

O script altera **somente** a política de senha e o hook — não mexe em Site URL, SMTP,
Google etc. Rodar de novo é seguro (gera e aplica um segredo novo nos dois lados).

---

## Checklist rápido

- [ ] `npx supabase db push` (migrations em dia)
- [ ] Supabase: Site URL + Redirect URLs com o domínio de produção
- [ ] Supabase: Email → Confirm email ON
- [ ] Supabase: Google provider habilitado (Client ID/Secret colados)
- [ ] Google Cloud: origin do app + redirect `.../auth/v1/callback`
- [ ] Supabase: SMTP custom (Resend) habilitado
- [ ] `build/web` publicado com o `_redirects`
- [ ] Senha forte + hook de e-mail real: `scripts/apply-auth-hardening.ps1` (seção 8)
