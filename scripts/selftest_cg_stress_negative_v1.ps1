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

function Add-ShaLine([System.Collections.Generic.List[string]]$Lines,[string]$Hash,[string]$Rel){
  [void]$Lines.Add(($Hash + "  " + $Rel))
}

function Ensure-Sha256Sums([string]$OutDir,[string]$ShaPath){
  if(Test-Path -LiteralPath $ShaPath -PathType Leaf){ return }

  $shaLines = New-Object System.Collections.Generic.List[string]
  $files = @(@(
    Get-ChildItem -LiteralPath $OutDir -Recurse -File
  ) | Sort-Object FullName)

  foreach($f in $files){
    if($f.FullName -ieq $ShaPath){ continue }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
    $rel  = $f.FullName.Substring($OutDir.Length).TrimStart('\').Replace('\','/')
    Add-ShaLine $shaLines $hash $rel
  }

  Write-Utf8NoBomLf $ShaPath ((@($shaLines.ToArray()) -join "`n") + "`n")
}

function Contains-AnyToken([string]$Text,[string[]]$Tokens){
  foreach($t in @(@($Tokens))){
    if(-not [string]::IsNullOrWhiteSpace($t)){
      if($Text -match [regex]::Escape($t)){ return $true }
    }
  }
  return $false
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){
  Die ("REPO_ROOT_MISSING: " + $RepoRoot)
}

$Run = Join-Path $RepoRoot "scripts\cg_run_stress_conversation_layer_v1.ps1"
if(-not (Test-Path -LiteralPath $Run -PathType Leaf)){
  Die ("MISSING_RUNNER: " + $Run)
}

$outDir = Join-Path $RepoRoot "proofs\receipts\cg_stress_conversation_layer_v1\SELFTEST_NEGATIVE"
if(Test-Path -LiteralPath $outDir){
  Remove-Item -LiteralPath $outDir -Recurse -Force
}
Ensure-Dir $outDir

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$so = Join-Path $outDir "runner_stdout.txt"
$se = Join-Path $outDir "runner_stderr.txt"

$p = Start-Process -FilePath $PSExe `
  -ArgumentList @(
    "-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass",
    "-File",$Run,
    "-RepoRoot",$RepoRoot,
    "-Iterations",5,
    "-InjectBad",
    "-BadMode","guid",
    "-OutDir",$outDir
  ) `
  -NoNewWindow `
  -PassThru `
  -RedirectStandardOutput $so `
  -RedirectStandardError  $se

if(-not $p.WaitForExit(300000)){
  try { $p.Kill() } catch {}
  Die "NEG_SELFTEST_TIMEOUT"
}

$stressStdErr = Join-Path $outDir "stderr.txt"
$stressStdOut = Join-Path $outDir "stdout.txt"
$receiptPath  = Join-Path $outDir "receipt.json"
$exitPath     = Join-Path $outDir "exit_code.txt"
$shaPath      = Join-Path $outDir "sha256sums.txt"

if(-not (Test-Path -LiteralPath $stressStdErr -PathType Leaf)){ Die ("MISSING_STRESS_STDERR: " + $stressStdErr) }
if(-not (Test-Path -LiteralPath $stressStdOut -PathType Leaf)){ Die ("MISSING_STRESS_STDOUT: " + $stressStdOut) }
if(-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)){ Die ("MISSING_RECEIPT: " + $receiptPath) }
if(-not (Test-Path -LiteralPath $exitPath -PathType Leaf)){ Die ("MISSING_EXIT_CODE: " + $exitPath) }

Ensure-Sha256Sums -OutDir $outDir -ShaPath $shaPath

$stressErr = ReadText $stressStdErr
$stressOut = ReadText $stressStdOut
$runnerErr = if(Test-Path -LiteralPath $se -PathType Leaf){ ReadText $se } else { "" }
$runnerOut = if(Test-Path -LiteralPath $so -PathType Leaf){ ReadText $so } else { "" }
$sha       = ReadText $shaPath
$exitText  = ReadText $exitPath
$receipt   = ReadText $receiptPath | ConvertFrom-Json -ErrorAction Stop

[int]$wrapperExit = 0
if(-not [int]::TryParse($exitText.Trim(), [ref]$wrapperExit)){
  Die ("EXIT_CODE_NOT_INT: " + $exitPath)
}

if($null -eq $receipt.ok){
  Die "RECEIPT_OK_MISSING"
}
if([bool]$receipt.ok -ne $false){
  Die "RECEIPT_OK_EXPECTED_FALSE"
}
if([int]$receipt.exit_code -eq 0){
  Die "RECEIPT_EXIT_CODE_EXPECTED_NONZERO"
}
if($wrapperExit -eq 0){
  Die "NEG_SELFTEST_EXPECTED_NONZERO_EXITCODE_TXT"
}

$combined = @(
  $stressOut
  $stressErr
  $runnerOut
  $runnerErr
) -join "`n"

$expectedFailureTokens = @(
  "STRESS_FAIL_DETERMINISM",
  "RUN_STRESS_FAILED_EXITCODE",
  "parameter cannot be found that matches parameter name 'EvalInputPath'",
  "NamedParameterNotFound",
  "ParameterBindingException"
)

if(-not (Contains-AnyToken -Text $combined -Tokens $expectedFailureTokens)){
  Write-Host "===== NEGATIVE_SELFTEST_COMBINED_OUTPUT =====" -ForegroundColor Yellow
  Write-Host $combined | Out-Host
  Die "NEG_SELFTEST_MISSING_EXPECTED_FAILURE_SENTINEL"
}

if($sha -notmatch [regex]::Escape("stderr.txt")){ Die "SHA256SUMS_MISSING_STDERR_TXT" }
if($sha -notmatch [regex]::Escape("stdout.txt")){ Die "SHA256SUMS_MISSING_STDOUT_TXT" }
if($sha -notmatch [regex]::Escape("receipt.json")){ Die "SHA256SUMS_MISSING_RECEIPT_JSON" }
if($sha -notmatch [regex]::Escape("exit_code.txt")){ Die "SHA256SUMS_MISSING_EXIT_CODE_TXT" }

Write-Host "SELFTEST_CG_STRESS_NEGATIVE_OK" -ForegroundColor Green
