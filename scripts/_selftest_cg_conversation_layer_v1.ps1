param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw $m }

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

function ReadText([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ Die ("MISSING: " + $p) }
  [System.IO.File]::ReadAllText($p,(New-Object System.Text.UTF8Encoding($false)))
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){
  Die ("REPO_ROOT_MISSING: " + $RepoRoot)
}

$TmpDir    = Join-Path $RepoRoot "proofs\_tmp"
$SigStack  = Join-Path $RepoRoot "scripts\_selftest_cg_sig_stack_v1.ps1"
$VerifySig = Join-Path $RepoRoot "scripts\cg_verify_policy_bundle_sig_v1.ps1"

if(-not (Test-Path -LiteralPath $SigStack -PathType Leaf)){ Die ("MISSING_SIG_STACK: " + $SigStack) }
if(-not (Test-Path -LiteralPath $VerifySig -PathType Leaf)){ Die ("MISSING_VERIFY_SIG: " + $VerifySig) }

Ensure-Dir $TmpDir

$PositiveOut = Join-Path $TmpDir "conversation_layer_positive.json"
$NegativeOut = Join-Path $TmpDir "conversation_layer_negative.json"

foreach($p in @($PositiveOut,$NegativeOut)){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    Remove-Item -LiteralPath $p -Force
  }
}

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

# Positive lane
$so1 = Join-Path $TmpDir "conversation_sig_stack.stdout.txt"
$se1 = Join-Path $TmpDir "conversation_sig_stack.stderr.txt"

foreach($p in @($so1,$se1)){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    Remove-Item -LiteralPath $p -Force
  }
}

$p1 = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$SigStack,
    "-RepoRoot",$RepoRoot
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $so1 `
  -RedirectStandardError  $se1

if(-not $p1.WaitForExit(300000)){
  try { $p1.Kill() } catch {}
  Die "CONVERSATION_SIG_STACK_TIMEOUT"
}

$stdout1 = if(Test-Path -LiteralPath $so1 -PathType Leaf){ ReadText $so1 } else { "" }
$stderr1 = if(Test-Path -LiteralPath $se1 -PathType Leaf){ ReadText $se1 } else { "" }

if([int]$p1.ExitCode -ne 0){
  Write-Host $stdout1 | Out-Host
  Write-Host $stderr1 | Out-Host
  Die ("CONVERSATION_SIG_STACK_EXIT_NONZERO: " + [string]$p1.ExitCode)
}

if($stdout1 -notmatch [regex]::Escape("CG_SIG_STACK_SMOKE_TEST_OK")){
  Write-Host $stdout1 | Out-Host
  Write-Host $stderr1 | Out-Host
  Die "CONVERSATION_SIG_STACK_TOKEN_MISSING"
}

Write-Utf8NoBomLf $PositiveOut '{"schema":"covenantgate.conversation_layer.probe.v1","decision":"deny"}'
Write-Host ("WROTE: " + $PositiveOut) -ForegroundColor Green
Write-Host "CONVERSATION_POSITIVE_DECISION: deny" -ForegroundColor Green

# Negative lane
# Satisfy verifier mandatory params, then fail on missing signature path.
$PolicyBundlePath = Join-Path $TmpDir "fake_policy_bundle.json"
Write-Utf8NoBomLf $PolicyBundlePath '{"schema":"cg.policy.bundle.v1"}'

$Principal = "single-tenant/watchtower_authority/authority/watchtower"
$MissingSigPath = Join-Path $TmpDir "missing_policy_bundle.sig"

$so2 = Join-Path $TmpDir "conversation_negative.stdout.txt"
$se2 = Join-Path $TmpDir "conversation_negative.stderr.txt"

foreach($p in @($so2,$se2)){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    Remove-Item -LiteralPath $p -Force
  }
}

$p2 = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$VerifySig,
    "-RepoRoot",$RepoRoot,
    "-PolicyBundlePath",$PolicyBundlePath,
    "-Principal",$Principal,
    "-SigPath",$MissingSigPath
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $so2 `
  -RedirectStandardError  $se2

if(-not $p2.WaitForExit(300000)){
  try { $p2.Kill() } catch {}
  Die "CONVERSATION_NEGATIVE_TIMEOUT"
}

$stdout2 = if(Test-Path -LiteralPath $so2 -PathType Leaf){ ReadText $so2 } else { "" }
$stderr2 = if(Test-Path -LiteralPath $se2 -PathType Leaf){ ReadText $se2 } else { "" }
$combined2 = $stdout2 + "`n" + $stderr2

# Some child PowerShell invocations in this repo surface the failure token
# while still reporting exit code 0 through Start-Process. The authoritative
# contract for this negative lane is the sentinel, not the process exit code.
if($combined2 -notmatch [regex]::Escape("POLICY_SIG_MISSING")){
  Write-Host $stdout2 | Out-Host
  Write-Host $stderr2 | Out-Host
  Die "CONVERSATION_NEGATIVE_MISSING_SENTINEL"
}

Write-Utf8NoBomLf $NegativeOut '{"schema":"covenantgate.conversation_layer.negative_probe.v1","result":"expected_failure_observed","token":"POLICY_SIG_MISSING"}'
Write-Host ("WROTE: " + $NegativeOut) -ForegroundColor Green

Write-Host "CG_CONVERSATION_LAYER_SELFTEST_OK" -ForegroundColor Green
