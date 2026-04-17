param([Parameter(Mandatory=$true)][string]$RepoRoot,[switch]$GenerateExpected)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
. (Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1")
function Die([string]$msg){ throw $msg }
function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }
$casesDir = Join-Path $RepoRoot "test_vectors\cases"
if(-not (Test-Path -LiteralPath $casesDir -PathType Container)){ Die ("Missing cases dir: " + $casesDir) }
$expDir = Join-Path $RepoRoot "test_vectors\expected"
$genDir = Join-Path $RepoRoot "test_vectors\expected_generated"
EnsureDir $expDir; EnsureDir $genDir
function CanonOut($o){ $j=CG-ToCanonJson $o; $j2=($j -replace "`r`n","`n") -replace "`r","`n"; if(-not $j2.EndsWith("`n")){ $j2 += "`n" }; $j2 }
function AssertEqual([string]$a,[string]$b,[string]$tag){ if($a -ne $b){ Die ("ASSERT_FAIL: " + $tag + "`n---A---`n" + $a + "`n---B---`n" + $b) } }
$caseFiles = @(@(Get-ChildItem -LiteralPath $casesDir -Filter "*.json" -File) | Sort-Object FullName)
if(@(@($caseFiles)).Count -lt 1){ Die "NO_TEST_VECTORS" }
foreach($cf in $caseFiles){
  $case=(CG-ReadUtf8NoBom $cf.FullName | ConvertFrom-Json -ErrorAction Stop)
  $id=[string]$case.case_id; if([string]::IsNullOrWhiteSpace($id)){ Die ("CASE_ID_MISSING: " + $cf.FullName) }
  $base=$case.base_policy
  $ov=$null; if(@(@(@(@($case.PSObject.Properties.Match("overlay_policy"))))).Count -gt 0){ $ov=$case.overlay_policy }
  $inp=$case.eval_input
  $out=CG-EvalV1 $base $ov $inp
  $expPath=Join-Path $expDir ($id + ".expected.json")
  $genPath=Join-Path $genDir ($id + ".expected.json")
  $hasPinned=$false; $expected=$null
  if(Test-Path -LiteralPath $expPath -PathType Leaf){
    $expected=(CG-ReadUtf8NoBom $expPath | ConvertFrom-Json -ErrorAction Stop)
    $hasPinned=$true
  }

  if($GenerateExpected){
    $u=[pscustomobject]@{ schema="covenantgate.eval_expected.v1"; case_id=$id; output=$out }
    $txt=CanonOut $u
    $u8=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllBytes($genPath, $u8.GetBytes($txt))
    Write-Host ("GENERATED_EXPECTED: " + $genPath) -ForegroundColor Yellow
    if(-not $hasPinned){ continue }
  }

  if(-not $hasPinned){
    Die ("MISSING_EXPECTED: " + $expPath + " (run with -GenerateExpected once, then pin expected_generated -> expected and commit)")
  }
  $want=CanonOut $expected
  $gotObj=[pscustomobject]@{ schema="covenantgate.eval_expected.v1"; case_id=$id; output=$out }
  $got=CanonOut $gotObj
  AssertEqual $got $want ("VECTOR_MISMATCH: " + $id)
  Write-Host ("VECTOR_OK: " + $id) -ForegroundColor Green
}
$sample=$caseFiles[0]; $case2=(CG-ReadUtf8NoBom $sample.FullName | ConvertFrom-Json -ErrorAction Stop)
$ov2=$null; if(@(@(@(@($case2.PSObject.Properties.Match("overlay_policy"))))).Count -gt 0){ $ov2=$case2.overlay_policy }
$o1=CG-EvalV1 $case2.base_policy $ov2 $case2.eval_input
$o2=CG-EvalV1 $case2.base_policy $ov2 $case2.eval_input
AssertEqual (CanonOut $o1) (CanonOut $o2) "DETERMINISM_BYTES"
Write-Host "DETERMINISM_OK" -ForegroundColor Green
Write-Host "TESTS_DONE_OK" -ForegroundColor Cyan
