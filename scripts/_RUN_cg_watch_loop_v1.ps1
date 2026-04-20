param(
  [string]$RepoRoot,
  [ValidateSet("start","stop","status","run-once","tail")]
  [string]$Mode = "status"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stateDir = Join-Path $RepoRoot "scripts\state"
$pidFile  = Join-Path $stateDir "cg_watch.pid"
$worker   = Join-Path $RepoRoot "scripts\cg_watch_worker_v1.ps1"
$receipt  = Join-Path $RepoRoot "proofs\receipts\cg_watch.ndjson"

function Is-Running($watchPid){
  try { Get-Process -Id $watchPid -ErrorAction Stop | Out-Null; return $true }
  catch { return $false }
}

switch($Mode){

  "start" {
    if(Test-Path $pidFile){
      $watchPid = Get-Content $pidFile
      if(Is-Running $watchPid){
        Write-Host "ALREADY_RUNNING PID=$watchPid"
        return
      }
    }

    $p = Start-Process powershell.exe `
      -ArgumentList "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$worker`" -RepoRoot `"$RepoRoot`"" `
      -WindowStyle Hidden `
      -PassThru

    $null = New-Item -ItemType Directory -Force -Path $stateDir
    Set-Content $pidFile $p.Id

    Write-Host "WATCH_STARTED PID=$($p.Id)"
  }

  "stop" {
    if(Test-Path $pidFile){
      $watchPid = Get-Content $pidFile
      if(Is-Running $watchPid){
        Stop-Process -Id $watchPid -Force
        Write-Host "WATCH_STOPPED PID=$watchPid"
      }
      Remove-Item $pidFile -Force
    } else {
      Write-Host "NOT_RUNNING"
    }
  }

  "status" {
    if(Test-Path $pidFile){
      $watchPid = Get-Content $pidFile
      if(Is-Running $watchPid){
        Write-Host "RUNNING PID=$watchPid"
      } else {
        Write-Host "STALE_PID"
      }
    } else {
      Write-Host "STOPPED"
    }
  }

  "run-once" {
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
      -File $worker `
      -RepoRoot $RepoRoot
  }

  "tail" {
    if(Test-Path $receipt){
      Get-Content $receipt -Tail 20
    } else {
      Write-Host "NO_RECEIPTS"
    }
  }
}