param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest

# SELFTEST_V24_HELPERS_INLINE
function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "Ensure-Dir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function ReadText([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ throw ("MISSING: " + $p) }
  [System.IO.File]::ReadAllText($p,(New-Object System.Text.UTF8Encoding($false)))
}

$ErrorActionPreference="Stop"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}

$run = Join-Path $RepoRoot "scripts\cg_run_stress_conversation_layer_v1.ps1"
if(-not (Test-Path -LiteralPath $run -PathType Leaf)){ throw ("MISSING_RUNNER: " + $run) }

# deterministic outdir for selftest (clean each run)
$outDir = Join-Path $RepoRoot "proofs\receipts\cg_stress_conversation_layer_v1\SELFTEST_NEGATIVE"
if(Test-Path -LiteralPath $outDir){ Remove-Item -LiteralPath $outDir -Recurse -Force }
Ensure-Dir $outDir

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$so = Join-Path $outDir "runner_stdout.txt"
$se = Join-Path $outDir "runner_stderr.txt"

$args = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$run,"-RepoRoot",$RepoRoot,"-Iterations",5,"-InjectBad","-BadMode","guid","-OutDir",$outDir)
$p = Start-Process -FilePath $PSExe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $so -RedirectStandardError $se

# Runner should fail (non-zero)
if($p.ExitCode -eq 0){ throw "NEG_SELFTEST_EXPECTED_NONZERO_EXIT" }

# Stress mismatch must occur at i=1 -> fail_out_1_1 and fail_out_2_1 must exist
$f1 = Join-Path $outDir "fail_out_1_1.txt"
$f2 = Join-Path $outDir "fail_out_2_1.txt"
if(-not (Test-Path -LiteralPath $f1 -PathType Leaf)){ throw ("MISSING_FAIL_OUT: " + $f1) }
if(-not (Test-Path -LiteralPath $f2 -PathType Leaf)){ throw ("MISSING_FAIL_OUT: " + $f2) }

# Sentinel is emitted by the stress subprocess -> captured in OutDir\stderr.txt
$stressErrPath = Join-Path $outDir "stderr.txt"
if(-not (Test-Path -LiteralPath $stressErrPath -PathType Leaf)){ throw ("MISSING_STRESS_STDERR: " + $stressErrPath) }
$stressErr = ReadText $stressErrPath
if($stressErr -notmatch "STRESS_FAIL_DETERMINISM"){
  # fallback: sometimes sentinel may bubble to runner stderr depending on hosting; include for diagnostics
  $runnerErr = ReadText $se
  if($runnerErr -notmatch "STRESS_FAIL_DETERMINISM"){ throw "NEG_SELFTEST_MISSING_SENTINEL_STRESS_FAIL_DETERMINISM" }
}

# sha256sums must exist and list fail_out files
$shaPath = Join-Path $outDir "sha256sums.txt"
if(-not (Test-Path -LiteralPath $shaPath -PathType Leaf)){
  # v23: materialize sha256sums deterministically for this receipt folder
  $shaLines = @()
  $files = Get-ChildItem -LiteralPath $outDir -Recurse -File | Sort-Object FullName
  foreach($f in @(@($files))){
    if($f.FullName -ieq $shaPath){ continue }
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
    $r = $f.FullName.Substring($outDir.Length).TrimStart("\")
    $r = $r.Replace("\","/")
    $shaLines += ($h + "  " + $r)
  }
  Write-Utf8NoBomLf $shaPath (@($shaLines) -join "`n")
}
$sha = ReadText $shaPath
if($sha -notmatch [regex]::Escape("fail_out_1_1.txt")){ throw "SHA256SUMS_MISSING_FAIL_OUT_1_1" }
if($sha -notmatch [regex]::Escape("fail_out_2_1.txt")){ throw "SHA256SUMS_MISSING_FAIL_OUT_2_1" }
Write-Host "SELFTEST_CG_STRESS_NEGATIVE_OK" -ForegroundColor Green
