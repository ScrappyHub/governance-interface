param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

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
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){ Die ("REPO_ROOT_MISSING: " + $RepoRoot) }

$Example    = Join-Path $RepoRoot "examples\policy.bundle.example.v1.json"
$Priv       = Join-Path $RepoRoot "proofs\keys\id_ed25519"
$VerifyPath = Join-Path $RepoRoot "scripts\cg_verify_policy_bundle_sig_v1.ps1"
$TmpDir     = Join-Path $RepoRoot "proofs\_tmp"
$PSExe      = (Get-Command powershell.exe -ErrorAction Stop).Source
$ssh        = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source

if(-not (Test-Path -LiteralPath $Example -PathType Leaf)){ Die ("MISSING_EXAMPLE_BUNDLE: " + $Example) }
if(-not (Test-Path -LiteralPath $Priv -PathType Leaf)){ Die ("PRIVKEY_MISSING: " + $Priv) }
if(-not (Test-Path -LiteralPath $VerifyPath -PathType Leaf)){ Die ("MISSING_VERIFY_SCRIPT: " + $VerifyPath) }

$null = (Get-Content -LiteralPath $Example -Raw | ConvertFrom-Json -ErrorAction Stop)

Ensure-Dir $TmpDir

. (Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1")

$canonObj = (CG-ReadUtf8NoBom $Example | ConvertFrom-Json -ErrorAction Stop)
$canon    = CG-ToCanonJson $canonObj
$canon    = $canon.Replace("`r`n","`n").Replace("`r","`n")
if(-not $canon.EndsWith("`n")){ $canon += "`n" }

$msg     = Join-Path $TmpDir "policy_bundle_canon_for_sign.txt"
$autoSig = $msg + ".sig"
$Sig     = Join-Path $TmpDir "policy_bundle.sig"
$soSign  = Join-Path $TmpDir "ssh_sign.stdout.txt"
$seSign  = Join-Path $TmpDir "ssh_sign.stderr.txt"

foreach($p in @($msg,$autoSig,$Sig,$soSign,$seSign)){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    Remove-Item -LiteralPath $p -Force
  }
}

Write-Utf8NoBomLf $msg $canon

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = ('-Y sign -f "{0}" -n "covenantgate/policy-bundle" "{1}"' -f $Priv,$msg)
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi
[void]$p.Start()

if(-not $p.WaitForExit(30000)){
  try { $p.Kill() } catch {}
  Die "SIGN_TIMEOUT"
}

$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()

$u = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllBytes($soSign,$u.GetBytes((($stdout -replace "`r`n","`n") -replace "`r","`n")))
[System.IO.File]::WriteAllBytes($seSign,$u.GetBytes((($stderr -replace "`r`n","`n") -replace "`r","`n")))

if(-not (Test-Path -LiteralPath $autoSig -PathType Leaf)){
  Die ("SIGNATURE_MISSING_AFTER_SIGN: " + $autoSig)
}

Copy-Item -LiteralPath $autoSig -Destination $Sig -Force
Write-Host ("SIGNED_OK: " + $Sig) -ForegroundColor Green

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $VerifyPath `
  -RepoRoot $RepoRoot `
  -PolicyBundlePath $Example `
  -SigPath $Sig `
  -Principal "single-tenant/example/authority/covenant-gate" `
  -Namespace "covenantgate/policy-bundle" `
  -TimeoutSec 15 | Out-Host

if($LASTEXITCODE -ne 0){
  Die ("VERIFY_EXIT_NONZERO: " + $LASTEXITCODE)
}

Write-Host "CG_SIG_STACK_SMOKE_TEST_OK" -ForegroundColor Green
