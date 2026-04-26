param(
  [Parameter(Mandatory=$true)][ValidateSet("run")][string]$Command,
  [Parameter(Mandatory=$true)][string]$Repo,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [ValidateSet("plan","explain","sql","action")][string]$Mode = "plan",
  [ValidateSet("stub","openai")][string]$Adapter = "stub"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Runner = Join-Path $RepoRoot "scripts\cg_run_repo_session_v1.ps1"
$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Runner `
  -RepoRoot $RepoRoot `
  -TargetRepo $Repo `
  -Prompt $Prompt `
  -Mode $Mode `
  -Adapter $Adapter

exit $LASTEXITCODE
