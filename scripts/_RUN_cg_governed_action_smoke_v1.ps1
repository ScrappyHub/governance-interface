param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Action = Join-Path $RepoRoot "scripts\cg_governed_action_v1.ps1"
$TargetRepo = "C:\dev\shutterwall"

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Action `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  -Action export | Out-Host

if($LASTEXITCODE -ne 0){ throw ("EXPORT_ACTION_FAILED: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Action `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  -Action destructive | Out-Host

if($LASTEXITCODE -ne 2){ throw ("DND_DESTRUCTIVE_EXPECTED_DENY_GOT: " + $LASTEXITCODE) }

Write-Host "CG_GOVERNED_ACTION_SMOKE_OK" -ForegroundColor Green
