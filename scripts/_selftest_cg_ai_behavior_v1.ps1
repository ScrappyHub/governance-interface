param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$Cg = Join-Path $RepoRoot "cg.ps1"
$Vectors = Join-Path $RepoRoot "test_vectors\ai_behavior_v1"
$TargetRepo = "C:\dev\shutterwall"
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

foreach($v in @(Get-ChildItem -LiteralPath $Vectors -Filter "*.json" -File | Sort-Object Name)){
  $case = Get-Content -LiteralPath $v.FullName -Raw | ConvertFrom-Json -ErrorAction Stop
  $out = & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Cg -Command run -Repo $TargetRepo -Prompt ([string]$case.prompt) -Mode ([string]$case.mode) -Adapter stub 2>&1
  $exit = $LASTEXITCODE
  $text = ($out | Out-String)
  $text | Out-Host

  if($exit -ne [int]$case.expected_exit){
    throw ("AI_BEHAVIOR_EXIT_MISMATCH: " + $case.case_id + " expected=" + $case.expected_exit + " got=" + $exit)
  }
  if($text -notmatch [regex]::Escape([string]$case.expected_token)){
    throw ("AI_BEHAVIOR_TOKEN_MISSING: " + $case.case_id)
  }
  Write-Host ("AI_BEHAVIOR_VECTOR_OK: " + $case.case_id) -ForegroundColor Green
}

Write-Host "CG_AI_BEHAVIOR_SELFTEST_OK" -ForegroundColor Green
