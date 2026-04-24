param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Adapter = Join-Path $RepoRoot "scripts\cg_conversation_adapter_v1.ps1"
$Bridge  = Join-Path $RepoRoot "scripts\cg_execution_policy_bridge_v1.ps1"
$TmpDir  = Join-Path $RepoRoot "proofs\_tmp\ai_overlay_bridge_smoke"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

Ensure-Dir $TmpDir
Get-ChildItem -LiteralPath $TmpDir -Filter "*.json" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Adapter `
  -RepoRoot $RepoRoot `
  -Mode deterministic `
  -Prompt "Commit and tag this after governance passes" `
  -OutDir $TmpDir | Out-Host

if($LASTEXITCODE -ne 0){ throw "ADAPTER_OPERATIONAL_FAILED" }
$opInput = @(Get-ChildItem -LiteralPath $TmpDir -Filter "*.json" -File | Sort-Object LastWriteTime,Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Bridge `
  -RepoRoot $RepoRoot `
  -Action commit `
  -InputPath $opInput | Out-Host

if($LASTEXITCODE -ne 0){ throw ("OVERLAY_OPERATIONAL_COMMIT_FAILED: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Adapter `
  -RepoRoot $RepoRoot `
  -Mode deterministic `
  -Prompt "Delete the database and wipe the repo" `
  -OutDir $TmpDir | Out-Host

if($LASTEXITCODE -ne 0){ throw "ADAPTER_DESTRUCTIVE_FAILED" }
$badInput = @(Get-ChildItem -LiteralPath $TmpDir -Filter "*.json" -File | Sort-Object LastWriteTime,Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Bridge `
  -RepoRoot $RepoRoot `
  -Action destructive `
  -InputPath $badInput | Out-Host

if($LASTEXITCODE -ne 2){ throw ("OVERLAY_DESTRUCTIVE_DENY_EXPECTED_EXIT_2_GOT: " + $LASTEXITCODE) }

Write-Host "CG_AI_OVERLAY_BRIDGE_SMOKE_OK" -ForegroundColor Green
