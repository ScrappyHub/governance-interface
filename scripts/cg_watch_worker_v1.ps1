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
  if($null -eq $last.record_hash -or [string]::IsNullOrWhiteSpace([string]$last.record_hash)){ return ("0" * 64) }
  return ([string]$last.record_hash).ToLowerInvariant()
}

function Get-RecordHash($OrderedObj){
  $canon = CG-ToCanonJson $OrderedObj
  return (CG-Sha256HexTextNormalized $canon).ToLowerInvariant()
}

function Get-WatchInputs {
  $watchDir = Join-Path $RepoRoot "watch_inputs"
  $caseDir  = Join-Path $RepoRoot "test_vectors\cases"
  $watchFiles = @()
  if(Test-Path -LiteralPath $watchDir -PathType Container){
    $watchFiles = @(@(Get-ChildItem -LiteralPath $watchDir -Filter "*.json" -File) | Sort-Object FullName)
  }
  if(@(@($watchFiles)).Count -gt 0){ return @(@($watchFiles)) }
  if(-not (Test-Path -LiteralPath $caseDir -PathType Container)){ throw ("NO_INPUT_DIRS: " + $watchDir + " ; " + $caseDir) }
  $caseFiles = @(@(Get-ChildItem -LiteralPath $caseDir -Filter "*.json" -File) | Sort-Object FullName)
  if(@(@($caseFiles)).Count -lt 1){ throw ("NO_CASE_FILES: " + $caseDir) }
  return @(@($caseFiles))
}

$StateDir    = Join-Path $RepoRoot "scripts\state"
$ReceiptPath = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"
$StatusPath  = Join-Path $StateDir "cg_watch.status.json"

Ensure-Dir $StateDir
Ensure-Dir (Split-Path -Parent $ReceiptPath)

while($true){
  $tsBatch = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
  try {
    $inputs = @(Get-WatchInputs)
    $processed = New-Object System.Collections.Generic.List[object]
    foreach($inputFile in @(@($inputs))){
      $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
      $case = (CG-ReadUtf8NoBom $inputFile.FullName | ConvertFrom-Json -ErrorAction Stop)
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
        source_file   = [string]$inputFile.Name
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
        source_file   = $core.source_file
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
      $processed.Add([ordered]@{
        source_file   = [string]$inputFile.Name
        case_id       = [string]$case.case_id
        decision      = [string]$out.decision
        evaluation_id = [string]$out.evaluation_id
        record_hash   = $recordHash
      }) | Out-Null
    }
    Write-Utf8NoBomLf $StatusPath (([ordered]@{
      schema        = "covenantgate.watch.status.v1"
      last_run      = $tsBatch
      input_count   = @(@($inputs)).Count
      processed     = @(@($processed.ToArray()))
      status        = "OK"
    } | ConvertTo-Json -Depth 20 -Compress))
  } catch {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
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
      schema      = $coreErr.schema
      ts          = $coreErr.ts
      type        = $coreErr.type
      error       = $coreErr.error
      prev_hash   = $coreErr.prev_hash
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
