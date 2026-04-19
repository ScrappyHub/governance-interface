param(
  [Parameter(Position=0)][string]$Command = "help",
  [string]$RepoRoot = ".",
  [switch]$Quiet
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
$Version = "1.0.0-cg-cli"

function Die([string]$m){ throw $m }
function Say([string]$m){ if(-not $Quiet){ Write-Host $m } }
function Script-Path([string]$Name){ Join-Path $RepoRoot ("scripts\" + $Name) }
function Ensure-Script([string]$Name){
  $p = Script-Path $Name
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("MISSING_SCRIPT: " + $p) }
  return $p
}
function Run-Script([string]$Name){
  $p = Ensure-Script $Name
  & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $p -RepoRoot $RepoRoot
  if($LASTEXITCODE -ne 0){ Die ("SCRIPT_EXIT_NONZERO: " + $Name + ":" + [string]$LASTEXITCODE) }
}
function Show-Help {
  $lines = @(
    "Covenant Gate CLI",
    "",
    "Commands:",
    "  version",
    "  doctor",
    "  quickstart",
    "  full-green",
    "  vectors",
    "  conversation-selftest",
    "  stress-negative",
    "  help"
  )
  foreach($line in @(@($lines))){ Write-Host $line }
}
function Run-Doctor {
  $required = @(
    "cg_run_test_vectors_v1.ps1",
    "_selftest_cg_conversation_layer_v1.ps1",
    "selftest_cg_stress_negative_v1.ps1",
    "_RUN_cg_full_green_v1.ps1",
    "_RUN_cg_quickstart_v1.ps1"
  )
  foreach($name in @(@($required))){
    $p = Script-Path $name
    if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("DOCTOR_MISSING_SCRIPT: " + $p) }
    Say ("FOUND: " + $p)
  }
  $psv = $PSVersionTable.PSVersion.ToString()
  Say ("POWERSHELL_VERSION: " + $psv)
  Say ("REPO_ROOT: " + $RepoRoot)
  Write-Host "CG_DOCTOR_OK" -ForegroundColor Green
}

$cmd = $Command.ToLowerInvariant()
switch($cmd){
  "version" { Write-Host $Version; break }
  "doctor"  { Run-Doctor; break }
  "quickstart" { Run-Script "_RUN_cg_quickstart_v1.ps1"; break }
  "full-green" { Run-Script "_RUN_cg_full_green_v1.ps1"; break }
  "vectors" { Run-Script "cg_run_test_vectors_v1.ps1"; break }
  "conversation-selftest" { Run-Script "_selftest_cg_conversation_layer_v1.ps1"; break }
  "stress-negative" { Run-Script "selftest_cg_stress_negative_v1.ps1"; break }
  "help" { Show-Help; break }
  default { Die ("UNKNOWN_COMMAND: " + $Command) }
}
