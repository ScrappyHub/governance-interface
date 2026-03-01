param(
  [Parameter(Mandatory=$true)][string]$BasePolicyPath,
  [Parameter(Mandatory=$false)][string]$OverlayPolicyPath,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$false)][string]$OutPath
)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path (Split-Path -Parent $PSCommandPath) "_lib_covenantgate_eval_v1.ps1")
function Die([string]$msg){ throw $msg }
if(-not (Test-Path -LiteralPath $BasePolicyPath -PathType Leaf)){ Die ("Missing base policy: " + $BasePolicyPath) }
if(-not (Test-Path -LiteralPath $InputPath -PathType Leaf)){ Die ("Missing input: " + $InputPath) }
if($OverlayPolicyPath -and -not (Test-Path -LiteralPath $OverlayPolicyPath -PathType Leaf)){ Die ("Missing overlay: " + $OverlayPolicyPath) }
$base = (CG-ReadUtf8NoBom $BasePolicyPath | ConvertFrom-Json -ErrorAction Stop)
$ov = $null; if($OverlayPolicyPath){ $ov = (CG-ReadUtf8NoBom $OverlayPolicyPath | ConvertFrom-Json -ErrorAction Stop) }
$inp = (CG-ReadUtf8NoBom $InputPath | ConvertFrom-Json -ErrorAction Stop)
$out = CG-EvalV1 $base $ov $inp
$j = CG-ToCanonJson $out
$j2 = ($j -replace "`r`n","`n") -replace "`r","`n"
if(-not $j2.EndsWith("`n")){ $j2 += "`n" }
if($OutPath){
  $u = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($OutPath, $u.GetBytes($j2))
  Write-Host ("WROTE: " + $OutPath) -ForegroundColor Green
} else {
  Write-Output $j2
}
