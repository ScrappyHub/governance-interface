param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Adapter = Join-Path $RepoRoot "scripts\cg_conversation_adapter_v1.ps1"
$Runner  = Join-Path $RepoRoot "scripts\_RUN_cg_watch_loop_v1.ps1"
$Tmp     = Join-Path $RepoRoot "proofs\_tmp\external_ai_response.txt"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
Ensure-Dir (Split-Path -Parent $Tmp)
[System.IO.File]::WriteAllText($Tmp,"I recommend committing only after governance passes.",(New-Object System.Text.UTF8Encoding($false)))

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Adapter -RepoRoot $RepoRoot -Mode deterministic -Prompt "Can I commit this repo after the checks pass?" | Out-Host
if($LASTEXITCODE -ne 0){ throw "DETERMINISTIC_ADAPTER_FAILED" }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Adapter -RepoRoot $RepoRoot -Mode external-file -Prompt "Review this model response" -ExternalResponsePath $Tmp | Out-Host
if($LASTEXITCODE -ne 0){ throw "EXTERNAL_FILE_ADAPTER_FAILED" }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Runner -RepoRoot $RepoRoot -Mode run-once | Out-Host
if($LASTEXITCODE -ne 0){ throw "WATCH_RUN_ONCE_FAILED" }

Write-Host "CG_CONVERSATION_ADAPTER_SMOKE_OK" -ForegroundColor Green
