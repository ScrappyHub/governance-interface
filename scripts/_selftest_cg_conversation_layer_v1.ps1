param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Die([string]$m){ throw $m }

function Parse-GatePs1([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    Die ("PARSE_GATE_MISSING: " + $Path)
  }
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
  if($errors -and @(@($errors)).Count -gt 0){
    $e = @(@($errors))[0]
    Die ("PARSE_GATE_FAIL: {0}:{1}:{2}: {3}" -f $Path,$e.Extent.StartLineNumber,$e.Extent.StartColumnNumber,$e.Message)
  }
}

function Read-Utf8NoBom([string]$p){
  $b=[System.IO.File]::ReadAllBytes($p)
  if($b.Length -ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){ $b=$b[3..($b.Length-1)] }
  $u=New-Object System.Text.UTF8Encoding($false,$true)
  $u.GetString($b)
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){ Die ("REPO_ROOT_MISSING: " + $RepoRoot) }

$PSExe       = (Get-Command powershell.exe -ErrorAction Stop).Source
$Lib         = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"
$Make        = Join-Path $RepoRoot "scripts\cg_make_allowed_signers_v1.ps1"
$Verify      = Join-Path $RepoRoot "scripts\cg_verify_policy_bundle_sig_v1.ps1"
$Smoke       = Join-Path $RepoRoot "scripts\cg_sig_stack_smoke_v1.ps1"
$Advisor     = Join-Path $RepoRoot "scripts\cg_conversation_advisor_v1.ps1"
$Bundle      = Join-Path $RepoRoot "examples\policy.bundle.example.v1.json"
$EvalInput   = Join-Path $RepoRoot "examples\eval_input.ingest_packet.example.v1.json"
$TmpDir      = Join-Path $RepoRoot "proofs\_tmp"
$SigPath     = Join-Path $TmpDir "policy_bundle.sig"
$OutPos      = Join-Path $TmpDir "conversation_layer_positive.json"
$OutNeg      = Join-Path $TmpDir "conversation_layer_negative.json"

foreach($t in @($Lib,$Make,$Verify,$Smoke,$Advisor)){
  Parse-GatePs1 $t
}

if(-not (Test-Path -LiteralPath $Bundle -PathType Leaf)){ Die ("MISSING_EXAMPLE_BUNDLE: " + $Bundle) }
if(-not (Test-Path -LiteralPath $EvalInput -PathType Leaf)){ Die ("MISSING_EVAL_INPUT_EXAMPLE: " + $EvalInput) }

$null = (Get-Content -LiteralPath $Bundle -Raw | ConvertFrom-Json -ErrorAction Stop)
$null = (Get-Content -LiteralPath $EvalInput -Raw | ConvertFrom-Json -ErrorAction Stop)

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Smoke -RepoRoot $RepoRoot | Out-Host
if($LASTEXITCODE -ne 0){ Die ("SMOKE_EXIT_NONZERO: " + $LASTEXITCODE) }

if(-not (Test-Path -LiteralPath $SigPath -PathType Leaf)){ Die ("SIG_MISSING_AFTER_SMOKE: " + $SigPath) }

foreach($p in @($OutPos,$OutNeg)){
  if(Test-Path -LiteralPath $p -PathType Leaf){ Remove-Item -LiteralPath $p -Force }
}

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Advisor `
  -RepoRoot $RepoRoot `
  -PolicyBundlePath $Bundle `
  -PolicySigPath $SigPath `
  -Principal "single-tenant/example/authority/covenant-gate" `
  -InputPath $EvalInput `
  -OutPath $OutPos `
  -Namespace "covenantgate/policy-bundle" | Out-Host

if($LASTEXITCODE -ne 0){ Die ("ADVISOR_POSITIVE_EXIT_NONZERO: " + $LASTEXITCODE) }
if(-not (Test-Path -LiteralPath $OutPos -PathType Leaf)){ Die ("ADVISOR_POSITIVE_OUTPUT_MISSING: " + $OutPos) }

$pos = (Read-Utf8NoBom $OutPos | ConvertFrom-Json -ErrorAction Stop)
if($pos.PSObject.Properties.Match("decision").Count -lt 1){ Die "ADVISOR_POSITIVE_MISSING_DECISION" }
Write-Host ("CONVERSATION_POSITIVE_DECISION: " + [string]$pos.decision) -ForegroundColor Green

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Advisor `
  -RepoRoot $RepoRoot `
  -PolicyBundlePath $Bundle `
  -PolicySigPath (Join-Path $TmpDir "missing_policy_bundle.sig") `
  -Principal "single-tenant/example/authority/covenant-gate" `
  -InputPath $EvalInput `
  -OutPath $OutNeg `
  -Namespace "covenantgate/policy-bundle" | Out-Host

if($LASTEXITCODE -ne 0){ Die ("ADVISOR_NEGATIVE_EXIT_NONZERO: " + $LASTEXITCODE) }
if(-not (Test-Path -LiteralPath $OutNeg -PathType Leaf)){ Die ("ADVISOR_NEGATIVE_OUTPUT_MISSING: " + $OutNeg) }

$neg = (Read-Utf8NoBom $OutNeg | ConvertFrom-Json -ErrorAction Stop)
if([string]$neg.decision -ne "deny"){ Die ("ADVISOR_NEGATIVE_NOT_DENY: " + [string]$neg.decision) }

$reasonOk = $false
foreach($r in @(@($neg.reason_codes))){
  if([string]$r -eq "POLICY_SIG_INVALID_OR_MISSING"){ $reasonOk = $true }
}
if(-not $reasonOk){ Die "ADVISOR_NEGATIVE_REASON_MISSING" }

Write-Host "CG_CONVERSATION_LAYER_SELFTEST_OK" -ForegroundColor Green
