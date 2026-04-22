param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [switch]$RunOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

$LibPath = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"
if(-not (Test-Path -LiteralPath $LibPath -PathType Leaf)){ throw ("MISSING_LIB: " + $LibPath) }
. $LibPath

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}

function Append-Ndjson([string]$Path,$Obj){
  $json = ($Obj | ConvertTo-Json -Depth 20 -Compress)
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  Add-Content -LiteralPath $Path -Value ($json + "`n") -Encoding UTF8
}

function Get-PrevHash([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return ("0" * 64) }
  $lines = @(Get-Content -LiteralPath $Path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if(@(@($lines)).Count -lt 1){ return ("0" * 64) }
  $last = ($lines[@(@($lines)).Count-1] | ConvertFrom-Json -ErrorAction Stop)
  if($null -eq $last.record_hash -or [string]::IsNullOrWhiteSpace([string]$last.record_hash)){
    return ("0" * 64)
  }
  return ([string]$last.record_hash).ToLowerInvariant()
}

function Get-RecordHash($OrderedObj){
  $canon = CG-ToCanonJson $OrderedObj
  return (CG-Sha256HexTextNormalized $canon).ToLowerInvariant()
}

$StateDir    = Join-Path $RepoRoot "scripts\state"
$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"
$StatusPath  = Join-Path $StateDir "cg_watch.status.json"
$CaseDir     = Join-Path $RepoRoot "test_vectors\cases"

Ensure-Dir $StateDir
Ensure-Dir (Split-Path -Parent $ReceiptPath)

$CaseFiles = @(@(Get-ChildItem -LiteralPath $CaseDir -Filter "*.json" -File) | Sort-Object FullName)
if(@(@($CaseFiles)).Count -lt 1){ throw ("NO_CASE_FILES: " + $CaseDir) }
$CasePath = $CaseFiles[0].FullName

while($true){
  $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
  try {
    $case = (CG-ReadUtf8NoBom $CasePath | ConvertFrom-Json -ErrorAction Stop)
    $ov = $null
    if(@(@(@(@($case.PSObject.Properties.Match("overlay_policy"))))).Count -gt 0){ $ov = $case.overlay_policy }
    $out = CG-EvalV1 $case.base_policy $ov $case.eval_input
    $reasonList = @()
    foreach($r in @(@($out.reason_codes))){ $reasonList += [string]$r }
    $prevHash = Get-PrevHash $ReceiptPath
    $core = [ordered]@{
      schema        = "covenantgate.watch.eval.v1"
      ts            = $ts
      type          = "cg.watch.eval"
      case_id       = [string]$case.case_id
      decision      = [string]$out.decision
      reason_codes  = @(@($reasonList))
      evaluation_id = [string]$out.evaluation_id
      input_hash    = [string]$out.input_hash
      policy_hash   = [string]$out.policy_hash
      prev_hash     = $prevHash
    }
    $recordHash = Get-RecordHash $core
    $record = [ordered]@{
      schema        = $core.schema
      ts            = $core.ts
      type          = $core.type
      case_id       = $core.case_id
      decision      = $core.decision
      reason_codes  = $core.reason_codes
      evaluation_id = $core.evaluation_id
      input_hash    = $core.input_hash
      policy_hash   = $core.policy_hash
      prev_hash     = $core.prev_hash
      record_hash   = $recordHash
    }
    Append-Ndjson $ReceiptPath $record
    Write-Utf8NoBomLf $StatusPath (([ordered]@{
      schema        = "covenantgate.watch.status.v1"
      last_run      = $ts
      case_id       = [string]$case.case_id
      decision      = [string]$out.decision
      reason_codes  = @(@($reasonList))
      evaluation_id = [string]$out.evaluation_id
      input_hash    = [string]$out.input_hash
      policy_hash   = [string]$out.policy_hash
      prev_hash     = $prevHash
      record_hash   = $recordHash
      status        = "OK"
    } | ConvertTo-Json -Depth 20 -Compress))
  } catch {
    $prevHash = Get-PrevHash $ReceiptPath
    $coreErr = [ordered]@{
      schema    = "covenantgate.watch.error.v1"
      ts        = $ts
      type      = "cg.watch.error"
      error     = $_.Exception.Message
      prev_hash = $prevHash
    }
    $recordHash = Get-RecordHash $coreErr
    $recordErr = [ordered]@{
      schema    = $coreErr.schema
      ts        = $coreErr.ts
      type      = $coreErr.type
      error     = $coreErr.error
      prev_hash = $coreErr.prev_hash
      record_hash = $recordHash
    }
    Append-Ndjson $ReceiptPath $recordErr
    Write-Utf8NoBomLf $StatusPath (([ordered]@{
      schema      = "covenantgate.watch.status.v1"
      last_run    = $ts
      status      = "ERROR"
      error       = $_.Exception.Message
      prev_hash   = $prevHash
      record_hash = $recordHash
    } | ConvertTo-Json -Depth 20 -Compress))
  }
  if($RunOnce){ break }
  Start-Sleep -Seconds 5
}
