param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ContextContractPath,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [string]$AiOutputText = "",
  [ValidateSet("plan","explain","sql","action")][string]$Mode = "plan",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$ContextContractPath = (Resolve-Path $ContextContractPath).Path

if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_ai_adapter_contract_gate"
}

$Classifier = Join-Path $RepoRoot "scripts\cg_ai_intent_classifier_v1.ps1"
$SchemaGuard = Join-Path $RepoRoot "scripts\cg_ai_schema_guard_v1.ps1"
$DynamicDnd = Join-Path $RepoRoot "scripts\cg_dynamic_dnd_context_v1.ps1"

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function Read-Json([string]$Path){
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}
function Sha256Text([string]$Text){
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir

$ctx = Read-Json $ContextContractPath
$targetRepo = [string]$ctx.target_repo

$decision = "allow_plan_only"
$reasons = New-Object System.Collections.Generic.List[string]
$events = New-Object System.Collections.Generic.List[string]

$events.Add("CONTEXT_CONTRACT_LOADED") | Out-Null
$reasons.Add("AI_BOUND_TO_REPO_CONTEXT") | Out-Null

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

$intent = "unknown"
$risk = "unknown"
$confidence = "unknown"

if(Test-Path -LiteralPath $Classifier -PathType Leaf){
  $classifierJson = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Classifier -Text $Prompt
  if($LASTEXITCODE -eq 0){
    $c = $classifierJson | ConvertFrom-Json -ErrorAction Stop
    $intent = [string]$c.intent
    $risk = [string]$c.risk_level
    $confidence = [string]$c.confidence
    foreach($r in @($c.reason_codes)){ if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasons.Add([string]$r) | Out-Null } }
    $events.Add("INTENT_CLASSIFIED") | Out-Null
  }
}

$schemaGuardDecision = "not_run"
$schemaGuardReasons = @()

if(($Mode -eq "sql" -or $Mode -eq "action") -and -not [string]::IsNullOrWhiteSpace($AiOutputText)){
  $schemaPath = [string]$ctx.schema_contract.path
  if(-not [string]::IsNullOrWhiteSpace($schemaPath) -and (Test-Path -LiteralPath $schemaPath -PathType Leaf) -and (Test-Path -LiteralPath $SchemaGuard -PathType Leaf)){
    $sgOut = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
      -File $SchemaGuard `
      -RepoRoot $RepoRoot `
      -ContractPath $schemaPath `
      -AiOutputText $AiOutputText

    if($LASTEXITCODE -eq 0){
      $schemaGuardDecision = "allow"
      $events.Add("SCHEMA_GUARD_ALLOW") | Out-Null
    } elseif($LASTEXITCODE -eq 2){
      $schemaGuardDecision = "deny"
      $decision = "deny"
      $reasons.Add("SCHEMA_GUARD_DENY") | Out-Null
      $events.Add("SCHEMA_GUARD_DENY") | Out-Null
    } else {
      $schemaGuardDecision = "error"
      $decision = "deny"
      $reasons.Add("SCHEMA_GUARD_ERROR") | Out-Null
      $events.Add("SCHEMA_GUARD_ERROR") | Out-Null
    }

    foreach($line in @($sgOut -split "`n")){
      if($line -match "^CG_AI_SCHEMA_GUARD_REASON_CODES:\s*(.*)$"){
        foreach($r in @($Matches[1] -split ",")){
          if(-not [string]::IsNullOrWhiteSpace($r)){ $reasons.Add($r.Trim()) | Out-Null }
        }
      }
    }
  } else {
    $decision = "deny"
    $reasons.Add("SCHEMA_CONTRACT_REQUIRED_FOR_SQL_OR_ACTION") | Out-Null
    $events.Add("SCHEMA_GUARD_MISSING_CONTRACT") | Out-Null
  }
}

$dynamicDndDecision = "not_run"
if(Test-Path -LiteralPath $DynamicDnd -PathType Leaf){
  $ddOut = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $DynamicDnd `
    -RepoRoot $RepoRoot `
    -TargetRepo $targetRepo `
    -Action export `
    -Intent $intent `
    -RiskLevel $risk `
    -Confidence $confidence `
    -ExternalAi

  if($LASTEXITCODE -eq 0){
    $dynamicDndDecision = "allow"
    $events.Add("DYNAMIC_DND_ALLOW") | Out-Null
  } elseif($LASTEXITCODE -eq 2){
    $dynamicDndDecision = "deny"
    $decision = "deny"
    $reasons.Add("DYNAMIC_DND_DENY") | Out-Null
    $events.Add("DYNAMIC_DND_DENY") | Out-Null
  } else {
    $dynamicDndDecision = "error"
    $decision = "deny"
    $reasons.Add("DYNAMIC_DND_ERROR") | Out-Null
    $events.Add("DYNAMIC_DND_ERROR") | Out-Null
  }

  foreach($line in @($ddOut -split "`n")){
    if($line -match "^CG_DYNAMIC_DND_REASON_CODES:\s*(.*)$"){
      foreach($r in @($Matches[1] -split ",")){
        if(-not [string]::IsNullOrWhiteSpace($r)){ $reasons.Add($r.Trim()) | Out-Null }
      }
    }
  }
}

$result = [ordered]@{
  schema = "covenantgate.ai_adapter_contract_gate.v1"
  context_contract_path = $ContextContractPath
  context_contract_hash = [string]$ctx.context_contract_hash
  target_repo = $targetRepo
  mode = $Mode
  prompt_sha256 = Sha256Text $Prompt
  ai_output_sha256 = Sha256Text $AiOutputText
  classified_intent = $intent
  risk_level = $risk
  confidence = $confidence
  schema_guard_decision = $schemaGuardDecision
  dynamic_dnd_decision = $dynamicDndDecision
  decision = $decision
  reason_codes = @(@($reasons.ToArray()) | Sort-Object -Unique)
  events = @(@($events.ToArray()))
}

$outPath = Join-Path $OutDir ("cg_ai_adapter_contract_gate_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_AI_CONTRACT_GATE_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_AI_CONTRACT_GATE_TARGET: " + $targetRepo)
Write-Host ("CG_AI_CONTRACT_GATE_MODE: " + $Mode)
Write-Host ("CG_AI_CONTRACT_GATE_DECISION: " + $decision)
Write-Host ("CG_AI_CONTRACT_GATE_REASON_CODES: " + ((@($reasons.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_AI_CONTRACT_GATE_EVENTS: " + ((@($events.ToArray())) -join " | "))

if($decision -eq "deny"){
  Write-Host "CG_AI_CONTRACT_GATE_DENY" -ForegroundColor Yellow
  exit 2
}

Write-Host "CG_AI_CONTRACT_GATE_OK" -ForegroundColor Green
exit 0
