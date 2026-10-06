<#
.SYNOPSIS
  Aplica no Supabase de PRODUÇÃO a política de senha forte e a validação de
  e-mail real (hook before-user-created). Ver docs/auth-setup.md, seção 8.

.DESCRIPTION
  Ordem segura (cadastros não quebram no meio do caminho):
    1. Lê a config atual do Auth e avisa se a confirmação de e-mail estiver
       desligada (é ela que prova que a caixa de e-mail existe).
    2. Gera um segredo novo para o hook e o grava nas secrets das Edge
       Functions.
    3. Publica a função before-user-created (sem verificação de JWT: quem a
       chama é o próprio Auth, com assinatura Standard Webhooks).
    4. Atualiza SÓ estes campos do Auth (Management API, PATCH parcial):
       senha mínima 8 + maiúscula/minúscula/número/símbolo, e o hook ligado.
    5. Confere a config e faz um teste: cadastro com e-mail temporário tem de
       ser recusado (nenhum usuário é criado).

  Requer um Personal Access Token do Supabase na variável de ambiente
  SUPABASE_ACCESS_TOKEN (supabase.com/dashboard/account/tokens). O token não
  é gravado em lugar nenhum por este script.

.EXAMPLE
  $env:SUPABASE_ACCESS_TOKEN = "<seu token>"   # só nesta janela do terminal
  .\scripts\apply-auth-hardening.ps1
#>
param(
  [string]$ProjectRef = 'vowloulfqfvgvqzazuea'
)

$ErrorActionPreference = 'Stop'

if (-not $env:SUPABASE_ACCESS_TOKEN) {
  throw 'Defina SUPABASE_ACCESS_TOKEN (token pessoal do Supabase) antes de rodar.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $env:LOCALAPPDATA 'SupabaseCLI\supabase.exe'
if (-not (Test-Path $cli)) { $cli = 'supabase' }

$api = "https://api.supabase.com/v1/projects/$ProjectRef"
$headers = @{ Authorization = "Bearer $($env:SUPABASE_ACCESS_TOKEN)" }

# Opção "minúsculas, maiúsculas, números e símbolos" da Management API. O valor
# tem de ser EXATAMENTE este (a API só aceita as opções da lista dela) — com
# duas barras invertidas antes do ":".
$requiredCharacters = 'abcdefghijklmnopqrstuvwxyz:ABCDEFGHIJKLMNOPQRSTUVWXYZ:0123456789:!@#$%^&*()_+-=[]{};''\\:"|<>?,./`~'

function Show-AuthConfig($config, [string]$title) {
  Write-Host "`n== $title" -ForegroundColor Cyan
  Write-Host ("  senha mínima ............ {0}" -f $config.password_min_length)
  Write-Host ("  caracteres exigidos ..... {0}" -f $config.password_required_characters)
  Write-Host ("  confirmação de e-mail ... {0}" -f (-not $config.mailer_autoconfirm))
  Write-Host ("  hook before-user-created  {0} {1}" -f $config.hook_before_user_created_enabled, $config.hook_before_user_created_uri)
}

# 1. Config atual -------------------------------------------------------------
$before = Invoke-RestMethod -Uri "$api/config/auth" -Headers $headers
Show-AuthConfig $before 'Antes'
if ($before.mailer_autoconfirm) {
  Write-Warning ('A confirmação de e-mail está DESLIGADA em produção. Sem ela, ' +
    'ninguém prova que a caixa de e-mail existe. Ligue em Authentication > ' +
    'Sign In / Providers > Email > "Confirm email".')
}

# 2. Segredo do hook ------------------------------------------------------------
$bytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$hookSecret = 'v1,whsec_' + [Convert]::ToBase64String($bytes)

Push-Location $repoRoot
try {
  Write-Host "`n== Gravando o segredo da função" -ForegroundColor Cyan
  & $cli secrets set "BEFORE_USER_CREATED_HOOK_SECRET=$hookSecret" --project-ref $ProjectRef
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao gravar a secret da função.' }

  # 3. Deploy da função -------------------------------------------------------
  Write-Host "`n== Publicando a função before-user-created" -ForegroundColor Cyan
  & $cli functions deploy before-user-created --project-ref $ProjectRef --no-verify-jwt
  if ($LASTEXITCODE -ne 0) { throw 'Falha no deploy da função.' }
}
finally {
  Pop-Location
}

# 4. Config do Auth ------------------------------------------------------------
function Update-AuthConfig([hashtable]$fields) {
  $body = $fields | ConvertTo-Json
  Invoke-RestMethod -Uri "$api/config/auth" -Method Patch -Headers $headers `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
}

# 4a. Hook PRIMEIRO e sozinho: a função acabou de receber o segredo novo, então
# o hook precisa do mesmo valor já — se algo falhar depois, os dois lados
# continuam em sincronia e os cadastros funcionam.
Write-Host "`n== Ligando o hook com o segredo novo" -ForegroundColor Cyan
Update-AuthConfig @{
  hook_before_user_created_enabled = $true
  hook_before_user_created_uri     = "https://$ProjectRef.supabase.co/functions/v1/before-user-created"
  hook_before_user_created_secrets = $hookSecret
}

# 4b. Política de senha (pulada se já estiver aplicada).
$hasSymbolsRule = "$($before.password_required_characters)".Contains('!@#$%^&*')
if ($before.password_min_length -ge 8 -and $hasSymbolsRule) {
  Write-Host "`n== Política de senha já aplicada — nada a mudar" -ForegroundColor Cyan
}
else {
  Write-Host "`n== Aplicando a política de senha" -ForegroundColor Cyan
  Update-AuthConfig @{
    password_min_length          = 8
    password_required_characters = $requiredCharacters
  }
}

# 5. Verificação ----------------------------------------------------------------
$after = Invoke-RestMethod -Uri "$api/config/auth" -Headers $headers
Show-AuthConfig $after 'Depois'

# reveal=true: sem ele a API devolve as chaves mascaradas e o teste sai sem
# apikey ("Resposta inesperada" vazia).
$keys = Invoke-RestMethod -Uri "$api/api-keys?reveal=true" -Headers $headers
$anon = ($keys | Where-Object { $_.type -eq 'publishable' -or $_.name -eq 'anon' } |
  Select-Object -First 1).api_key

Write-Host "`n== Teste: e-mail temporário deve ser recusado" -ForegroundColor Cyan
$probe = @{ email = "teste-hook-$([guid]::NewGuid().ToString('N').Substring(0, 8))@mailinator.com"; password = 'Senha@123teste' } | ConvertTo-Json
try {
  Invoke-RestMethod -Uri "https://$ProjectRef.supabase.co/auth/v1/signup" -Method Post `
    -Headers @{ apikey = $anon } -ContentType 'application/json' -Body $probe | Out-Null
  Write-Warning 'O cadastro de teste NÃO foi recusado — confira os logs da função no painel.'
}
catch {
  $detail = $_.ErrorDetails.Message
  if ($detail -match 'email_disposable') {
    Write-Host '  OK: recusado como e-mail temporário.' -ForegroundColor Green
  }
  else {
    Write-Warning "Resposta inesperada: $detail"
  }
}
