param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateSet("commit","export","apply","destructive")][string]$Action,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [string]$ConfirmToken = "",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$InputPath = (Resolve-Path $InputPath).Path
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_execution_policy_bridge" }

$ReasonLib = Join-Path $RepoRoot "scripts\_lib_cg_reason_normalize_v1.ps1"
$OverlayPath = Join-Path $RepoRoot "policy\ai_overlay_v1.json"

if(-not (Test-Path -LiteralPath $ReasonLib -PathType Leaf)){ throw ("MISSING_REASON_LIB: " + $ReasonLib) }
if(-not (Test-Path -LiteralPath $OverlayPath -PathType Leaf)){ throw ("MISSING_AI_OVERLAY: " + $OverlayPath) }

. $ReasonLib

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
function Read-Json([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("MISSING_INPUT: " + $Path) }
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}
function Get-Prop($Obj,[string]$Name){
  if($null -eq $Obj){ return $null }
  $m = @($Obj.PSObject.Properties.Match($Name))
  if(@($m).Count -lt 1){ return $null }
  return $m[0].Value
}
function Sha256Text([string]$Text){
  if($null -eq $Text){ $Text = "" }
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function Match-OverlayRule($Rule,[string]$Intent,[string]$Risk,[bool]$NeedsConfirm){
  $match = Get-Prop $Rule "match"
  if($null -eq $match){ return $false }

  $mi = Get-Prop $match "classified_intent"
  $mr = Get-Prop $match "risk_level"
  $mc = Get-Prop $match "requires_confirmation"

  if($null -ne $mi -and [string]$mi -ne $Intent){ return $false }
  if($null -ne $mr -and [string]$mr -ne $Risk){ return $false }
  if($null -ne $mc -and [bool]$mc -ne $NeedsConfirm){ return $false }

  return $true
}

Ensure-Dir $OutDir

$case = Read-Json $InputPath
$overlay = Read-Json $OverlayPath

$eval = Get-Prop $case "eval_input"
$base = Get-Prop $case "base_policy"

$intent = [string](Get-Prop $eval "classified_intent")
$risk   = [string](Get-Prop $eval "risk_level")
$needsConfirm = Get-Prop $eval "requires_confirmation"

if([string]::IsNullOrWhiteSpace($intent)){ $intent = "unknown" }
if([string]::IsNullOrWhiteSpace($risk)){ $risk = "unknown" }
if($null -eq $needsConfirm){ $needsConfirm = $false }

$decision = "allow"
$reasons = New-Object System.Collections.Generic.List[string]
$matchedRules = New-Object System.Collections.Generic.List[string]

if($null -ne $base){
  foreach($rule in @($base.rules)){
    foreach($r in @($rule.reason_codes)){
      if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasons.Add([string]$r) | Out-Null }
    }
  }
}

foreach($rule in @($overlay.rules)){
  if(Match-OverlayRule $rule $intent $risk ([bool]$needsConfirm)){
    $rid = [string](Get-Prop $rule "rule_id")
    if(-not [string]::IsNullOrWhiteSpace($rid)){ $matchedRules.Add($rid) | Out-Null }

    $rd = [string](Get-Prop $rule "decision")
    foreach($r in @($rule.reason_codes)){
      if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasons.Add([string]$r) | Out-Null }
    }

    if($rd -eq "deny"){
      $decision = "deny"
    }
    elseif($rd -eq "deny_without_confirm_token"){
      if($ConfirmToken -ne "I_UNDERSTAND_DESTRUCTIVE_ACTION"){ $decision = "deny" }
    }
    elseif($rd -eq "allow"){
      if($decision -ne "deny"){ $decision = "allow" }
    }
  }
}

if($Action -eq "destructive" -and $ConfirmToken -ne "I_UNDERSTAND_DESTRUCTIVE_ACTION"){
  $decision = "deny"
  $reasons.Add("CONFIRMATION_REQUIRED") | Out-Null
}

if($Action -eq "commit" -and $risk -eq "critical"){
  $decision = "deny"
  $reasons.Add("CRITICAL_RISK") | Out-Null
}

if($Action -eq "apply" -and ($risk -eq "critical" -or $intent -eq "destructive")){
  $decision = "deny"
  $reasons.Add("CRITICAL_RISK") | Out-Null
}

$normalizedReasons = @(CG-NormalizeReasonCodes -ReasonCodes @($reasons.ToArray()))
$reasonText = (@($normalizedReasons) | Sort-Object -Unique) -join ","
$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")

$result = [ordered]@{
  schema = "covenantgate.execution_policy_bridge.v1"
  run_id = $runId
  action = $Action
  input_path = $InputPath
  input_sha256 = Sha256Text (Get-Content -LiteralPath $InputPath -Raw)
  overlay_path = $OverlayPath
  overlay_sha256 = Sha256Text (Get-Content -LiteralPath $OverlayPath -Raw)
  matched_rules = @(@($matchedRules.ToArray()))
  classified_intent = $intent
  risk_level = $risk
  requires_confirmation = [bool]$needsConfirm
  decision = $decision
  reason_codes = @(@($normalizedReasons))
}

$outPath = Join-Path $OutDir ("cg_execution_policy_bridge_" + $runId + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 30 -Compress))

Write-Host ("CG_EXECUTION_BRIDGE_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_EXECUTION_BRIDGE_ACTION: " + $Action)
Write-Host ("CG_EXECUTION_BRIDGE_INTENT: " + $intent)
Write-Host ("CG_EXECUTION_BRIDGE_RISK: " + $risk)
Write-Host ("CG_EXECUTION_BRIDGE_DECISION: " + $decision)
Write-Host ("CG_EXECUTION_BRIDGE_REASON_CODES: " + $reasonText)

if($decision -eq "allow"){
  Write-Host "CG_EXECUTION_POLICY_BRIDGE_OK" -ForegroundColor Green
  exit 0
}

Write-Host "CG_EXECUTION_POLICY_BRIDGE_DENY" -ForegroundColor Yellow
exit 2
