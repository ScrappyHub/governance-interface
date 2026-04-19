param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

function Run-Step {
  param([string]$Name,[scriptblock]$Fn)
  Write-Host ("STEP: " + $Name) -ForegroundColor Cyan
  & $Fn
}

Run-Step "CONVERSATION_LAYER" {
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File (Join-Path $RepoRoot "scripts\_selftest_cg_conversation_layer_v1.ps1") `
    -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ throw "CONVERSATION_LAYER_FAILED" }
}

Run-Step "STRESS_NEGATIVE" {
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File (Join-Path $RepoRoot "scripts\selftest_cg_stress_negative_v1.ps1") `
    -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ throw "STRESS_NEGATIVE_FAILED" }
}

Run-Step "VECTORS" {
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File (Join-Path $RepoRoot "scripts\cg_run_test_vectors_v1.ps1") `
    -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ throw "VECTORS_FAILED" }
}

Run-Step "FULL_GREEN" {
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File (Join-Path $RepoRoot "scripts\_RUN_cg_full_green_v1.ps1") `
    -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ throw "FULL_GREEN_FAILED" }
}

Write-Host "CG_QUICKSTART_OK" -ForegroundColor Green
