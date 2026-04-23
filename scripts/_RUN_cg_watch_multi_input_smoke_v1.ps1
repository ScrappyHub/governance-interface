param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

$RunnerPath = Join-Path $RepoRoot "scripts\_RUN_cg_watch_loop_v1.ps1"
$Receipt    = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"
$StatusFile = Join-Path $RepoRoot "scripts\state\cg_watch.status.json"
$WatchDir   = Join-Path $RepoRoot "watch_inputs"
$CaseDir    = Join-Path $RepoRoot "test_vectors\cases"

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

Ensure-Dir $WatchDir
if(Test-Path -LiteralPath $Receipt -PathType Leaf){ Remove-Item -LiteralPath $Receipt -Force }
if(Test-Path -LiteralPath $StatusFile -PathType Leaf){ Remove-Item -LiteralPath $StatusFile -Force }

$sourceCases = @(@(Get-ChildItem -LiteralPath $CaseDir -Filter "*.json" -File) | Sort-Object FullName)
if(@(@($sourceCases)).Count -lt 2){ throw "NEED_AT_LEAST_2_CASES_FOR_SMOKE" }

$dst1 = Join-Path $WatchDir "watch_input_001.json"
$dst2 = Join-Path $WatchDir "watch_input_002.json"
Copy-Item -LiteralPath $sourceCases[0].FullName -Destination $dst1 -Force
Copy-Item -LiteralPath $sourceCases[1].FullName -Destination $dst2 -Force

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $RunnerPath -RepoRoot $RepoRoot -Mode run-once | Out-Host
if($LASTEXITCODE -ne 0){ throw ("MULTI_INPUT_RUN_ONCE_FAILED: " + $LASTEXITCODE) }

if(-not (Test-Path -LiteralPath $Receipt -PathType Leaf)){ throw "MULTI_INPUT_RECEIPT_MISSING" }
$lines = @(Get-Content -LiteralPath $Receipt | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if(@(@($lines)).Count -lt 2){ throw ("MULTI_INPUT_RECEIPT_LINES_LT_2: " + @(@($lines)).Count) }

$r1 = ($lines[0] | ConvertFrom-Json -ErrorAction Stop)
$r2 = ($lines[1] | ConvertFrom-Json -ErrorAction Stop)
if([string]$r1.type -ne "cg.watch.eval"){ throw "MULTI_INPUT_REC1_TYPE_BAD" }
if([string]$r2.type -ne "cg.watch.eval"){ throw "MULTI_INPUT_REC2_TYPE_BAD" }
if([string]$r1.source_file -eq [string]$r2.source_file){ throw "MULTI_INPUT_SOURCE_FILE_NOT_DISTINCT" }
if(([string]$r2.prev_hash).ToLowerInvariant() -ne ([string]$r1.record_hash).ToLowerInvariant()){ throw "MULTI_INPUT_CHAIN_BAD" }

if(-not (Test-Path -LiteralPath $StatusFile -PathType Leaf)){ throw "MULTI_INPUT_STATUS_MISSING" }
$status = (Get-Content -LiteralPath $StatusFile -Raw | ConvertFrom-Json -ErrorAction Stop)
if([int]$status.input_count -lt 2){ throw "MULTI_INPUT_STATUS_COUNT_LT_2" }

Write-Host "CG_WATCH_MULTI_INPUT_SMOKE_OK" -ForegroundColor Green
