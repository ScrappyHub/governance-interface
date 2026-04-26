param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [ValidateSet("plan","explain","sql","action")][string]$Mode = "plan",
  [ValidateSet("stub","openai")][string]$Adapter = "stub"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

$Context = Join-Path $RepoRoot "scripts\cg_repo_context_contract_v1.ps1"
$Ai = Join-Path $RepoRoot "scripts\cg_ai_adapter_openai_v1.ps1"
$Gate = Join-Path $RepoRoot "scripts\cg_ai_adapter_contract_gate_v1.ps1"
$Trace = Join-Path $RepoRoot "scripts\cg_execution_trace_v1.ps1"

$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
$Bundle = Join-Path (Join-Path $RepoRoot "proofs\receipts\cg_run_repo_session") $RunId

function Ensure-Dir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Read-Json([string]$Path){ return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop) }

Ensure-Dir $Bundle
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Context -RepoRoot $RepoRoot -TargetRepo $TargetRepo -OutDir $Bundle | Out-Host
if($LASTEXITCODE -ne 0){ throw "RUN_CONTEXT_FAILED" }
$ContextPath = @(Get-ChildItem -LiteralPath $Bundle -Filter "cg_repo_context_contract_*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Ai -RepoRoot $RepoRoot -ContextContractPath $ContextPath -Prompt $Prompt -Adapter $Adapter -OutDir $Bundle | Out-Host
if($LASTEXITCODE -ne 0){ throw "RUN_AI_ADAPTER_FAILED" }
$AiPath = @(Get-ChildItem -LiteralPath $Bundle -Filter "cg_ai_adapter_openai_*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName
$AiObj = Read-Json $AiPath
$AiText = [string]$AiObj.response_text

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Gate -RepoRoot $RepoRoot -ContextContractPath $ContextPath -Prompt $Prompt -AiOutputText $AiText -Mode $Mode -OutDir $Bundle | Out-Host
$gateExit = $LASTEXITCODE
if(($gateExit -ne 0) -and ($gateExit -ne 2)){ throw ("RUN_GATE_UNEXPECTED_EXIT: " + $gateExit) }

$GatePath = @(Get-ChildItem -LiteralPath $Bundle -Filter "cg_ai_adapter_contract_gate_*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName
$GateObj = Read-Json $GatePath

$reasonCsv = (@($GateObj.reason_codes) -join ",")
$eventCsv  = (@($GateObj.events) -join "|")

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Trace `
  -RepoRoot $RepoRoot `
  -ContextContractPath $ContextPath `
  -Prompt $Prompt `
  -AiOutputText $AiText `
  -Decision ([string]$GateObj.decision) `
  -ReasonCodesCsv $reasonCsv `
  -EventsCsv $eventCsv `
  -OutDir $Bundle | Out-Host
if($LASTEXITCODE -ne 0){ throw "RUN_TRACE_FAILED" }

Write-Host ("CG_RUN_REPO_SESSION_BUNDLE: " + $Bundle) -ForegroundColor Cyan
Write-Host ("CG_RUN_REPO_SESSION_DECISION: " + [string]$GateObj.decision)
Write-Host ("CG_RUN_REPO_SESSION_REASON_CODES: " + ((@($GateObj.reason_codes)) -join ","))
if([string]$GateObj.decision -eq "deny"){
  Write-Host "CG_RUN_REPO_SESSION_DENY" -ForegroundColor Yellow
  exit 2
}
Write-Host "CG_RUN_REPO_SESSION_OK" -ForegroundColor Green
exit 0
