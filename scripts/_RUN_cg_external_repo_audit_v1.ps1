param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot   = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

$Intake  = Join-Path $RepoRoot "scripts\cg_intake_repo_v1.ps1"
$Watch   = Join-Path $RepoRoot "scripts\_RUN_cg_watch_loop_v1.ps1"
$Bridge  = Join-Path $RepoRoot "scripts\cg_execution_policy_bridge_v1.ps1"

$RunId   = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
$OutRoot = Join-Path $RepoRoot "proofs\receipts\cg_external_repo_audit"
$Bundle  = Join-Path $OutRoot $RunId
$InputDir = Join-Path $Bundle "watch_inputs"

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

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ throw ("MISSING_FILE: " + $Path) }
  return [System.IO.File]::ReadAllText($Path,(New-Object System.Text.UTF8Encoding($false)))
}

function Sha256File([string]$Path){
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

foreach($p in @($Intake,$Watch,$Bridge)){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ throw ("MISSING_REQUIRED_SCRIPT: " + $p) }
}

Ensure-Dir $Bundle
Ensure-Dir $InputDir

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

$intakeOut = Join-Path $Bundle "intake.stdout.txt"
$intakeErr = Join-Path $Bundle "intake.stderr.txt"
$watchOut  = Join-Path $Bundle "watch.stdout.txt"
$watchErr  = Join-Path $Bundle "watch.stderr.txt"
$bridgeOut = Join-Path $Bundle "bridge.stdout.txt"
$bridgeErr = Join-Path $Bundle "bridge.stderr.txt"

$p1 = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$Intake,
    "-RepoRoot",$RepoRoot,
    "-TargetRepo",$TargetRepo,
    "-OutDir",$InputDir
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $intakeOut `
  -RedirectStandardError $intakeErr

$p1.WaitForExit()
if($p1.ExitCode -ne 0){ throw ("INTAKE_FAILED: " + $p1.ExitCode) }

$inputs = @(@(Get-ChildItem -LiteralPath $InputDir -Filter "*.json" -File) | Sort-Object FullName)
if(@(@($inputs)).Count -lt 1){ throw "NO_INTAKE_WATCH_INPUTS" }

$p2 = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$Watch,
    "-RepoRoot",$RepoRoot,
    "-Mode","run-once"
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $watchOut `
  -RedirectStandardError $watchErr

$p2.WaitForExit()
if($p2.ExitCode -ne 0){ throw ("WATCH_RUN_ONCE_FAILED: " + $p2.ExitCode) }

$latestInput = $inputs[@(@($inputs)).Count-1].FullName

$p3 = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$Bridge,
    "-RepoRoot",$RepoRoot,
    "-Action","export",
    "-InputPath",$latestInput,
    "-OutDir",$Bundle
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $bridgeOut `
  -RedirectStandardError $bridgeErr

$p3.WaitForExit()
if(($p3.ExitCode -ne 0) -and ($p3.ExitCode -ne 2)){
  throw ("BRIDGE_UNEXPECTED_EXIT: " + $p3.ExitCode)
}

$inputObj = Read-Text $latestInput | ConvertFrom-Json -ErrorAction Stop
$assetCount = @(@($inputObj.eval_input.assets)).Count
$missingCount = @(@($inputObj.eval_input.missing)).Count

$bridgeText = Read-Text $bridgeOut
$bridgeDecision = "unknown"
if($bridgeText -match "CG_EXECUTION_BRIDGE_DECISION:\s*allow"){ $bridgeDecision = "allow" }
if($bridgeText -match "CG_EXECUTION_BRIDGE_DECISION:\s*deny"){ $bridgeDecision = "deny" }

$summary = [ordered]@{
  schema = "covenantgate.external_repo_audit.v1"
  run_id = $RunId
  target_repo = $TargetRepo
  target_name = (Split-Path -Leaf $TargetRepo)
  intake_input = $latestInput
  intake_input_sha256 = Sha256File $latestInput
  asset_count = $assetCount
  missing_count = $missingCount
  bridge_decision = $bridgeDecision
  intake_exit_code = $p1.ExitCode
  watch_exit_code = $p2.ExitCode
  bridge_exit_code = $p3.ExitCode
  status = "OK"
}

Write-Utf8NoBomLf (Join-Path $Bundle "summary.json") (($summary | ConvertTo-Json -Depth 50 -Compress))

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

Write-Host ("CG_EXTERNAL_REPO_AUDIT_BUNDLE: " + $Bundle) -ForegroundColor Cyan
Write-Host ("CG_EXTERNAL_REPO_AUDIT_TARGET: " + $TargetRepo)
Write-Host ("CG_EXTERNAL_REPO_AUDIT_ASSETS: " + $assetCount)
Write-Host ("CG_EXTERNAL_REPO_AUDIT_MISSING: " + $missingCount)
Write-Host ("CG_EXTERNAL_REPO_AUDIT_BRIDGE_DECISION: " + $bridgeDecision)
Write-Host "CG_EXTERNAL_REPO_AUDIT_OK" -ForegroundColor Green
