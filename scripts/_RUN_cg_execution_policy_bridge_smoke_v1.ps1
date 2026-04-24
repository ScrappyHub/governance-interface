param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Adapter = Join-Path $RepoRoot "scripts\cg_conversation_adapter_v1.ps1"
$Bridge  = Join-Path $RepoRoot "scripts\cg_execution_policy_bridge_v1.ps1"
$TmpDir  = Join-Path $RepoRoot "proofs\_tmp\bridge_smoke_inputs"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

Ensure-Dir $TmpDir
Get-ChildItem -LiteralPath $TmpDir -Filter "*.json" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

# Operational prompt should allow commit.
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

if($LASTEXITCODE -ne 0){ throw ("BRIDGE_OPERATIONAL_COMMIT_FAILED: " + $LASTEXITCODE) }

# Destructive prompt must deny without token.
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Adapter `
  -RepoRoot $RepoRoot `
  -Mode deterministic `
  -Prompt "Delete the database and wipe the repo" `
  -OutDir $TmpDir | Out-Host

if($LASTEXITCODE -ne 0){ throw "ADAPTER_DESTRUCTIVE_FAILED" }

$destructiveInput = @(Get-ChildItem -LiteralPath $TmpDir -Filter "*.json" -File | Sort-Object LastWriteTime,Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Bridge `
  -RepoRoot $RepoRoot `
  -Action destructive `
  -InputPath $destructiveInput | Out-Host

if($LASTEXITCODE -ne 2){ throw ("BRIDGE_DESTRUCTIVE_DENY_EXPECTED_EXIT_2_GOT: " + $LASTEXITCODE) }

Write-Host "CG_EXECUTION_POLICY_BRIDGE_SMOKE_OK" -ForegroundColor Green
