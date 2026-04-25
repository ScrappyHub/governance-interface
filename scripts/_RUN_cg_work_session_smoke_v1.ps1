param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Session = Join-Path $RepoRoot "scripts\cg_work_session_v1.ps1"
$TargetRepo = "C:\dev\shutterwall"

if(-not (Test-Path -LiteralPath $Session -PathType Leaf)){ throw "MISSING_WORK_SESSION" }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Session `
  -RepoRoot $RepoRoot `
  -Mode blank `
  -Prompt "Start a new governed workspace with no repo yet" | Out-Host

if($LASTEXITCODE -ne 0){ throw ("BLANK_SESSION_FAILED: " + $LASTEXITCODE) }

if(Test-Path -LiteralPath $TargetRepo -PathType Container){
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $Session `
    -RepoRoot $RepoRoot `
    -Mode repo `
    -TargetRepo $TargetRepo `
    -Prompt "Audit and continue working ShutterWall without mutating it" | Out-Host

  if($LASTEXITCODE -ne 0){ throw ("REPO_SESSION_FAILED: " + $LASTEXITCODE) }
}

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Session `
  -RepoRoot $RepoRoot `
  -Mode uploaded-files `
  -Prompt "Work with uploaded governance files but no repo" | Out-Host

if($LASTEXITCODE -ne 0){ throw ("UPLOADED_FILES_SESSION_FAILED: " + $LASTEXITCODE) }

Write-Host "CG_WORK_SESSION_SMOKE_OK" -ForegroundColor Green
