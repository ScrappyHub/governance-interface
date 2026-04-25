param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot   = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

$Audit = Join-Path $RepoRoot "scripts\_RUN_cg_external_repo_audit_v1.ps1"
if(-not (Test-Path -LiteralPath $Audit -PathType Leaf)){
  throw ("MISSING_AUDIT_RUNNER: " + $Audit)
}

$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
$OutRoot = Join-Path $RepoRoot "proofs\receipts\cg_re_eval_unlock"
$Bundle = Join-Path $OutRoot $RunId

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
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

Ensure-Dir $Bundle

$auditOut = Join-Path $Bundle "re_audit.stdout.txt"
$auditErr = Join-Path $Bundle "re_audit.stderr.txt"

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Audit `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  > $auditOut 2> $auditErr

$auditExit = $LASTEXITCODE
if($auditExit -ne 0){
  Get-Content -LiteralPath $auditOut -ErrorAction SilentlyContinue | Out-Host
  Get-Content -LiteralPath $auditErr -ErrorAction SilentlyContinue | Out-Host
  throw ("RE_AUDIT_FAILED: " + $auditExit)
}

$auditRoot = Join-Path $RepoRoot "proofs\receipts\cg_external_repo_audit"
$latestAudit = @(Get-ChildItem -LiteralPath $auditRoot -Directory | Sort-Object Name | Select-Object -Last 1)[0].FullName
$summaryPath = Join-Path $latestAudit "summary.json"
$summary = Read-Json $summaryPath

$missingCount = [int]$summary.missing_count
$bridgeDecision = [string]$summary.bridge_decision
$intakeDecision = [string]$summary.intake_decision

$unlockDecision = "deny_execution"
$reasonCodes = New-Object System.Collections.Generic.List[string]

if($missingCount -eq 0 -and $bridgeDecision -eq "allow"){
  $unlockDecision = "allow_execution"
  $reasonCodes.Add("REPO_GOVERNANCE_ASSETS_PRESENT") | Out-Null
  $reasonCodes.Add("EXECUTION_UNLOCKED") | Out-Null
} else {
  $reasonCodes.Add("EXECUTION_REMAINS_LOCKED") | Out-Null
  if($missingCount -gt 0){ $reasonCodes.Add("REPO_GOVERNANCE_ASSETS_MISSING") | Out-Null }
  foreach($r in @($summary.bridge_reason_codes)){
    if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasonCodes.Add([string]$r) | Out-Null }
  }
}

$result = [ordered]@{
  schema = "covenantgate.re_eval_unlock.v1"
  run_id = $RunId
  target_repo = $TargetRepo
  audit_bundle = $latestAudit
  audit_summary = $summaryPath
  missing_count = $missingCount
  intake_decision = $intakeDecision
  bridge_decision = $bridgeDecision
  unlock_decision = $unlockDecision
  execution_allowed = ($unlockDecision -eq "allow_execution")
  mutation_allowed = $false
  reason_codes = @(@($reasonCodes.ToArray()) | Sort-Object -Unique)
}

Write-Utf8NoBomLf (Join-Path $Bundle "summary.json") (($result | ConvertTo-Json -Depth 50 -Compress))

$shaPath = Join-Path $Bundle "sha256sums.txt"
$shaLines = New-Object System.Collections.Generic.List[string]
$files = @(@(Get-ChildItem -LiteralPath $Bundle -Recurse -File) | Sort-Object FullName)
foreach($f in @(@($files))){
  if($f.FullName -ieq $shaPath){ continue }
  $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
  $r = $f.FullName.Substring($Bundle.Length).TrimStart("\")
  $r = $r.Replace("\","/")
  $shaLines.Add($h + "  " + $r) | Out-Null
}
Write-Utf8NoBomLf $shaPath ((@($shaLines.ToArray()) -join "`n") + "`n")

Write-Host ("CG_RE_EVAL_UNLOCK_BUNDLE: " + $Bundle) -ForegroundColor Cyan
Write-Host ("CG_RE_EVAL_UNLOCK_TARGET: " + $TargetRepo)
Write-Host ("CG_RE_EVAL_UNLOCK_MISSING: " + $missingCount)
Write-Host ("CG_RE_EVAL_UNLOCK_INTAKE_DECISION: " + $intakeDecision)
Write-Host ("CG_RE_EVAL_UNLOCK_BRIDGE_DECISION: " + $bridgeDecision)
Write-Host ("CG_RE_EVAL_UNLOCK_DECISION: " + $unlockDecision)
Write-Host ("CG_RE_EVAL_UNLOCK_REASON_CODES: " + ((@($reasonCodes.ToArray()) | Sort-Object -Unique) -join ","))

if($unlockDecision -eq "allow_execution"){
  Write-Host "CG_EXECUTION_UNLOCKED" -ForegroundColor Green
} else {
  Write-Host "CG_EXECUTION_REMAINS_LOCKED" -ForegroundColor Yellow
}

Write-Host "CG_RE_EVAL_UNLOCK_OK" -ForegroundColor Green
