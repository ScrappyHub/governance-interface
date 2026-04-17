param(
  [Parameter(Mandatory=$true)][string]$Command,
  [string]$Bundle,
  [string]$Input,
  [string]$Out,
  [string]$Prompt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw $m }

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

switch ($Command) {

  "verify-policy" {
    if(-not $Bundle){ Die "MISSING_BUNDLE" }

    & "$RepoRoot\scripts\cg_verify_policy_bundle_sig_v1.ps1" `
      -RepoRoot $RepoRoot `
      -BundlePath $Bundle

    Write-Host "CG_VERIFY_POLICY_OK"
    break
  }

  "eval" {
    if(-not $Bundle){ Die "MISSING_BUNDLE" }
    if(-not $Input){ Die "MISSING_INPUT" }

    & "$RepoRoot\scripts\cg_eval_v1.ps1" `
      -RepoRoot $RepoRoot `
      -BundlePath $Bundle `
      -InputPath $Input `
      -OutPath $Out

    Write-Host "CG_EVAL_OK"
    break
  }

  "chat" {
    if(-not $Bundle){ Die "MISSING_BUNDLE" }
    if(-not $Prompt){ Die "MISSING_PROMPT" }

    & "$RepoRoot\scripts\cg_conversation_layer_v1.ps1" `
      -RepoRoot $RepoRoot `
      -BundlePath $Bundle `
      -Prompt $Prompt

    Write-Host "CG_CHAT_OK"
    break
  }

  default {
    Die ("UNKNOWN_COMMAND: " + $Command)
  }
}
