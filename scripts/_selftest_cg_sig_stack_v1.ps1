param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw $m }

function Parse-GatePs1([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("PARSE_GATE_MISSING: " + $Path)
  }
  $t = $null
  $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
  if($e -and @(@($e)).Count -gt 0){
    $x = @(@($e))[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$x.Extent.StartLineNumber,$x.Extent.StartColumnNumber,$x.Message)
  }
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){ Die ("REPO_ROOT_MISSING: " + $RepoRoot) }

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$Targets = @(
  (Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"),
  (Join-Path $RepoRoot "scripts\cg_make_allowed_signers_v1.ps1"),
  (Join-Path $RepoRoot "scripts\cg_verify_policy_bundle_sig_v1.ps1"),
  (Join-Path $RepoRoot "scripts\cg_sig_stack_smoke_v1.ps1")
)

foreach($t in $Targets){
  Parse-GatePs1 $t
}

$Smoke = Join-Path $RepoRoot "scripts\cg_sig_stack_smoke_v1.ps1"
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Smoke -RepoRoot $RepoRoot | Out-Host

if($LASTEXITCODE -ne 0){
  Die ("SELFTEST_SMOKE_EXIT_NONZERO: " + $LASTEXITCODE)
}

Write-Host "CG_SIG_STACK_SELFTEST_OK" -ForegroundColor Green
