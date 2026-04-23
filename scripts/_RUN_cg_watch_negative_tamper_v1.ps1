param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

$LibPath      = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"
$FullGreen    = Join-Path $RepoRoot "scripts\_RUN_cg_watch_full_green_v1.ps1"
$BundleRoot   = Join-Path $RepoRoot "proofs\receipts\cg_watch_full_green"
$NegRoot      = Join-Path $RepoRoot "proofs\receipts\cg_watch_negative_tamper"

if(-not (Test-Path -LiteralPath $LibPath -PathType Leaf)){ throw ("MISSING_LIB: " + $LibPath) }
if(-not (Test-Path -LiteralPath $FullGreen -PathType Leaf)){ throw ("MISSING_FULLGREEN: " + $FullGreen) }
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

function Get-RecordHash($OrderedObj){
  $canon = CG-ToCanonJson $OrderedObj
  return (CG-Sha256HexTextNormalized $canon).ToLowerInvariant()
}

function Verify-WatchChain([string]$NdjsonPath){
  if(-not (Test-Path -LiteralPath $NdjsonPath -PathType Leaf)){ throw ("MISSING_CHAIN: " + $NdjsonPath) }
  $lines = @(Get-Content -LiteralPath $NdjsonPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if(@(@($lines)).Count -lt 2){ throw "CHAIN_LINE_COUNT_LT_2" }
  $prevExpected = ("0" * 64)
  for($i = 0; $i -lt @(@($lines)).Count; $i++){
    $r = ($lines[$i] | ConvertFrom-Json -ErrorAction Stop)
    if([string]$r.schema -eq "covenantgate.watch.eval.v1"){
      $core = [ordered]@{
        schema        = [string]$r.schema
        ts            = [string]$r.ts
        type          = [string]$r.type
        case_id       = [string]$r.case_id
        decision      = [string]$r.decision
        reason_codes  = @(@($r.reason_codes))
        evaluation_id = [string]$r.evaluation_id
        input_hash    = [string]$r.input_hash
        policy_hash   = [string]$r.policy_hash
        prev_hash     = [string]$r.prev_hash
      }
    } elseif([string]$r.schema -eq "covenantgate.watch.error.v1"){
      $core = [ordered]@{
        schema    = [string]$r.schema
        ts        = [string]$r.ts
        type      = [string]$r.type
        error     = [string]$r.error
        prev_hash = [string]$r.prev_hash
      }
    } else {
      throw ("UNKNOWN_SCHEMA_AT_INDEX_" + $i)
    }
    if(([string]$r.prev_hash).ToLowerInvariant() -ne $prevExpected.ToLowerInvariant()){
      throw ("PREV_HASH_MISMATCH_AT_INDEX_" + $i)
    }
    $recomputed = Get-RecordHash $core
    if($recomputed -ne ([string]$r.record_hash).ToLowerInvariant()){
      throw ("RECORD_HASH_MISMATCH_AT_INDEX_" + $i)
    }
    $prevExpected = ([string]$r.record_hash).ToLowerInvariant()
  }
  return $true
}

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $FullGreen -RepoRoot $RepoRoot | Out-Host
if($LASTEXITCODE -ne 0){ throw ("WATCH_FULL_GREEN_FAILED: " + $LASTEXITCODE) }

$Bundles = @(@(Get-ChildItem -LiteralPath $BundleRoot -Directory) | Sort-Object Name)
if(@(@($Bundles)).Count -lt 1){ throw "NO_WATCH_FULL_GREEN_BUNDLES_FOUND" }
$LatestBundle = $Bundles[@(@($Bundles)).Count-1].FullName
$SourceNdjson = Join-Path $LatestBundle "cg_watch.ndjson"
if(-not (Test-Path -LiteralPath $SourceNdjson -PathType Leaf)){ throw ("MISSING_SOURCE_NDJSON: " + $SourceNdjson) }

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmssZ")
$TamperDir = Join-Path $NegRoot $runId
Ensure-Dir $TamperDir
$TamperedNdjson = Join-Path $TamperDir "cg_watch_tampered.ndjson"

$lines = @(Get-Content -LiteralPath $SourceNdjson | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if(@(@($lines)).Count -lt 2){ throw "SOURCE_CHAIN_LT_2" }

$r1 = ($lines[0] | ConvertFrom-Json -ErrorAction Stop)
$r2 = ($lines[1] | ConvertFrom-Json -ErrorAction Stop)

# tamper second record without recomputing record_hash
if([string]$r2.decision -eq "deny"){
  $r2.decision = "allow"
} else {
  $r2.decision = "deny"
}

$newLines = New-Object System.Collections.Generic.List[string]
$newLines.Add(($r1 | ConvertTo-Json -Depth 20 -Compress)) | Out-Null
$newLines.Add(($r2 | ConvertTo-Json -Depth 20 -Compress)) | Out-Null
for($i = 2; $i -lt @(@($lines)).Count; $i++){
  $newLines.Add($lines[$i]) | Out-Null
}
Write-Utf8NoBomLf $TamperedNdjson ((@($newLines.ToArray()) -join "`n") + "`n")

$detected = $false
$failure  = ""
try {
  [void](Verify-WatchChain $TamperedNdjson)
} catch {
  $detected = $true
  $failure = $_.Exception.Message
}

if(-not $detected){ throw "NEGATIVE_TAMPER_NOT_DETECTED" }
if($failure -notmatch "RECORD_HASH_MISMATCH"){ throw ("UNEXPECTED_TAMPER_FAILURE: " + $failure) }

$summary = [ordered]@{
  schema = "covenantgate.watch.negative_tamper.v1"
  run_id = $runId
  source_bundle = $LatestBundle
  tampered_chain = $TamperedNdjson
  failure = $failure
  status = "TAMPER_DETECTED"
}
Write-Utf8NoBomLf (Join-Path $TamperDir "summary.json") (($summary | ConvertTo-Json -Depth 20 -Compress))

$shaPath = Join-Path $TamperDir "sha256sums.txt"
$shaLines = New-Object System.Collections.Generic.List[string]
$files = @(@(Get-ChildItem -LiteralPath $TamperDir -Recurse -File) | Sort-Object FullName)
foreach($f in @(@($files))){
  if($f.FullName -ieq $shaPath){ continue }
  $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
  $r = $f.FullName.Substring($TamperDir.Length).TrimStart("\")
  $r = $r.Replace("\","/")
  $shaLines.Add($h + "  " + $r) | Out-Null
}
Write-Utf8NoBomLf $shaPath ((@($shaLines.ToArray()) -join "`n") + "`n")

Write-Host ("CG_WATCH_NEGATIVE_TAMPER_BUNDLE: " + $TamperDir) -ForegroundColor Cyan
Write-Host "CG_WATCH_CHAIN_TAMPER_DETECTED" -ForegroundColor Green
