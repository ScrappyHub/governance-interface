param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PolicyBundlePath,
  [Parameter(Mandatory=$true)][string]$PolicySigPath,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter()][string]$OutPath = "",
  [Parameter()][string]$Namespace = "covenantgate/policy-bundle"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1")

function Die([string]$m){ throw $m }

function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}

function Emit-Json([Parameter(Mandatory=$true)]$Obj,[string]$Path){
  $j = CG-ToCanonJson $Obj
  $j = $j.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $j.EndsWith("`n")){ $j += "`n" }
  if([string]::IsNullOrWhiteSpace($Path)){
    Write-Output $j
  } else {
    Write-Utf8NoBomLf $Path $j
    Write-Host ("WROTE: " + $Path) -ForegroundColor Green
  }
}

function New-SigDeny([Parameter(Mandatory=$true)]$EvalInput,[Parameter(Mandatory=$true)][string]$ReasonCode){
  $ih = CG-Sha256HexBytes (CG-CanonBytes $EvalInput)
  $engine = "covenantgate.eval.v1"
  $zeros  = ("0" * 64)
  $u      = New-Object System.Text.UTF8Encoding($false)
  $eid    = CG-Sha256HexBytes ($u.GetBytes(($zeros + "`n" + $ih + "`n" + $engine)))
  [pscustomobject]@{
    schema         = "covenantgate.eval_output.v1"
    decision       = "deny"
    reason_codes   = @($ReasonCode)
    policy_hash    = $zeros
    input_hash     = $ih
    engine_version = $engine
    evaluation_id  = $eid
    matched_rules  = @{
      allow = @()
      deny  = @()
    }
  }
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){ Die ("REPO_ROOT_MISSING: " + $RepoRoot) }
if(-not (Test-Path -LiteralPath $PolicyBundlePath -PathType Leaf)){ Die ("MISSING_POLICY_BUNDLE: " + $PolicyBundlePath) }
if(-not (Test-Path -LiteralPath $InputPath -PathType Leaf)){ Die ("MISSING_INPUT: " + $InputPath) }

$rootIn = (CG-ReadUtf8NoBom $InputPath | ConvertFrom-Json -ErrorAction Stop)
$evalIn = $rootIn
if($rootIn -ne $null -and $rootIn.PSObject.Properties.Match("eval_input").Count -gt 0){
  $evalIn = $rootIn.eval_input
}

try {
  $VerifyPath = Join-Path $RepoRoot "scripts\cg_verify_policy_bundle_sig_v1.ps1"
  if(-not (Test-Path -LiteralPath $VerifyPath -PathType Leaf)){ Die ("MISSING_VERIFY_SCRIPT: " + $VerifyPath) }

  & (Get-Command powershell.exe -ErrorAction Stop).Source -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $VerifyPath `
    -RepoRoot $RepoRoot `
    -PolicyBundlePath $PolicyBundlePath `
    -SigPath $PolicySigPath `
    -Principal $Principal `
    -Namespace $Namespace `
    -TimeoutSec 15 | Out-Host

  if($LASTEXITCODE -ne 0){
    throw ("VERIFY_EXIT_NONZERO: " + $LASTEXITCODE)
  }
}
catch {
  $deny = New-SigDeny -EvalInput $evalIn -ReasonCode "POLICY_SIG_INVALID_OR_MISSING"
  Emit-Json -Obj $deny -Path $OutPath
  return
}

$bundle = (CG-ReadUtf8NoBom $PolicyBundlePath | ConvertFrom-Json -ErrorAction Stop)
$base   = $null
$ov     = $null

if($bundle.PSObject.Properties.Match("base_policy").Count -gt 0){
  $base = $bundle.base_policy
}
if($bundle.PSObject.Properties.Match("overlay_policy").Count -gt 0){
  $ov = $bundle.overlay_policy
}

if($null -eq $base){
  Die "POLICY_BUNDLE_MISSING_BASE_POLICY"
}

$outObj = CG-EvalV1 $base $ov $evalIn
Emit-Json -Obj $outObj -Path $OutPath
