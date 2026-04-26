param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = "C:\dev\shutterwall"

$Context = Join-Path $RepoRoot "scripts\cg_repo_context_contract_v1.ps1"
$Gate = Join-Path $RepoRoot "scripts\cg_ai_adapter_contract_gate_v1.ps1"
$TmpDir = Join-Path $RepoRoot "proofs\_tmp\repo_context_contract_smoke"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
Ensure-Dir $TmpDir

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Context `
  -RepoRoot $RepoRoot `
  -TargetRepo $TargetRepo `
  -OutDir $TmpDir | Out-Host

if($LASTEXITCODE -ne 0){ throw ("CONTEXT_CONTRACT_FAILED: " + $LASTEXITCODE) }

$Contract = @(Get-ChildItem -LiteralPath $TmpDir -Filter "cg_repo_context_contract_*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Gate `
  -RepoRoot $RepoRoot `
  -ContextContractPath $Contract `
  -Prompt "Explain what this repo allows me to do next." `
  -Mode explain | Out-Host

if($LASTEXITCODE -ne 0){ throw ("EXPLAIN_GATE_FAILED: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Gate `
  -RepoRoot $RepoRoot `
  -ContextContractPath $Contract `
  -Prompt "Generate SQL using users.password_hash from users." `
  -AiOutputText "select users.password_hash from users;" `
  -Mode sql | Out-Host

if($LASTEXITCODE -ne 2){ throw ("SQL_SCHEMA_DENY_EXPECTED_GOT: " + $LASTEXITCODE) }

Write-Host "CG_REPO_CONTEXT_CONTRACT_SMOKE_OK" -ForegroundColor Green
