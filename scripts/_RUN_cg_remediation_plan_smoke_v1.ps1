param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$AuditRoot = Join-Path $RepoRoot "proofs\receipts\cg_external_repo_audit"
$Remediate = Join-Path $RepoRoot "scripts\cg_remediation_plan_v1.ps1"

if(-not (Test-Path -LiteralPath $Remediate -PathType Leaf)){ throw "MISSING_REMEDIATION_SCRIPT" }
if(-not (Test-Path -LiteralPath $AuditRoot -PathType Container)){ throw "MISSING_EXTERNAL_AUDIT_ROOT" }

$Latest = @(Get-ChildItem -LiteralPath $AuditRoot -Directory | Sort-Object Name | Select-Object -Last 1)[0].FullName

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Remediate `
  -RepoRoot $RepoRoot `
  -AuditBundle $Latest | Out-Host

if($LASTEXITCODE -ne 0){ throw ("REMEDIATION_PLAN_FAILED: " + $LASTEXITCODE) }

Write-Host "CG_REMEDIATION_PLAN_SMOKE_OK" -ForegroundColor Green
