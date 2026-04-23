param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateSet("commit","export","apply","destructive")][string]$Action,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [string]$ConfirmToken = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$InputPath = (Resolve-Path $InputPath).Path

function Die([string]$m){ throw $m }

function Read-Json([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Die ("MISSING_INPUT: " + $Path) }
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
}

function Get-Prop($Obj,[string]$Name){
  $m = @($Obj.PSObject.Properties.Match($Name))
  if(@($m).Count -lt 1){ return $null }
  return $m[0].Value
}

$case = Read-Json $InputPath
$base = Get-Prop $case "base_policy"
$eval = Get-Prop $case "eval_input"

$decision = "deny"
$reasons = New-Object System.Collections.Generic.List[string]

if($null -eq $base){
  $reasons.Add("MISSING_BASE_POLICY") | Out-Null
}
if($null -eq $eval){
  $reasons.Add("MISSING_EVAL_INPUT") | Out-Null
}

if(@($reasons.ToArray()).Count -eq 0){
  $rules = @($base.rules)
  foreach($rule in $rules){
    $rd = Get-Prop $rule "decision"
    $rc = @(Get-Prop $rule "reason_codes")
    if(-not [string]::IsNullOrWhiteSpace([string]$rd)){
      $decision = [string]$rd
    }
    foreach($r in $rc){
      if(-not [string]::IsNullOrWhiteSpace([string]$r)){ $reasons.Add([string]$r) | Out-Null }
    }
  }
}

if($Action -eq "destructive"){
  if($ConfirmToken -ne "I_UNDERSTAND_DESTRUCTIVE_ACTION"){
    $decision = "deny"
    $reasons.Clear()
    $reasons.Add("DESTRUCTIVE_ACTION_REQUIRES_CONFIRMATION") | Out-Null
  }
}

if($Action -eq "commit"){
  if($decision -ne "allow"){
    $reasons.Add("COMMIT_BLOCKED_BY_GOVERNANCE") | Out-Null
  }
}

if($Action -eq "apply"){
  if($decision -ne "allow"){
    $reasons.Add("APPLY_BLOCKED_BY_GOVERNANCE") | Out-Null
  }
}

if($Action -eq "export"){
  if($decision -ne "allow"){
    $reasons.Add("EXPORT_ALLOWED_WITH_WARNINGS_ONLY") | Out-Null
  }
}

$reasonText = (@($reasons.ToArray()) | Sort-Object -Unique) -join ","

Write-Host ("CG_EXECUTION_ACTION: " + $Action)
Write-Host ("CG_EXECUTION_DECISION: " + $decision)
Write-Host ("CG_EXECUTION_REASON_CODES: " + $reasonText)

if($decision -eq "allow"){
  Write-Host "CG_EXECUTION_GATE_OK" -ForegroundColor Green
  exit 0
}

Write-Host "CG_EXECUTION_GATE_DENY" -ForegroundColor Yellow
exit 2
