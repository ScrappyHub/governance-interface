param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Iterations = 200,
  [switch]$InjectBad,
  [ValidateSet("timestamp","guid","unordered")][string]$BadMode = "timestamp",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "Ensure-Dir: empty path" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf  = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  Ensure-Dir (Split-Path -Parent $Path)
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function ReadText([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ throw ("MISSING: " + $p) }
  [System.IO.File]::ReadAllText($p,(New-Object System.Text.UTF8Encoding($false)))
}
function Sha256File([string]$p){ (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant() }
function Sha256Bytes([byte[]]$b){ (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new($b))).Hash.ToLowerInvariant() }
function NowUtc(){ [DateTime]::UtcNow.ToString("o") }
function NowStamp(){ (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss") }

$kind = "cg_stress_conversation_layer_v1"
if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot ("proofs\receipts\" + $kind + "\" + (NowStamp))
}
Ensure-Dir $OutDir

$stress = Join-Path $RepoRoot "scripts\cg_stress_conversation_layer_v1.ps1"
if(-not (Test-Path -LiteralPath $stress -PathType Leaf)){ throw ("MISSING_STRESS: " + $stress) }

$started = NowUtc
$so = Join-Path $OutDir "stdout.txt"
$se = Join-Path $OutDir "stderr.txt"

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$args = @("-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File",$stress,"-RepoRoot",$RepoRoot,"-Iterations",$Iterations,"-OutDir",$OutDir)
if($InjectBad){ $args += @("-InjectBad","-BadMode",$BadMode) }

$p = Start-Process -FilePath $PSExe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $so -RedirectStandardError $se
$exit = $p.ExitCode
$ended = NowUtc

$exitPath = Join-Path $OutDir "exit_code.txt"
Write-Utf8NoBomLf $exitPath ($exit.ToString())

$stdoutHash = Sha256File $so
$stderrHash = Sha256File $se
$engineHash = Sha256File $stress

$rel = $OutDir.Substring($RepoRoot.Length).TrimStart("\")
$rel = $rel.Replace("\","/")

$receipt = [ordered]@{
  schema="covenantgate.receipt.stress.v1"
  version=1
  kind=$kind
  started_utc=$started
  ended_utc=$ended
  ok=($exit -eq 0)
  iterations=$Iterations
  inject_bad=[bool]$InjectBad
  bad_mode=$BadMode
  out_dir_rel=$rel
  stdout_sha256=$stdoutHash
  stderr_sha256=$stderrHash
  exit_code=$exit
  engine_sha256=$engineHash
}
$receiptPath = Join-Path $OutDir "receipt.json"
Write-Utf8NoBomLf $receiptPath (($receipt | ConvertTo-Json -Depth 20 -Compress))

# sha256sums last (covers receipt + transcripts + stress artifacts)
$shaPath = Join-Path $OutDir "sha256sums.txt"
$shaLines = @()
$files = Get-ChildItem -LiteralPath $OutDir -Recurse -File | Sort-Object FullName
foreach($f in @(@($files))){
  if($f.FullName -ieq $shaPath){ continue }
  $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
  $r = $f.FullName.Substring($OutDir.Length).TrimStart("\")
  $r = $r.Replace("\","/")
  $shaLines += ($h + "  " + $r)
}
Write-Utf8NoBomLf $shaPath (@($shaLines) -join "`n")

if($exit -ne 0){

  # v21: sha256sums top of sentinel block
  $shaPath = Join-Path $OutDir "sha256sums.txt"
  if(-not (Test-Path -LiteralPath $shaPath -PathType Leaf)){
    $shaLines = @()
    $files = Get-ChildItem -LiteralPath $OutDir -Recurse -File | Sort-Object FullName
    foreach($f in @(@($files))){
      if($f.FullName -ieq $shaPath){ continue }
      $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
      $r = $f.FullName.Substring($OutDir.Length).TrimStart("\")
      $r = $r.Replace("\","/")
      $shaLines += ($h + "  " + $r)
    }
    Write-Utf8NoBomLf $shaPath (@($shaLines) -join "`n")
  }

  # v19: always emit sha256sums.txt even on failure (covers fail_out files)
  $shaPath = Join-Path $OutDir "sha256sums.txt"
  if(-not (Test-Path -LiteralPath $shaPath -PathType Leaf)){
    $shaLines = @()
    $files = Get-ChildItem -LiteralPath $OutDir -Recurse -File | Sort-Object FullName
    foreach($f in @(@($files))){
      if($f.FullName -ieq $shaPath){ continue }
      $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
      $r = $f.FullName.Substring($OutDir.Length).TrimStart("\")
      $r = $r.Replace("\","/")
      $shaLines += ($h + "  " + $r)
    }
    Write-Utf8NoBomLf $shaPath (@($shaLines) -join "`n")
  }
  # If stress subprocess produced the determinism sentinel, rethrow it exactly
  # v20: sha256sums on failure
  $shaPath = Join-Path $OutDir "sha256sums.txt"
  if(-not (Test-Path -LiteralPath $shaPath -PathType Leaf)){
    $shaLines = @()
    $files = Get-ChildItem -LiteralPath $OutDir -Recurse -File | Sort-Object FullName
    foreach($f in @(@($files))){
      if($f.FullName -ieq $shaPath){ continue }
      $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
      $r = $f.FullName.Substring($OutDir.Length).TrimStart("\")
      $r = $r.Replace("\","/")
      $shaLines += ($h + "  " + $r)
    }
    Write-Utf8NoBomLf $shaPath (@($shaLines) -join "`n")
  }
  $stressErrPath = Join-Path $OutDir "stderr.txt"
  if(Test-Path -LiteralPath $stressErrPath -PathType Leaf){
    $stressErr = ReadText $stressErrPath
    if($stressErr -match "STRESS_FAIL_DETERMINISM"){ throw "STRESS_FAIL_DETERMINISM" }
  }
  throw ("RUN_STRESS_FAILED_EXITCODE: " + $exit)
}
Write-Host "CG_RUN_STRESS_OK" -ForegroundColor Green
