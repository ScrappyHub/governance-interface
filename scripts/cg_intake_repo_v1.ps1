param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo,
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot "watch_inputs" }

$LibPath = Join-Path $RepoRoot "scripts\_lib_covenantgate_eval_v1.ps1"
if(-not (Test-Path -LiteralPath $LibPath -PathType Leaf)){ throw ("MISSING_LIB: " + $LibPath) }
. $LibPath

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
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
function RelPath([string]$Path,[string]$Root){
  $r = $Path.Substring($Root.Length).TrimStart("\")
  return $r.Replace("\","/")
}

Ensure-Dir $OutDir

$allFiles = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -ErrorAction Stop) | Where-Object {
  $_.FullName -notmatch "\\\.git\\" -and
  $_.FullName -notmatch "\\node_modules\\" -and
  $_.FullName -notmatch "\\release\\" -and
  $_.FullName -notmatch "\\proofs\\"
} | Sort-Object FullName)

$signals = New-Object System.Collections.Generic.List[string]
$assets  = New-Object System.Collections.Generic.List[object]

foreach($f in @(@($allFiles))){
  $rel = RelPath $f.FullName $TargetRepo
  $name = $f.Name.ToLowerInvariant()
  $ext = $f.Extension.ToLowerInvariant()
  $kind = "unknown"
  if($rel -match "overlay" -and $ext -eq ".json"){ $kind = "overlay"; $signals.Add("OVERLAY_FOUND") | Out-Null }
  elseif($rel -match "schema" -and $ext -eq ".json"){ $kind = "schema"; $signals.Add("SCHEMA_FOUND") | Out-Null }
  elseif($rel -match "policy" -and $ext -eq ".json"){ $kind = "policy"; $signals.Add("POLICY_FOUND") | Out-Null }
  elseif($ext -eq ".sql"){ $kind = "sql"; $signals.Add("SQL_FOUND") | Out-Null }
  elseif($name -eq "package.json"){ $kind = "node_project"; $signals.Add("NODE_PROJECT") | Out-Null }
  elseif($rel -match "supabase"){ $kind = "supabase"; $signals.Add("SUPABASE_FOUND") | Out-Null }
  elseif($rel -match "memory|canon|context"){ $kind = "memory"; $signals.Add("MEMORY_FOUND") | Out-Null }
  elseif($name -like "_run_*.ps1"){ $kind = "runner"; $signals.Add("RUNNER_FOUND") | Out-Null }
  if($kind -ne "unknown"){
    $assets.Add([ordered]@{ kind=$kind; path=$rel; sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant() }) | Out-Null
  }
}

$uniqueSignals = @(@($signals.ToArray()) | Sort-Object -Unique)
$assetArray = @(@($assets.ToArray()))

$required = @("policy","overlay","schema","sql","runner")
$foundKinds = @(@($assetArray) | ForEach-Object { $_.kind } | Sort-Object -Unique)
$missing = New-Object System.Collections.Generic.List[string]
foreach($r in @(@($required))){
  if($foundKinds -notcontains $r){ $missing.Add($r) | Out-Null }
}

$decision = "allow"
$reasonCodes = New-Object System.Collections.Generic.List[string]
if(@(@($missing.ToArray())).Count -gt 0){
  $decision = "deny"
  foreach($m in @(@($missing.ToArray()))){ $reasonCodes.Add(("MISSING_" + $m.ToUpperInvariant())) | Out-Null }
} else {
  $reasonCodes.Add("REPO_GOVERNANCE_ASSETS_PRESENT") | Out-Null
}

$basePolicy = [ordered]@{
  policy_id = "cg.repo.intake.policy.v1"
  default_decision = "deny"
  rules = @(
    [ordered]@{ rule_id="repo_intake_result"; decision=$decision; reason_codes=@(@($reasonCodes.ToArray())) }
  )
}
$evalInput = [ordered]@{
  input_id = ("repo_intake:" + (Split-Path -Leaf $TargetRepo))
  target_repo = $TargetRepo
  signals = @(@($uniqueSignals))
  assets = @(@($assetArray))
  missing = @(@($missing.ToArray()))
}
$case = [ordered]@{
  case_id = ("repo_intake_" + (Split-Path -Leaf $TargetRepo))
  base_policy = $basePolicy
  overlay_policy = $null
  eval_input = $evalInput
}

$outName = ("repo_intake_" + (Split-Path -Leaf $TargetRepo) + ".json")
$outPath = Join-Path $OutDir $outName
Write-Utf8NoBomLf $outPath (($case | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_INTAKE_REPO_WATCH_INPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_INTAKE_DECISION: " + $decision) -ForegroundColor Yellow
Write-Host ("CG_INTAKE_REASON_CODES: " + ((@($reasonCodes.ToArray())) -join ",")) -ForegroundColor Yellow
Write-Host "CG_INTAKE_REPO_OK" -ForegroundColor Green
