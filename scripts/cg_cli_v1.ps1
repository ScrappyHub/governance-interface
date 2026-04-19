param(
  [Parameter(Position=0)][string]$Command = "help",
  [string]$RepoRoot = ".",
  [switch]$Quiet
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
$Version = "1.0.2-cg-cli-control"
$RuntimeDir  = Join-Path $RepoRoot "runtime\watch"
$PidPath     = Join-Path $RuntimeDir "cg_watch.pid"
$StopPath    = Join-Path $RuntimeDir "cg_watch.stop"
$StatusPath  = Join-Path $RuntimeDir "cg_watch.status.json"
$StatePath   = Join-Path $RuntimeDir "cg_state.json"

function Die([string]$m){ throw $m }
function Say([string]$m){ if(-not $Quiet){ Write-Host $m } }
function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("MISSING_FILE: " + $Path) }
  [System.IO.File]::ReadAllText($Path,(New-Object System.Text.UTF8Encoding($false)))
}
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
function Write-State([string]$Status,[string]$RunId,[string]$Bundle){
  Ensure-Dir $RuntimeDir
  $obj = [ordered]@{
    schema = "covenantgate.cli.state.v1"
    updated_utc = [DateTime]::UtcNow.ToString("o")
    last_status = $Status
    last_run_id = $RunId
    last_bundle = $Bundle
  }
  Write-Utf8NoBomLf $StatePath (($obj | ConvertTo-Json -Depth 10 -Compress))
}
function Get-LatestFullGreenDir {
  $root = Join-Path $RepoRoot "proofs\receipts\cg_full_green"
  if(-not (Test-Path -LiteralPath $root -PathType Container)){ return $null }
  $dirs = @(@(Get-ChildItem -LiteralPath $root -Directory) | Sort-Object Name)
  if(@(@($dirs)).Count -lt 1){ return $null }
  return $dirs[@(@($dirs)).Count-1].FullName
}
function Run-QuickCheck {
  Run-Script "_RUN_cg_quickstart_v1.ps1"
}
function Run-FullGreen {
  Run-Script "_RUN_cg_full_green_v1.ps1"
  $bundle = Get-LatestFullGreenDir
  $runId = ""
  if($bundle){ $runId = Split-Path -Leaf $bundle }
  Write-State "OK" $runId $bundle
}
function Show-Last {
  if(-not (Test-Path -LiteralPath $StatePath -PathType Leaf)){ Die ("STATE_MISSING: " + $StatePath) }
  $obj = Read-Text $StatePath | ConvertFrom-Json -ErrorAction Stop
  Write-Host ("CG_LAST_RUN: " + [string]$obj.last_run_id)
  Write-Host ("CG_LAST_STATUS: " + [string]$obj.last_status)
  Write-Host ("CG_LAST_BUNDLE: " + [string]$obj.last_bundle)
}
function Run-Doctor {
  Ensure-Dir $RuntimeDir
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
  Say ("POWERSHELL_VERSION: " + $PSVersionTable.PSVersion.ToString())
  Say ("REPO_ROOT: " + $RepoRoot)
  Write-Host "CG_DOCTOR_OK" -ForegroundColor Green
}
function Start-Watch {
  Ensure-Dir $RuntimeDir
  if(Test-Path -LiteralPath $StopPath -PathType Leaf){ Remove-Item -LiteralPath $StopPath -Force }
  $status = [ordered]@{
    schema = "covenantgate.watch.status.v1"
    status = "running"
    updated_utc = [DateTime]::UtcNow.ToString("o")
  }
  Write-Utf8NoBomLf $StatusPath (($status | ConvertTo-Json -Depth 10 -Compress))
  $pidObj = [ordered]@{
    schema = "covenantgate.watch.pid.v1"
    pid = $PID
    started_utc = [DateTime]::UtcNow.ToString("o")
  }
  Write-Utf8NoBomLf $PidPath (($pidObj | ConvertTo-Json -Depth 10 -Compress))
  Write-Host "CG_WATCH_STARTED" -ForegroundColor Green
}
function Stop-Watch {
  Ensure-Dir $RuntimeDir
  Write-Utf8NoBomLf $StopPath "stop"
  $status = [ordered]@{
    schema = "covenantgate.watch.status.v1"
    status = "stop_requested"
    updated_utc = [DateTime]::UtcNow.ToString("o")
  }
  Write-Utf8NoBomLf $StatusPath (($status | ConvertTo-Json -Depth 10 -Compress))
  Write-Host "CG_WATCH_STOPPED" -ForegroundColor Green
}
function Watch-Status {
  if(-not (Test-Path -LiteralPath $StatusPath -PathType Leaf)){ Die ("WATCH_STATUS_MISSING: " + $StatusPath) }
  $obj = Read-Text $StatusPath | ConvertFrom-Json -ErrorAction Stop
  Write-Host ("CG_WATCH_STATUS: " + [string]$obj.status)
}
function Show-Help {
  $lines = @(
    "Covenant Gate CLI",
    "",
    "Commands:",
    "  version",
    "  doctor",
    "  quick-check",
    "  run",
    "  last",
    "  watch-start",
    "  watch-stop",
    "  watch-status",
    "  vectors",
    "  conversation-selftest",
    "  stress-negative",
    "  help"
  )
  foreach($line in @(@($lines))){ Write-Host $line }
}
$cmd = $Command.ToLowerInvariant()
switch($cmd){
  "version" { Write-Host ("COVENANT_GATE_VERSION: " + $Version); break }
  "doctor"  { Run-Doctor; break }
  "quick-check" { Run-QuickCheck; break }
  "run" { Run-FullGreen; break }
  "last" { Show-Last; break }
  "watch-start" { Start-Watch; break }
  "watch-stop" { Stop-Watch; break }
  "watch-status" { Watch-Status; break }
  "vectors" { Run-Script "cg_run_test_vectors_v1.ps1"; break }
  "conversation-selftest" { Run-Script "_selftest_cg_conversation_layer_v1.ps1"; break }
  "stress-negative" { Run-Script "selftest_cg_stress_negative_v1.ps1"; break }
  "help" { Show-Help; break }
  default { Die ("UNKNOWN_COMMAND: " + $Command) }
}
