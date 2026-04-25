param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Engine = Join-Path $RepoRoot "scripts\cg_dynamic_dnd_context_v1.ps1"
$TargetRepo = "C:\dev\shutterwall"
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Engine `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  -Action export `
  -Intent governance `
  -RiskLevel low `
  -Confidence high | Out-Host

if($LASTEXITCODE -ne 0){ throw ("DYNAMIC_DND_EXPORT_EXPECTED_ALLOW_GOT: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Engine `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  -Action destructive `
  -Intent destructive `
  -RiskLevel critical `
  -Confidence high | Out-Host

if($LASTEXITCODE -ne 2){ throw ("DYNAMIC_DND_DESTRUCTIVE_EXPECTED_DENY_GOT: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Engine `
  -RepoRoot $TargetRepo `
  -TargetRepo $TargetRepo `
  -Action commit-plan `
  -Intent operational `
  -RiskLevel medium `
  -Confidence low `
  -ExternalAi | Out-Host

if($LASTEXITCODE -ne 2){ throw ("DYNAMIC_DND_EXTERNAL_AI_EXPECTED_DENY_GOT: " + $LASTEXITCODE) }

Write-Host "CG_DYNAMIC_DND_CONTEXT_SMOKE_OK" -ForegroundColor Green
