param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateSet("deterministic","external-file")][string]$Mode,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [string]$ExternalResponsePath = "",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot "watch_inputs" }

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function Sha256Text([string]$Text){
  $bytes = [System.Text.Encoding]::UTF8.GetBytes((($Text -replace "`r`n","`n") -replace "`r","`n"))
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir

$response = ""
$adapter = ""

if($Mode -eq "deterministic"){
  $adapter = "covenantgate.deterministic.local.v1"

  if($Prompt -match "delete|format|wipe|destroy|remove"){
    $response = "Request appears destructive. Governance review required before execution."
  } elseif($Prompt -match "commit|ship|release|tag"){
    $response = "Request appears to require execution gating before commit or release."
  } else {
    $response = "Conversation captured. No destructive intent detected. Governance review can proceed."
  }
}

if($Mode -eq "external-file"){
  $adapter = "covenantgate.external_file_adapter.v1"
  if([string]::IsNullOrWhiteSpace($ExternalResponsePath)){ throw "MISSING_EXTERNAL_RESPONSE_PATH" }
  $ExternalResponsePath = (Resolve-Path $ExternalResponsePath).Path
  $response = [System.IO.File]::ReadAllText($ExternalResponsePath,(New-Object System.Text.UTF8Encoding($false)))
}

$Classifier = Join-Path $RepoRoot "scripts\cg_ai_intent_classifier_v1.ps1"
if(-not (Test-Path -LiteralPath $Classifier -PathType Leaf)){ throw ("MISSING_CLASSIFIER: " + $Classifier) }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$classifierJson = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Classifier -Text ($Prompt + "`n" + $response)
if($LASTEXITCODE -ne 0){ throw ("CLASSIFIER_EXIT_NONZERO: " + $LASTEXITCODE) }
$classifier = ($classifierJson | ConvertFrom-Json -ErrorAction Stop)

$promptHash = Sha256Text $Prompt
$responseHash = Sha256Text $response

$decision = "allow"
$reasons = New-Object System.Collections.Generic.List[string]
foreach($cr in @(@($classifier.reason_codes))){
  if(-not [string]::IsNullOrWhiteSpace([string]$cr)){ $reasons.Add([string]$cr) | Out-Null }
}
if([bool]$classifier.requires_confirmation -eq $true){
  $decision = "deny"
  $reasons.Add("CLASSIFIER_REQUIRES_CONFIRMATION") | Out-Null
}

if($response -match "destructive|delete|format|wipe|destroy"){
  $decision = "deny"
  $reasons.Add("AI_OR_PROMPT_REQUIRES_EXECUTION_GATE") | Out-Null
}
if($Mode -eq "external-file"){
  $reasons.Add("EXTERNAL_AI_OUTPUT_REQUIRES_GOVERNANCE") | Out-Null
}
if(@($reasons.ToArray()).Count -eq 0){
  $reasons.Add("CONVERSATION_CAPTURED") | Out-Null
}

$case = [ordered]@{
  case_id = "conversation_adapter_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmssZ")
  base_policy = [ordered]@{
    policy_id = "cg.conversation.adapter.policy.v1"
    default_decision = "deny"
    rules = @(
      [ordered]@{
        rule_id = "conversation_adapter_result"
        decision = $decision
        reason_codes = @(@($reasons.ToArray()))
      }
    )
  }
  overlay_policy = $null
  eval_input = [ordered]@{
    input_id = "conversation:" + $promptHash
    adapter = $adapter
    mode = $Mode
    prompt_sha256 = $promptHash
    response_sha256 = $responseHash
    classified_intent = [string]$classifier.intent
    risk_level = [string]$classifier.risk_level
    confidence = [string]$classifier.confidence
    requires_confirmation = [bool]$classifier.requires_confirmation
    prompt_preview = $Prompt.Substring(0,[Math]::Min(160,$Prompt.Length))
    response_preview = $response.Substring(0,[Math]::Min(240,$response.Length))
  }
}

$outPath = Join-Path $OutDir ("conversation_adapter_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmssZ") + ".json")
Write-Utf8NoBomLf $outPath (($case | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_CONVERSATION_ADAPTER_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_CONVERSATION_ADAPTER_DECISION: " + $decision) -ForegroundColor Yellow
Write-Host ("CG_CONVERSATION_ADAPTER_REASON_CODES: " + ((@($reasons.ToArray())) -join ",")) -ForegroundColor Yellow
Write-Host "CG_CONVERSATION_ADAPTER_OK" -ForegroundColor Green
