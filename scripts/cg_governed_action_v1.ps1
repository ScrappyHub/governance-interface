param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo,
  [Parameter(Mandatory=$true)][ValidateSet("export","test","commit-plan","release-plan","destructive")][string]$Action,
  [switch]$Approve
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

$DndPath = Join-Path $RepoRoot "policy\dnd_policy_v1.json"
$UnlockRoot = Join-Path $RepoRoot "proofs\receipts\cg_re_eval_unlock"
$OutRoot = Join-Path $RepoRoot "proofs\receipts\cg_governed_action"

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
function Read-Json([string]$Path){
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}
function Rel([string]$Path,[string]$Root){
  return $Path.Substring($Root.Length).TrimStart("\").Replace("\","/")
}

if(-not (Test-Path -LiteralPath $DndPath -PathType Leaf)){ throw "DND_POLICY_MISSING" }
if(-not (Test-Path -LiteralPath $UnlockRoot -PathType Container)){ throw "UNLOCK_ROOT_MISSING" }

$dnd = Read-Json $DndPath
$latestUnlockDir = @(Get-ChildItem -LiteralPath $UnlockRoot -Directory | Sort-Object Name | Select-Object -Last 1)[0].FullName
$unlockSummary = Join-Path $latestUnlockDir "summary.json"
$unlock = Read-Json $unlockSummary

if([bool]$unlock.execution_allowed -ne $true){
  throw "EXECUTION_NOT_UNLOCKED"
}

$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")
Ensure-Dir $OutRoot

$denyReasons = New-Object System.Collections.Generic.List[string]
$matchedRules = New-Object System.Collections.Generic.List[string]

$files = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -ErrorAction Stop) | Where-Object {
  $_.FullName -notmatch "\\\.git\\" -and
  $_.FullName -notmatch "\\node_modules\\"
})

foreach($rule in @($dnd.rules)){
  if([string]$rule.action -ne $Action){ continue }

  foreach($pat in @($rule.match)){
    foreach($f in @($files)){
      $r = Rel $f.FullName $TargetRepo
      if($r -like [string]$pat){
        $matchedRules.Add([string]$rule.rule_id) | Out-Null
        foreach($rc in @($rule.reason_codes)){
          $denyReasons.Add([string]$rc) | Out-Null
        }
      }
    }
  }
}

$decision = "allow_plan_only"
if(@(@($denyReasons.ToArray())).Count -gt 0){
  $decision = "deny"
}

if(($Action -eq "commit-plan" -or $Action -eq "release-plan") -and -not $Approve){
  if($decision -ne "deny"){ $decision = "allow_plan_only" }
}

if($Action -eq "test" -or $Action -eq "export"){
  if($decision -ne "deny"){ $decision = "allow_execution" }
}

$result = [ordered]@{
  schema = "covenantgate.governed_action.v1"
  run_id = $runId
  target_repo = $TargetRepo
  action = $Action
  approve = [bool]$Approve
  unlock_summary = $unlockSummary
  dnd_policy = $DndPath
  decision = $decision
  matched_dnd_rules = @(@($matchedRules.ToArray()) | Sort-Object -Unique)
  reason_codes = @(@($denyReasons.ToArray()) | Sort-Object -Unique)
  mutation_performed = $false
  note = "Governed action runner currently emits decision receipts only. Mutation actions require dedicated approved executors."
}

$outPath = Join-Path $OutRoot ("cg_governed_action_" + $runId + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_GOVERNED_ACTION_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_GOVERNED_ACTION: " + $Action)
Write-Host ("CG_GOVERNED_ACTION_DECISION: " + $decision)
Write-Host ("CG_GOVERNED_ACTION_DND_RULES: " + ((@($matchedRules.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_GOVERNED_ACTION_REASON_CODES: " + ((@($denyReasons.ToArray()) | Sort-Object -Unique) -join ","))

if($decision -eq "deny"){
  Write-Host "CG_GOVERNED_ACTION_DENY" -ForegroundColor Yellow
  exit 2
}

Write-Host "CG_GOVERNED_ACTION_OK" -ForegroundColor Green
exit 0
