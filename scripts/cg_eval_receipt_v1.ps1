param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$InputPath = (Resolve-Path $InputPath).Path

if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_eval_receipt"
}

$Canon = Join-Path $RepoRoot "scripts\_lib_cg_canon_hash_v1.ps1"
$EvalLib = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"

if(-not (Test-Path -LiteralPath $Canon -PathType Leaf)){ throw "MISSING_CANON_LIB" }
if(-not (Test-Path -LiteralPath $EvalLib -PathType Leaf)){ throw "MISSING_EVAL_LIB" }

. $Canon
. $EvalLib

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

Ensure-Dir $OutDir

$case = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -ErrorAction Stop

$overlay = $null
if(@($case.PSObject.Properties.Match("overlay_policy")).Count -gt 0){
  $overlay = $case.overlay_policy
}

$result = CG-EvalV1 $case.base_policy $overlay $case.eval_input

$proposalHash = CG-HashObjectV1 $case.eval_input
$policyHash = CG-HashObjectV1 $case.base_policy
$overlayHash = ""
if($null -ne $overlay){ $overlayHash = CG-HashObjectV1 $overlay }

$decisionCore = [ordered]@{
  proposal_hash = $proposalHash
  policy_hash = $policyHash
  overlay_hash = $overlayHash
  decision = [string]$result.decision
  reason_codes = @(@($result.reason_codes) | Sort-Object)
  input_hash = [string]$result.input_hash
  evaluation_id = [string]$result.evaluation_id
}

$decisionHash = CG-HashObjectV1 $decisionCore

$receiptCore = [ordered]@{
  schema = "covenantgate.eval_receipt.v1"
  input_path = $InputPath
  proposal_hash = $proposalHash
  policy_hash = $policyHash
  overlay_hash = $overlayHash
  decision = [string]$result.decision
  reason_codes = @(@($result.reason_codes) | Sort-Object)
  evaluation_id = [string]$result.evaluation_id
  input_hash = [string]$result.input_hash
  decision_hash = $decisionHash
}

$receiptHash = CG-HashObjectV1 $receiptCore

$receipt = [ordered]@{
  schema = $receiptCore.schema
  input_path = $receiptCore.input_path
  proposal_hash = $receiptCore.proposal_hash
  policy_hash = $receiptCore.policy_hash
  overlay_hash = $receiptCore.overlay_hash
  decision = $receiptCore.decision
  reason_codes = $receiptCore.reason_codes
  evaluation_id = $receiptCore.evaluation_id
  input_hash = $receiptCore.input_hash
  decision_hash = $receiptCore.decision_hash
  receipt_hash = $receiptHash
}

$outPath = Join-Path $OutDir ("cg_eval_receipt_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($receipt | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_EVAL_RECEIPT_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_EVAL_PROPOSAL_HASH: " + $proposalHash)
Write-Host ("CG_EVAL_POLICY_HASH: " + $policyHash)
Write-Host ("CG_EVAL_DECISION: " + [string]$result.decision)
Write-Host ("CG_EVAL_DECISION_HASH: " + $decisionHash)
Write-Host ("CG_EVAL_RECEIPT_HASH: " + $receiptHash)
Write-Host "CG_EVAL_RECEIPT_OK" -ForegroundColor Green
