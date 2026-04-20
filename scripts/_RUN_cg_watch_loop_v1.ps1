param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [ValidateSet("start","stop","status","run-once","tail")][string]$Mode = "status"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path

$StateDir   = Join-Path $RepoRoot "scripts\state"
$PidFile    = Join-Path $StateDir "cg_watch.pid"
$Worker     = Join-Path $RepoRoot "scripts\cg_watch_worker_v1.ps1"
$Receipt    = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"
$StatusFile = Join-Path $StateDir "cg_watch.status.json"

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Is-Running([int]$WatchPid){
  try { Get-Process -Id $WatchPid -ErrorAction Stop | Out-Null; return $true }
  catch { return $false }
}

switch($Mode){
  "start" {
    Ensure-Dir $StateDir
    if(Test-Path -LiteralPath $PidFile -PathType Leaf){
      $watchPid = [int](Get-Content -LiteralPath $PidFile | Select-Object -First 1)
      if(Is-Running $watchPid){
        Write-Host ("ALREADY_RUNNING PID=" + $watchPid)
        break
      }
      Remove-Item -LiteralPath $PidFile -Force
    }
    $proc = Start-Process powershell.exe `
      -ArgumentList @(
        "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
        "-File",$Worker,
        "-RepoRoot",$RepoRoot
      ) `
      -WindowStyle Hidden `
      -PassThru
    Set-Content -LiteralPath $PidFile -Value ([string]$proc.Id) -Encoding UTF8
    Write-Host ("WATCH_STARTED PID=" + $proc.Id)
    break
  }

  "stop" {
    if(Test-Path -LiteralPath $PidFile -PathType Leaf){
      $watchPid = [int](Get-Content -LiteralPath $PidFile | Select-Object -First 1)
      if(Is-Running $watchPid){
        Stop-Process -Id $watchPid -Force
        Write-Host ("WATCH_STOPPED PID=" + $watchPid)
      } else {
        Write-Host ("STALE_PID PID=" + $watchPid)
      }
      Remove-Item -LiteralPath $PidFile -Force
    } else {
      Write-Host "NOT_RUNNING"
    }
    break
  }

  "status" {
    if(Test-Path -LiteralPath $PidFile -PathType Leaf){
      $watchPid = [int](Get-Content -LiteralPath $PidFile | Select-Object -First 1)
      if(Is-Running $watchPid){
        Write-Host ("RUNNING PID=" + $watchPid)
      } else {
        Write-Host "STALE_PID"
      }
    } else {
      Write-Host "STOPPED"
    }
    if(Test-Path -LiteralPath $StatusFile -PathType Leaf){
      Get-Content -LiteralPath $StatusFile | Out-Host
    }
    break
  }

  "run-once" {
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
      -File $Worker `
      -RepoRoot $RepoRoot `
      -RunOnce
    if($LASTEXITCODE -ne 0){ throw ("RUN_ONCE_FAILED: " + [string]$LASTEXITCODE) }
    break
  }

  "tail" {
    if(Test-Path -LiteralPath $Receipt -PathType Leaf){
      Get-Content -LiteralPath $Receipt -Tail 20 | Out-Host
    } else {
      Write-Host "NO_RECEIPTS"
    }
    break
  }
}
