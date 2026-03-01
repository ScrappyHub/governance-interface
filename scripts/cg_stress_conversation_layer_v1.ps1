param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [int]$Iterations = 200,
  [string]$OutDir = "",
  [switch]$InjectBad,
  [ValidateSet("timestamp","guid","unordered")][string]$BadMode = "timestamp"
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
function NowStamp(){ (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss") }

$kind = "cg_stress_conversation_layer_v1"
if([string]::IsNullOrWhiteSpace($OutDir)){
  $stamp  = NowStamp
  $OutDir = Join-Path $RepoRoot ("proofs\receipts\" + $kind + "\" + $stamp)
}
Ensure-Dir $OutDir

$log = Join-Path $OutDir "stress_log.txt"

$advisor = Join-Path $RepoRoot "scripts\cg_conversation_advisor_v1.ps1"
if(-not (Test-Path -LiteralPath $advisor -PathType Leaf)){ throw ("MISSING_ADVISOR: " + $advisor) }

$exIn = Join-Path $RepoRoot "examples\eval_input.ingest_packet.example.v1.json"
$base = Join-Path $RepoRoot "examples\policy.base.example.v1.json"
if(-not (Test-Path -LiteralPath $exIn -PathType Leaf)){ throw ("MISSING_EXAMPLE_INPUT: " + $exIn) }
if(-not (Test-Path -LiteralPath $base -PathType Leaf)){ throw ("MISSING_EXAMPLE_BASE_POLICY: " + $base) }

$lines = @()
$lines += ("ITERATIONS=" + $Iterations)
$lines += ("INJECT_BAD=" + $InjectBad)
$lines += ("BAD_MODE=" + $BadMode)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host ("STRESS_START iterations=" + $Iterations + " inject_bad=" + $InjectBad + " bad_mode=" + $BadMode) -ForegroundColor Cyan

for($i=1;$i -le $Iterations;$i++){
  if($InjectBad){
    $o1 = (& $advisor -RepoRoot $RepoRoot -EvalInputPath $exIn -PolicyBasePath $base -InjectBad -BadMode $BadMode 2>&1 | Out-String)
    $o2 = (& $advisor -RepoRoot $RepoRoot -EvalInputPath $exIn -PolicyBasePath $base -InjectBad -BadMode $BadMode 2>&1 | Out-String)
  } else {
    $o1 = (& $advisor -RepoRoot $RepoRoot -EvalInputPath $exIn -PolicyBasePath $base 2>&1 | Out-String)
    if($i -eq 1){
      # golden bytes: canonical LF advisor output (first run)
      $gold = (($o1 -replace "`r`n","`n") -replace "`r","`n")
      Write-Utf8NoBomLf (Join-Path $OutDir "advisor_output.json") $gold
    }
    $o2 = (& $advisor -RepoRoot $RepoRoot -EvalInputPath $exIn -PolicyBasePath $base 2>&1 | Out-String)
  }
  $b1 = [System.Text.Encoding]::UTF8.GetBytes((($o1 -replace "`r`n","`n") -replace "`r","`n"))
  $b2 = [System.Text.Encoding]::UTF8.GetBytes((($o2 -replace "`r`n","`n") -replace "`r","`n"))
  $h1 = (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new($b1))).Hash.ToLowerInvariant()
  $h2 = (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new($b2))).Hash.ToLowerInvariant()
  if($h1 -ne $h2){
    $lines += ("FAIL_DETERMINISM i=" + $i + " h1=" + $h1 + " h2=" + $h2)
    Write-Utf8NoBomLf (Join-Path $OutDir ("fail_out_1_" + $i + ".txt")) $o1
    Write-Utf8NoBomLf (Join-Path $OutDir ("fail_out_2_" + $i + ".txt")) $o2
    throw "STRESS_FAIL_DETERMINISM"
  }
  if(($i % 25) -eq 0){
    $lines += ("OK_CHECKPOINT i=" + $i + " sha=" + $h1 + " elapsed_ms=" + $sw.ElapsedMilliseconds)
    Write-Host ("OK_CHECKPOINT i=" + $i + " sha=" + $h1 + " elapsed_ms=" + $sw.ElapsedMilliseconds) -ForegroundColor Green
  }
}

Write-Utf8NoBomLf $log (@($lines) -join "`n")
Write-Host "CG_STRESS_CONVERSATION_LAYER_OK" -ForegroundColor Green
