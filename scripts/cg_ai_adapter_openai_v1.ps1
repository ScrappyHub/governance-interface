param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ContextContractPath,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [ValidateSet("stub","openai")][string]$Adapter = "stub",
  [string]$Model = "gpt-4.1-mini",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$ContextContractPath = (Resolve-Path $ContextContractPath).Path
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_ai_adapter_openai" }

function Ensure-Dir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function Sha256Text([string]$Text){
  if($null -eq $Text){ $Text = "" }
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir
$ctx = Get-Content -LiteralPath $ContextContractPath -Raw | ConvertFrom-Json -ErrorAction Stop
$ctxRaw = Get-Content -LiteralPath $ContextContractPath -Raw

$responseText = ""

if($Adapter -eq "stub"){
  if($Prompt -match "users\.password_hash|from users"){
    $responseText = "select users.password_hash from users;"
  } elseif($Prompt -match "valid sql|appointments|memberships"){
    $responseText = "select memberships.id, memberships.role from memberships join appointments on appointments.membership_id = memberships.id;"
  } elseif($Prompt -match "delete|wipe|destroy"){
    $responseText = "I will not perform destructive work. Generate a governed plan only."
  } else {
    $responseText = "Plan only. Context loaded for " + [string]$ctx.target_name + ". No mutation or execution requested."
  }
}

if($Adapter -eq "openai"){
  if([string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)){ throw "OPENAI_API_KEY_MISSING" }

  $system = "You are bound to a Covenant Gate repo context contract. You must obey it. Do not invent schema, files, policies, feature flags, or actions. Return a concise answer only."
  $inputText = $system + "`n`nCONTEXT_CONTRACT_JSON:`n" + $ctxRaw + "`n`nUSER_PROMPT:`n" + $Prompt

  $body = [ordered]@{
    model = $Model
    input = $inputText
  } | ConvertTo-Json -Depth 30 -Compress

  $headers = @{
    "Authorization" = "Bearer " + $env:OPENAI_API_KEY
    "Content-Type" = "application/json"
  }

  $resp = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/responses" -Headers $headers -Body $body

  if($null -ne $resp.output_text){
    $responseText = [string]$resp.output_text
  } else {
    $responseText = ($resp | ConvertTo-Json -Depth 50 -Compress)
  }
}

$result = [ordered]@{
  schema = "covenantgate.ai_adapter.openai.v1"
  adapter = $Adapter
  model = $Model
  context_contract_path = $ContextContractPath
  context_contract_hash = [string]$ctx.context_contract_hash
  prompt_sha256 = Sha256Text $Prompt
  response_sha256 = Sha256Text $responseText
  response_text = $responseText
}

$outPath = Join-Path $OutDir ("cg_ai_adapter_openai_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_AI_ADAPTER_OPENAI_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_AI_ADAPTER_OPENAI_MODE: " + $Adapter)
Write-Host ("CG_AI_ADAPTER_OPENAI_RESPONSE_SHA256: " + $result.response_sha256)
Write-Host "CG_AI_ADAPTER_OPENAI_OK" -ForegroundColor Green
