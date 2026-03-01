param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function EnsureDir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }
$src = Join-Path $RepoRoot "test_vectors\expected_generated"
$dst = Join-Path $RepoRoot "test_vectors\expected"
if(-not (Test-Path -LiteralPath $src -PathType Container)){ Die ("Missing expected_generated: " + $src) }
EnsureDir $dst
$files = @(@(Get-ChildItem -LiteralPath $src -Filter "*.expected.json" -File) | Sort-Object FullName)
if($files.Count -lt 1){ Die ("No generated expected files in: " + $src) }
foreach($f in $files){ Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dst $f.Name) -Force }
$after = @(@(Get-ChildItem -LiteralPath $dst -Filter "*.expected.json" -File))
if($after.Count -lt $files.Count){ Die ("PIN_EXPECTED_INCOMPLETE: wanted=" + $files.Count + " got=" + $after.Count) }
Write-Host ("PINNED_EXPECTED_OK: " + $files.Count + " files -> " + $dst) -ForegroundColor Green
