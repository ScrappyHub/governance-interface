param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

$LibPath    = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"
$RunnerPath = Join-Path $RepoRoot "scripts\_RUN_cg_watch_loop_v1.ps1"
$Receipt    = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"
$StatusFile = Join-Path $RepoRoot "scripts\state\cg_watch.status.json"
$BundleRoot = Join-Path $RepoRoot "proofs\receipts\cg_watch_full_green"

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

function Get-RecordHash($OrderedObj){
  $canon = CG-ToCanonJson $OrderedObj
  return (CG-Sha256HexTextNormalized $canon).ToLowerInvariant()
}

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmssZ")
$Bundle = Join-Path $BundleRoot $runId
Ensure-Dir $Bundle

if(Test-Path -LiteralPath $Receipt -PathType Leaf){ Remove-Item -LiteralPath $Receipt -Force }
if(Test-Path -LiteralPath $StatusFile -PathType Leaf){ Remove-Item -LiteralPath $StatusFile -Force }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $RunnerPath -RepoRoot $RepoRoot -Mode run-once | Out-Host
if($LASTEXITCODE -ne 0){ throw ("RUN1_FAILED: " + $LASTEXITCODE) }
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $RunnerPath -RepoRoot $RepoRoot -Mode run-once | Out-Host
if($LASTEXITCODE -ne 0){ throw ("RUN2_FAILED: " + $LASTEXITCODE) }

if(-not (Test-Path -LiteralPath $Receipt -PathType Leaf)){ throw ("MISSING_RECEIPT: " + $Receipt) }
$lines = @(Get-Content -LiteralPath $Receipt | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if(@(@($lines)).Count -lt 2){ throw ("RECEIPT_LINE_COUNT_LT_2: " + @(@($lines)).Count) }

$r1 = ($lines[0] | ConvertFrom-Json -ErrorAction Stop)
$r2 = ($lines[1] | ConvertFrom-Json -ErrorAction Stop)

if([string]$r1.schema -ne "covenantgate.watch.eval.v1"){ throw "REC1_SCHEMA_BAD" }
if([string]$r2.schema -ne "covenantgate.watch.eval.v1"){ throw "REC2_SCHEMA_BAD" }
if([string]$r1.type -ne "cg.watch.eval"){ throw "REC1_TYPE_BAD" }
if([string]$r2.type -ne "cg.watch.eval"){ throw "REC2_TYPE_BAD" }
if(([string]$r1.prev_hash).ToLowerInvariant() -ne ("0" * 64)){ throw "REC1_PREV_HASH_BAD" }
if(([string]$r2.prev_hash).ToLowerInvariant() -ne ([string]$r1.record_hash).ToLowerInvariant()){ throw "REC2_PREV_HASH_BAD" }

$core1 = [ordered]@{
  schema        = [string]$r1.schema
  ts            = [string]$r1.ts
  type          = [string]$r1.type
  case_id       = [string]$r1.case_id
  decision      = [string]$r1.decision
  reason_codes  = @(@($r1.reason_codes))
  evaluation_id = [string]$r1.evaluation_id
  input_hash    = [string]$r1.input_hash
  policy_hash   = [string]$r1.policy_hash
  prev_hash     = [string]$r1.prev_hash
}
$core2 = [ordered]@{
  schema        = [string]$r2.schema
  ts            = [string]$r2.ts
  type          = [string]$r2.type
  case_id       = [string]$r2.case_id
  decision      = [string]$r2.decision
  reason_codes  = @(@($r2.reason_codes))
  evaluation_id = [string]$r2.evaluation_id
  input_hash    = [string]$r2.input_hash
  policy_hash   = [string]$r2.policy_hash
  prev_hash     = [string]$r2.prev_hash
}
if((Get-RecordHash $core1) -ne ([string]$r1.record_hash).ToLowerInvariant()){ throw "REC1_RECORD_HASH_BAD" }
if((Get-RecordHash $core2) -ne ([string]$r2.record_hash).ToLowerInvariant()){ throw "REC2_RECORD_HASH_BAD" }

Copy-Item -LiteralPath $Receipt -Destination (Join-Path $Bundle "cg_watch.ndjson") -Force
if(Test-Path -LiteralPath $StatusFile -PathType Leaf){
  Copy-Item -LiteralPath $StatusFile -Destination (Join-Path $Bundle "cg_watch.status.json") -Force
}

$summary = [ordered]@{
  schema = "covenantgate.watch.full_green.v1"
  run_id = $runId
  receipt_lines = @(@($lines)).Count
  first_record_hash = [string]$r1.record_hash
  second_record_hash = [string]$r2.record_hash
  status = "OK"
}
Write-Utf8NoBomLf (Join-Path $Bundle "summary.json") (($summary | ConvertTo-Json -Depth 20 -Compress))

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

Write-Host ("CG_WATCH_FULL_GREEN_BUNDLE: " + $Bundle) -ForegroundColor Cyan
Write-Host "CG_WATCH_FULL_GREEN_OK" -ForegroundColor Green
