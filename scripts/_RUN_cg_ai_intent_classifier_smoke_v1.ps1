param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Classifier = Join-Path $RepoRoot "scripts\cg_ai_intent_classifier_v1.ps1"
if(-not (Test-Path -LiteralPath $Classifier -PathType Leaf)){ throw "MISSING_CLASSIFIER" }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

$destructiveJson = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Classifier -Text "Delete the database and wipe the repo"
if($LASTEXITCODE -ne 0){ throw "CLASSIFIER_DESTRUCTIVE_EXIT_NONZERO" }
$destructive = ($destructiveJson | ConvertFrom-Json -ErrorAction Stop)
if([string]$destructive.intent -ne "destructive"){ throw "DESTRUCTIVE_INTENT_NOT_DETECTED" }
if([string]$destructive.risk_level -ne "critical"){ throw "DESTRUCTIVE_RISK_NOT_CRITICAL" }
if([bool]$destructive.requires_confirmation -ne $true){ throw "DESTRUCTIVE_CONFIRMATION_NOT_REQUIRED" }

$operationalJson = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Classifier -Text "Commit, tag, and release this engine"
if($LASTEXITCODE -ne 0){ throw "CLASSIFIER_OPERATIONAL_EXIT_NONZERO" }
$operational = ($operationalJson | ConvertFrom-Json -ErrorAction Stop)
if([string]$operational.intent -ne "operational"){ throw "OPERATIONAL_INTENT_NOT_DETECTED" }

$governanceJson = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Classifier -Text "Check overlays, schemas, reason codes, and governance policy"
if($LASTEXITCODE -ne 0){ throw "CLASSIFIER_GOVERNANCE_EXIT_NONZERO" }
$governance = ($governanceJson | ConvertFrom-Json -ErrorAction Stop)
if([string]$governance.intent -ne "governance"){ throw "GOVERNANCE_INTENT_NOT_DETECTED" }

Write-Host "CG_AI_INTENT_CLASSIFIER_SMOKE_OK" -ForegroundColor Green
