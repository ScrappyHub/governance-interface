param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo,
  [Parameter(Mandatory=$true)][ValidateSet("export","test","commit-plan","release-plan","destructive")][string]$Action,
  [string]$Intent = "",
  [string]$RiskLevel = "",
  [string]$Confidence = "",
  [switch]$ExternalAi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

$PolicyPath = Join-Path $RepoRoot "policy\dynamic_dnd_policy_v1.json"
$UnlockRoot = Join-Path $RepoRoot "proofs\receipts\cg_re_eval_unlock"
$OutRoot = Join-Path $RepoRoot "proofs\receipts\cg_dynamic_dnd_context"

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
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("MISSING_JSON: " + $Path) }
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}
function Get-Prop($Obj,[string]$Name){
  if($null -eq $Obj){ return $null }
  $m = @($Obj.PSObject.Properties.Match($Name))
  if(@($m).Count -lt 1){ return $null }
  return $m[0].Value
}
function Rel([string]$Path,[string]$Root){
  return $Path.Substring($Root.Length).TrimStart("\").Replace("\","/")
}
function Test-RuleMatch($When,$Context){
  $missingGt = Get-Prop $When "missing_count_gt"
  if($null -ne $missingGt){
    if([int]$Context.missing_count -le [int]$missingGt){ return $false }
  }

  $risk = Get-Prop $When "risk_level"
  if($null -ne $risk){
    if([string]$Context.risk_level -ne [string]$risk){ return $false }
  }

  $action = Get-Prop $When "action"
  if($null -ne $action){
    if([string]$Context.action -ne [string]$action){ return $false }
  }

  $actionIn = Get-Prop $When "action_in"
  if($null -ne $actionIn){
    $ok = $false
    foreach($a in @($actionIn)){ if([string]$Context.action -eq [string]$a){ $ok = $true } }
    if(-not $ok){ return $false }
  }

  $confNotIn = Get-Prop $When "confidence_not_in"
  if($null -ne $confNotIn){
    foreach($c in @($confNotIn)){
      if([string]$Context.confidence -eq [string]$c){ return $false }
    }
  }

  $externalAi = Get-Prop $When "external_ai"
  if($null -ne $externalAi){
    if([bool]$Context.external_ai -ne [bool]$externalAi){ return $false }
  }

  $secretFound = Get-Prop $When "secret_material_found"
  if($null -ne $secretFound){
    if([bool]$Context.secret_material_found -ne [bool]$secretFound){ return $false }
  }

  $runtimeFound = Get-Prop $When "runtime_artifacts_found"
  if($null -ne $runtimeFound){
    if([bool]$Context.runtime_artifacts_found -ne [bool]$runtimeFound){ return $false }
  }

  return $true
}

if(-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)){ throw "DYNAMIC_DND_POLICY_MISSING" }

$policy = Read-Json $PolicyPath

$missingCount = 999
$executionAllowed = $false
$unlockSummaryPath = ""

if(Test-Path -LiteralPath $UnlockRoot -PathType Container){
  $latest = @(Get-ChildItem -LiteralPath $UnlockRoot -Directory | Sort-Object Name | Select-Object -Last 1)
  if(@($latest).Count -gt 0){
    $unlockSummaryPath = Join-Path $latest[0].FullName "summary.json"
    if(Test-Path -LiteralPath $unlockSummaryPath -PathType Leaf){
      $unlock = Read-Json $unlockSummaryPath
      $missingCount = [int]$unlock.missing_count
      $executionAllowed = [bool]$unlock.execution_allowed
    }
  }
}

$files = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -ErrorAction Stop) | Where-Object {
  $_.FullName -notmatch "\\\.git\\" -and
  $_.FullName -notmatch "\\node_modules\\"
})

$secretMaterialFound = $false
$runtimeArtifactsFound = $false
$secretHits = New-Object System.Collections.Generic.List[string]
$runtimeHits = New-Object System.Collections.Generic.List[string]

foreach($f in @($files)){
  $r = Rel $f.FullName $TargetRepo
  if($r -like "*.env" -or $r -like "*.key" -or $r -like "id_ed25519" -or $r -like "key_export/*" -or $r -like ".secrets/*"){
    $secretMaterialFound = $true
    $secretHits.Add($r) | Out-Null
  }
  if($r -like "runtime/*" -or $r -like "proofs/_tmp/*" -or $r -like "node_modules/*"){
    $runtimeArtifactsFound = $true
    $runtimeHits.Add($r) | Out-Null
  }
}

if([string]::IsNullOrWhiteSpace($Intent)){ $Intent = "unknown" }
if([string]::IsNullOrWhiteSpace($RiskLevel)){ $RiskLevel = "unknown" }
if([string]::IsNullOrWhiteSpace($Confidence)){ $Confidence = "unknown" }

$context = [ordered]@{
  action = $Action
  target_repo = $TargetRepo
  execution_allowed = $executionAllowed
  missing_count = $missingCount
  intent = $Intent
  risk_level = $RiskLevel
  confidence = $Confidence
  external_ai = [bool]$ExternalAi
  secret_material_found = $secretMaterialFound
  runtime_artifacts_found = $runtimeArtifactsFound
  secret_hits = @(@($secretHits.ToArray()) | Sort-Object -Unique)
  runtime_hits = @(@($runtimeHits.ToArray()) | Sort-Object -Unique)
}

$decision = "allow"
$matchedRules = New-Object System.Collections.Generic.List[string]
$reasons = New-Object System.Collections.Generic.List[string]

if(-not $executionAllowed){
  $decision = "deny"
  $reasons.Add("DND_DYNAMIC_EXECUTION_NOT_UNLOCKED") | Out-Null
}

foreach($rule in @($policy.rules)){
  $when = Get-Prop $rule "when"
  if(Test-RuleMatch $when $context){
    $decision = "deny"
    $matchedRules.Add([string]$rule.rule_id) | Out-Null
    foreach($r in @($rule.reason_codes)){
      if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasons.Add([string]$r) | Out-Null }
    }
  }
}

Ensure-Dir $OutRoot
$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")

$result = [ordered]@{
  schema = "covenantgate.dynamic_dnd_context.v1"
  run_id = $runId
  policy_path = $PolicyPath
  unlock_summary = $unlockSummaryPath
  context = $context
  decision = $decision
  matched_rules = @(@($matchedRules.ToArray()) | Sort-Object -Unique)
  reason_codes = @(@($reasons.ToArray()) | Sort-Object -Unique)
}

$outPath = Join-Path $OutRoot ("cg_dynamic_dnd_context_" + $runId + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_DYNAMIC_DND_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_DYNAMIC_DND_ACTION: " + $Action)
Write-Host ("CG_DYNAMIC_DND_DECISION: " + $decision)
Write-Host ("CG_DYNAMIC_DND_REASON_CODES: " + ((@($reasons.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_DYNAMIC_DND_MATCHED_RULES: " + ((@($matchedRules.ToArray()) | Sort-Object -Unique) -join ","))

if($decision -eq "deny"){
  Write-Host "CG_DYNAMIC_DND_DENY" -ForegroundColor Yellow
  exit 2
}

Write-Host "CG_DYNAMIC_DND_OK" -ForegroundColor Green
exit 0
