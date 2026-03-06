param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PolicyBundlePath,
  [Parameter(Mandatory=$true)][string]$SigPath,
  [Parameter(Mandatory=$true)][string]$Principal,
  [Parameter()][string]$Namespace = "covenantgate/policy-bundle",
  [Parameter()][int]$TimeoutSec = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1")

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
if(-not (Test-Path -LiteralPath $PolicyBundlePath -PathType Leaf)){ Die ("MISSING_BUNDLE: " + $PolicyBundlePath) }
if(-not (Test-Path -LiteralPath $SigPath -PathType Leaf)){ Die ("POLICY_SIG_MISSING: " + $SigPath) }

$TrustDir = Join-Path (Join-Path $RepoRoot "proofs") "trust"
$Allowed  = Join-Path $TrustDir "allowed_signers"
if(-not (Test-Path -LiteralPath $Allowed -PathType Leaf)){
  Die ("MISSING_ALLOWED_SIGNERS: " + $Allowed + " (run scripts\cg_make_allowed_signers_v1.ps1)")
}

$tmpDir = Join-Path (Join-Path $RepoRoot "proofs") "_tmp"
Ensure-Dir $tmpDir

$canonObj = (CG-ReadUtf8NoBom $PolicyBundlePath | ConvertFrom-Json -ErrorAction Stop)
$canon = CG-ToCanonJson $canonObj
$canon = $canon.Replace("`r`n","`n").Replace("`r","`n")
if(-not $canon.EndsWith("`n")){ $canon += "`n" }

$msgPath = Join-Path $tmpDir "policy_bundle_canon_verify.txt"
Write-Utf8NoBomLf $msgPath $canon

$stdoutPath = Join-Path $tmpDir "ssh_verify.stdout.txt"
$stderrPath = Join-Path $tmpDir "ssh_verify.stderr.txt"

if(Test-Path -LiteralPath $stdoutPath -PathType Leaf){ Remove-Item -LiteralPath $stdoutPath -Force }
if(Test-Path -LiteralPath $stderrPath -PathType Leaf){ Remove-Item -LiteralPath $stderrPath -Force }

$ssh = (Get-Command ssh-keygen.exe -ErrorAction Stop).Source

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ssh
$psi.Arguments = ('-Y verify -f "{0}" -I "{1}" -n "{2}" -s "{3}"' -f $Allowed,$Principal,$Namespace,$SigPath)
$psi.UseShellExecute = $false
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $psi

[void]$p.Start()
$p.StandardInput.Write($canon)
$p.StandardInput.Close()

if(-not $p.WaitForExit($TimeoutSec * 1000)){
  try { $p.Kill() } catch {}
  Die ("NATIVE_TIMEOUT: " + $ssh)
}

$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()

$u = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllBytes($stdoutPath, $u.GetBytes((($stdout -replace "`r`n","`n") -replace "`r","`n")))
[System.IO.File]::WriteAllBytes($stderrPath, $u.GetBytes((($stderr -replace "`r`n","`n") -replace "`r","`n")))

if($p.ExitCode -ne 0){
  Die ("POLICY_SIG_INVALID :: stdout=" + $stdoutPath + " stderr=" + $stderrPath)
}

Write-Host "POLICY_SIG_OK" -ForegroundColor Green
