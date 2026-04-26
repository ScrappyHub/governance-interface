param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [string]$InputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path

$EvalReceipt = Join-Path $RepoRoot "scripts\cg_eval_receipt_v1.ps1"
$OutRoot = Join-Path $RepoRoot "proofs\receipts\cg_replay_verify"

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Read-Json([string]$Path){
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}

if(-not (Test-Path -LiteralPath $EvalReceipt -PathType Leaf)){ throw "MISSING_EVAL_RECEIPT_RUNNER" }

if([string]::IsNullOrWhiteSpace($InputPath)){
  $watchDir = Join-Path $RepoRoot "watch_inputs"
  $candidate = @(Get-ChildItem -LiteralPath $watchDir -Filter "*.json" -File | Sort-Object LastWriteTime,Name | Select-Object -Last 1)
  if(@($candidate).Count -lt 1){ throw "NO_INPUT_FOUND" }
  $InputPath = $candidate[0].FullName
}

$InputPath = (Resolve-Path $InputPath).Path

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
$Bundle = Join-Path $OutRoot $runId
$Pass1 = Join-Path $Bundle "pass1"
$Pass2 = Join-Path $Bundle "pass2"
Ensure-Dir $Pass1
Ensure-Dir $Pass2

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $EvalReceipt `
  -RepoRoot $RepoRoot `
  -InputPath $InputPath `
  -OutDir $Pass1 | Out-Host

if($LASTEXITCODE -ne 0){ throw "REPLAY_PASS1_FAILED" }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $EvalReceipt `
  -RepoRoot $RepoRoot `
  -InputPath $InputPath `
  -OutDir $Pass2 | Out-Host

if($LASTEXITCODE -ne 0){ throw "REPLAY_PASS2_FAILED" }

$r1 = @(Get-ChildItem -LiteralPath $Pass1 -Filter "*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName
$r2 = @(Get-ChildItem -LiteralPath $Pass2 -Filter "*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName

$j1 = Read-Json $r1
$j2 = Read-Json $r2

$ok = $true
if([string]$j1.proposal_hash -ne [string]$j2.proposal_hash){ $ok = $false }
if([string]$j1.policy_hash -ne [string]$j2.policy_hash){ $ok = $false }
if([string]$j1.overlay_hash -ne [string]$j2.overlay_hash){ $ok = $false }
if([string]$j1.decision_hash -ne [string]$j2.decision_hash){ $ok = $false }
if([string]$j1.decision -ne [string]$j2.decision){ $ok = $false }

$summary = [ordered]@{
  schema = "covenantgate.replay_verify.v1"
  run_id = $runId
  input_path = $InputPath
  pass1_receipt = $r1
  pass2_receipt = $r2
  proposal_hash = [string]$j1.proposal_hash
  policy_hash = [string]$j1.policy_hash
  overlay_hash = [string]$j1.overlay_hash
  decision = [string]$j1.decision
  decision_hash = [string]$j1.decision_hash
  replay_match = $ok
}

Write-Utf8NoBomLf (Join-Path $Bundle "summary.json") (($summary | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_REPLAY_VERIFY_BUNDLE: " + $Bundle) -ForegroundColor Cyan
Write-Host ("CG_REPLAY_PROPOSAL_HASH: " + [string]$j1.proposal_hash)
Write-Host ("CG_REPLAY_POLICY_HASH: " + [string]$j1.policy_hash)
Write-Host ("CG_REPLAY_DECISION: " + [string]$j1.decision)
Write-Host ("CG_REPLAY_DECISION_HASH: " + [string]$j1.decision_hash)

if(-not $ok){
  Write-Host "CG_REPLAY_VERIFY_MISMATCH" -ForegroundColor Red
  exit 2
}

Write-Host "CG_REPLAY_VERIFY_OK" -ForegroundColor Green
