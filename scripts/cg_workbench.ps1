Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

while($true){

  Write-Host ""
  Write-Host "=== Covenant Gate Workbench ==="
  Write-Host "1) Run full green"
  Write-Host "2) Conversation test"
  Write-Host "3) Exit"

  $choice = Read-Host "Select"

  switch($choice){

    "1" {
      & .\scripts\_RUN_cg_full_green_v1.ps1 -RepoRoot (Resolve-Path ".").Path
    }

    "2" {
      while($true){
        $input = Read-Host "You"
        if($input -eq "exit"){ break }

        Write-Host "AI: (stub) $input"
      }
    }

    "3" { break }

    default {
      Write-Host "Invalid option"
    }
  }
}
