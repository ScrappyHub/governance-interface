param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
$Intake = Join-Path $RepoRoot "scripts\cg_intake_repo_v1.ps1"
$WatchDir = Join-Path $RepoRoot "watch_inputs"
$Runner = Join-Path $RepoRoot "scripts\_RUN_cg_watch_loop_v1.ps1"
if(-not (Test-Path -LiteralPath $Intake -PathType Leaf)){ throw "MISSING_INTAKE" }
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Intake -RepoRoot $RepoRoot -TargetRepo $RepoRoot -OutDir $WatchDir | Out-Host
if($LASTEXITCODE -ne 0){ throw ("INTAKE_EXIT_NONZERO: " + $LASTEXITCODE) }
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -RepoRoot $RepoRoot -Mode run-once | Out-Host
if($LASTEXITCODE -ne 0){ throw ("WATCH_RUN_ONCE_EXIT_NONZERO: " + $LASTEXITCODE) }
Write-Host "CG_INTAKE_REPO_SMOKE_OK" -ForegroundColor Green
