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

function Sha256-HexFile([string]$Path){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try{
    $fs = [System.IO.File]::OpenRead($Path)
    try{
      $hash = $sha.ComputeHash($fs)
    } finally {
      $fs.Dispose()
    }
  } finally {
    $sha.Dispose()
  }
  $sb = New-Object System.Text.StringBuilder
  for($i=0;$i -lt $hash.Length;$i++){
    [void]$sb.Append($hash[$i].ToString("x2"))
  }
  $sb.ToString()
}

function Run-ChildPs([string]$File,[string[]]$Args,[string]$Label,[string]$BundleDir){
  if(-not (Test-Path -LiteralPath $File -PathType Leaf)){
    Die ("MISSING_SCRIPT: " + $File)
  }

  $PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
  $stdoutPath = Join-Path $BundleDir ($Label + ".stdout.txt")
  $stderrPath = Join-Path $BundleDir ($Label + ".stderr.txt")

  if(Test-Path -LiteralPath $stdoutPath -PathType Leaf){ Remove-Item -LiteralPath $stdoutPath -Force }
  if(Test-Path -LiteralPath $stderrPath -PathType Leaf){ Remove-Item -LiteralPath $stderrPath -Force }

  $argList = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$File) + $Args

  $p = Start-Process -FilePath $PSExe -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  if(-not $p.WaitForExit(300000)){
    try { $p.Kill() } catch {}
    Die ("RUN_TIMEOUT: " + $Label)
  }

  [pscustomobject]@{
    type = "covenantgate.run.receipt.v1"
    label = $Label
    ok = ($p.ExitCode -eq 0)
    exit_code = [int]$p.ExitCode
    script = $File
    stdout = $stdoutPath
    stderr = $stderrPath
  }
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){
  Die ("REPO_ROOT_MISSING: " + $RepoRoot)
}

$ScriptsDir = Join-Path $RepoRoot "scripts"
if(-not (Test-Path -LiteralPath $ScriptsDir -PathType Container)){
  Die ("MISSING_SCRIPTS_DIR: " + $ScriptsDir)
}

$Targets = @(
  (Join-Path $ScriptsDir "_lib_covenantgate_eval_v1.ps1"),
  (Join-Path $ScriptsDir "cg_make_allowed_signers_v1.ps1"),
  (Join-Path $ScriptsDir "cg_verify_policy_bundle_sig_v1.ps1"),
  (Join-Path $ScriptsDir "cg_sig_stack_smoke_v1.ps1"),
  (Join-Path $ScriptsDir "_selftest_cg_sig_stack_v1.ps1"),
  (Join-Path $ScriptsDir "cg_conversation_advisor_v1.ps1"),
  (Join-Path $ScriptsDir "_selftest_cg_conversation_layer_v1.ps1"),
  (Join-Path $ScriptsDir "cg_run_test_vectors_v1.ps1"),
  (Join-Path $ScriptsDir "selftest_cg_stress_negative_v1.ps1")
)

foreach($t in $Targets){
  Parse-GatePs1 $t
}

$ReceiptRoot = Join-Path (Join-Path $RepoRoot "proofs") "receipts"
Ensure-Dir $ReceiptRoot
$NsDir = Join-Path $ReceiptRoot "cg_full_green"
Ensure-Dir $NsDir

$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmssZ")
$BundleDir = Join-Path $NsDir $RunId
Ensure-Dir $BundleDir

$ReceiptNdjson = Join-Path $BundleDir "cg_full_green.ndjson"
$ShaFile       = Join-Path $BundleDir "sha256sums.txt"

$receipts = New-Object System.Collections.Generic.List[object]

$r1 = Run-ChildPs (Join-Path $ScriptsDir "cg_run_test_vectors_v1.ps1") @("-RepoRoot",$RepoRoot) "test_vectors" $BundleDir
[void]$receipts.Add($r1)
if(-not $r1.ok){ Die ("STEP_FAIL: " + $r1.label) }

$r2 = Run-ChildPs (Join-Path $ScriptsDir "selftest_cg_stress_negative_v1.ps1") @("-RepoRoot",$RepoRoot) "stress_negative" $BundleDir
[void]$receipts.Add($r2)
if(-not $r2.ok){ Die ("STEP_FAIL: " + $r2.label) }

$r3 = Run-ChildPs (Join-Path $ScriptsDir "_selftest_cg_sig_stack_v1.ps1") @("-RepoRoot",$RepoRoot) "sig_stack" $BundleDir
[void]$receipts.Add($r3)
if(-not $r3.ok){ Die ("STEP_FAIL: " + $r3.label) }

$r4 = Run-ChildPs (Join-Path $ScriptsDir "_selftest_cg_conversation_layer_v1.ps1") @("-RepoRoot",$RepoRoot) "conversation_layer" $BundleDir
[void]$receipts.Add($r4)
if(-not $r4.ok){ Die ("STEP_FAIL: " + $r4.label) }

$summary = [ordered]@{
  type = "covenantgate.full_green.v1"
  utc = $RunId
  ok = $true
  repo_root = $RepoRoot
  bundle_dir = $BundleDir
  steps = @(
    [ordered]@{ label="test_vectors"; ok=$r1.ok; exit_code=$r1.exit_code },
    [ordered]@{ label="stress_negative"; ok=$r2.ok; exit_code=$r2.exit_code },
    [ordered]@{ label="sig_stack"; ok=$r3.ok; exit_code=$r3.exit_code },
    [ordered]@{ label="conversation_layer"; ok=$r4.ok; exit_code=$r4.exit_code }
  )
}

$lines = New-Object System.Collections.Generic.List[string]
foreach($r in @($receipts.ToArray())){
  [void]$lines.Add(($r | ConvertTo-Json -Compress -Depth 20))
}
[void]$lines.Add(($summary | ConvertTo-Json -Compress -Depth 20))
Write-Utf8NoBomLf $ReceiptNdjson ((@($lines.ToArray()) -join "`n") + "`n")

$rows = New-Object System.Collections.Generic.List[string]
$files = Get-ChildItem -LiteralPath $BundleDir -Recurse -File | Sort-Object FullName
foreach($f in $files){
  if($f.FullName -eq $ShaFile){ continue }
  $rel = $f.FullName.Substring($BundleDir.Length).TrimStart('\')
  $hash = Sha256-HexFile $f.FullName
  [void]$rows.Add(($hash + "  " + $rel))
}
Write-Utf8NoBomLf $ShaFile ((@(@($rows.ToArray()) | Sort-Object) -join "`n") + "`n")

Write-Host ("FULL_GREEN_BUNDLE: " + $BundleDir) -ForegroundColor Green
Write-Host "COVENANT_GATE_FULL_GREEN_OK" -ForegroundColor Green
