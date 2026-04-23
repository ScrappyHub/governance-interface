param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Gate = Join-Path $RepoRoot "scripts\cg_execution_gate_v1.ps1"
$Input = Join-Path $RepoRoot "watch_inputs\repo_intake_covenant-gate.json"

if(-not (Test-Path -LiteralPath $Gate -PathType Leaf)){ throw "MISSING_GATE" }
if(-not (Test-Path -LiteralPath $Input -PathType Leaf)){ throw "MISSING_INPUT_RUN_INTAKE_FIRST" }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Gate -RepoRoot $RepoRoot -Action commit -InputPath $Input | Out-Host
if($LASTEXITCODE -ne 0){ throw ("COMMIT_GATE_FAILED: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Gate -RepoRoot $RepoRoot -Action destructive -InputPath $Input | Out-Host
if($LASTEXITCODE -ne 2){ throw ("DESTRUCTIVE_DENY_EXPECTED_EXIT_2_GOT: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Gate -RepoRoot $RepoRoot -Action destructive -InputPath $Input -ConfirmToken I_UNDERSTAND_DESTRUCTIVE_ACTION | Out-Host
if($LASTEXITCODE -ne 0){ throw ("DESTRUCTIVE_CONFIRMED_FAILED: " + $LASTEXITCODE) }

Write-Host "CG_EXECUTION_GATE_SMOKE_OK" -ForegroundColor Green
