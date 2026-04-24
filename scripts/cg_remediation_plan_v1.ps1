param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$AuditBundle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$AuditBundle = (Resolve-Path $AuditBundle).Path

$SummaryPath = Join-Path $AuditBundle "summary.json"
if(-not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)){
  throw ("MISSING_AUDIT_SUMMARY: " + $SummaryPath)
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

$summary = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json -ErrorAction Stop

$missing = @()
foreach($m in @($summary.missing)){
  if(-not [string]::IsNullOrWhiteSpace([string]$m)){ $missing += [string]$m }
}

$steps = New-Object System.Collections.Generic.List[object]

foreach($m in @($missing)){
  $kind = ([string]$m).ToLowerInvariant()

  if($kind -eq "policy"){
    $steps.Add([ordered]@{
      step_id = "create_policy_pack"
      kind = "policy"
      action = "create_file"
      target_rel = "policy/base_policy_v1.json"
      reason_code = "MISSING_POLICY"
      description = "Create a base governance policy pack for repo-level decisions."
      gated = $true
    }) | Out-Null
  }

  if($kind -eq "overlay"){
    $steps.Add([ordered]@{
      step_id = "create_overlay_pack"
      kind = "overlay"
      action = "create_file"
      target_rel = "policy/overlay_v1.json"
      reason_code = "MISSING_OVERLAY"
      description = "Create an overlay policy for repo-specific constraints."
      gated = $true
    }) | Out-Null
  }

  if($kind -eq "schema"){
    $steps.Add([ordered]@{
      step_id = "create_schema_pack"
      kind = "schema"
      action = "create_file"
      target_rel = "schemas/covenantgate.repo_intake.v1.json"
      reason_code = "MISSING_SCHEMA"
      description = "Create a schema contract for repo intake and governance validation."
      gated = $true
    }) | Out-Null
  }

  if($kind -eq "sql"){
    $steps.Add([ordered]@{
      step_id = "create_sql_governance_manifest"
      kind = "sql"
      action = "create_file"
      target_rel = "supabase/migrations/00000000000000_governance_manifest.sql"
      reason_code = "MISSING_SQL"
      description = "Create a SQL governance manifest or migration placeholder for database-aware audits."
      gated = $true
    }) | Out-Null
  }
}

$decision = "allow_plan_only"
if(@($steps.ToArray()).Count -lt 1){ $decision = "no_remediation_needed" }

$plan = [ordered]@{
  schema = "covenantgate.remediation_plan.v1"
  run_id = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
  source_audit_bundle = $AuditBundle
  target_repo = [string]$summary.target_repo
  source_decision = [string]$summary.bridge_decision
  missing = @($missing)
  decision = $decision
  mutation_allowed = $false
  steps = @(@($steps.ToArray()))
  note = "Plan-only remediation. No target repo files were modified."
}

$OutDir = Join-Path $RepoRoot "proofs\receipts\cg_remediation_plan"
Ensure-Dir $OutDir
$OutPath = Join-Path $OutDir ("cg_remediation_plan_" + $plan.run_id + ".json")
$json = ($plan | ConvertTo-Json -Depth 50 -Compress)
Write-Utf8NoBomLf $OutPath $json

Write-Host ("CG_REMEDIATION_PLAN_OUTPUT: " + $OutPath) -ForegroundColor Cyan
Write-Host ("CG_REMEDIATION_PLAN_TARGET: " + [string]$summary.target_repo)
Write-Host ("CG_REMEDIATION_PLAN_DECISION: " + $decision)
Write-Host ("CG_REMEDIATION_PLAN_STEP_COUNT: " + @($steps.ToArray()).Count)
foreach($s in @($steps.ToArray())){
  Write-Host ("CG_REMEDIATION_STEP: " + $s.reason_code + " -> " + $s.target_rel)
}
Write-Host "CG_REMEDIATION_PLAN_OK" -ForegroundColor Green
