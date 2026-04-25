param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateSet("blank","repo","uploaded-files")][string]$Mode,
  [string]$TargetRepo = "",
  [string]$Prompt = "",
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_work_session"
}

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "ENSURE_DIR_EMPTY" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$Path,[string]$Text){
  $enc = New-Object System.Text.UTF8Encoding($false)
  $lf = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $lf.EndsWith("`n")){ $lf += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir){ Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path,$lf,$enc)
}
function Sha256Text([string]$Text){
  if($null -eq $Text){ $Text = "" }
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
$repoAttached = $false
$schemaAttached = $false
$overlayAttached = $false
$policyAttached = $false
$sqlAttached = $false
$missing = New-Object System.Collections.Generic.List[string]
$nextPrompts = New-Object System.Collections.Generic.List[string]

if($Mode -eq "repo"){
  if([string]::IsNullOrWhiteSpace($TargetRepo)){ throw "TARGET_REPO_REQUIRED_FOR_REPO_MODE" }
  $TargetRepo = (Resolve-Path $TargetRepo).Path
  $repoAttached = $true

  $files = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -ErrorAction Stop) | Where-Object {
    $_.FullName -notmatch "\\\.git\\" -and
    $_.FullName -notmatch "\\node_modules\\" -and
    $_.FullName -notmatch "\\proofs\\" -and
    $_.FullName -notmatch "\\release\\"
  })

  foreach($f in @(@($files))){
    $rel = $f.FullName.Substring($TargetRepo.Length).TrimStart("\").Replace("\","/")
    $lower = $rel.ToLowerInvariant()
    if($lower -match "policy" -and $lower.EndsWith(".json")){ $policyAttached = $true }
    if($lower -match "overlay" -and $lower.EndsWith(".json")){ $overlayAttached = $true }
    if($lower -match "schema" -and $lower.EndsWith(".json")){ $schemaAttached = $true }
    if($lower.EndsWith(".sql")){ $sqlAttached = $true }
  }

  if(-not $policyAttached){ $missing.Add("policy") | Out-Null; $nextPrompts.Add("Create missing base policy?") | Out-Null }
  if(-not $overlayAttached){ $missing.Add("overlay") | Out-Null; $nextPrompts.Add("Create missing overlay policy?") | Out-Null }
  if(-not $schemaAttached){ $missing.Add("schema") | Out-Null; $nextPrompts.Add("Create missing schema contract?") | Out-Null }
  if(-not $sqlAttached){ $missing.Add("sql") | Out-Null; $nextPrompts.Add("Create SQL governance manifest?") | Out-Null }
}

if($Mode -eq "blank"){
  $nextPrompts.Add("Continue as plan-only workspace?") | Out-Null
  $nextPrompts.Add("Create a base policy pack for this new workspace?") | Out-Null
  $nextPrompts.Add("Create an overlay policy when constraints are known?") | Out-Null
}

if($Mode -eq "uploaded-files"){
  $nextPrompts.Add("Classify uploaded files into policy/schema/overlay/assets?") | Out-Null
  $nextPrompts.Add("Continue as plan-only until files are promoted into a governed repo?") | Out-Null
}

$decision = "allow_plan_only"
$mutationAllowed = $false
$executionAllowed = $false
$reasonCodes = New-Object System.Collections.Generic.List[string]

if($Mode -eq "repo"){
  if(@(@($missing.ToArray())).Count -gt 0){
    $reasonCodes.Add("REPO_GOVERNANCE_ASSETS_MISSING") | Out-Null
    foreach($m in @(@($missing.ToArray()))){
      $reasonCodes.Add(("MISSING_" + ([string]$m).ToUpperInvariant())) | Out-Null
    }
  } else {
    $decision = "allow_governed_work"
    $reasonCodes.Add("REPO_GOVERNANCE_ASSETS_PRESENT") | Out-Null
  }
}

if($Mode -eq "blank"){
  $reasonCodes.Add("NO_REPO_ATTACHED") | Out-Null
  $reasonCodes.Add("PLAN_ONLY_WORKSPACE") | Out-Null
}

if($Mode -eq "uploaded-files"){
  $reasonCodes.Add("UPLOADED_FILES_ATTACHED") | Out-Null
  $reasonCodes.Add("PLAN_ONLY_UNTIL_GOVERNED_REPO") | Out-Null
}

$session = [ordered]@{
  schema = "covenantgate.work_session.v1"
  run_id = $runId
  workspace_mode = $Mode
  target_repo = $TargetRepo
  repo_attached = $repoAttached
  policy_attached = $policyAttached
  schema_attached = $schemaAttached
  overlay_attached = $overlayAttached
  sql_attached = $sqlAttached
  missing = @(@($missing.ToArray()))
  prompt_sha256 = Sha256Text $Prompt
  prompt_preview = $Prompt.Substring(0,[Math]::Min(240,$Prompt.Length))
  decision = $decision
  mutation_allowed = $mutationAllowed
  execution_allowed = $executionAllowed
  can_plan = $true
  can_explain = $true
  can_generate_artifacts = $true
  can_mutate = $mutationAllowed
  can_execute = $executionAllowed
  reason_codes = @(@($reasonCodes.ToArray()) | Sort-Object -Unique)
  next_prompts = @(@($nextPrompts.ToArray()))
  note = "Deny-first workspace: planning and artifact generation are allowed; repo mutation/execution require explicit governed apply."
}

$outPath = Join-Path $OutDir ("cg_work_session_" + $runId + ".json")
Write-Utf8NoBomLf $outPath (($session | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_WORK_SESSION_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_WORK_SESSION_MODE: " + $Mode)
Write-Host ("CG_WORK_SESSION_DECISION: " + $decision)
Write-Host ("CG_WORK_SESSION_MUTATION_ALLOWED: " + $mutationAllowed)
Write-Host ("CG_WORK_SESSION_EXECUTION_ALLOWED: " + $executionAllowed)
Write-Host ("CG_WORK_SESSION_REASON_CODES: " + ((@($reasonCodes.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_WORK_SESSION_NEXT_PROMPTS: " + ((@($nextPrompts.ToArray())) -join " | "))
Write-Host "CG_WORK_SESSION_OK" -ForegroundColor Green
