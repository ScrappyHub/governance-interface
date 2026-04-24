Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function CG-NormalizeReasonCodes {
  param([object[]]$ReasonCodes)

  $map = [ordered]@{
    "INTENT_DESTRUCTIVE" = "DESTRUCTIVE_INTENT"
    "BRIDGE_BLOCKED_DESTRUCTIVE_INTENT" = "DESTRUCTIVE_INTENT"
    "AI_OR_PROMPT_REQUIRES_EXECUTION_GATE" = "EXECUTION_GATE_REQUIRED"

    "REQUIRES_OPERATOR_CONFIRMATION" = "CONFIRMATION_REQUIRED"
    "CLASSIFIER_REQUIRES_CONFIRMATION" = "CONFIRMATION_REQUIRED"
    "BRIDGE_CONFIRMATION_REQUIRED" = "CONFIRMATION_REQUIRED"
    "DESTRUCTIVE_ACTION_REQUIRES_CONFIRMATION" = "CONFIRMATION_REQUIRED"

    "BRIDGE_BLOCKED_CRITICAL_RISK" = "CRITICAL_RISK"
    "COMMIT_BLOCKED_CRITICAL_RISK" = "CRITICAL_RISK"
    "APPLY_BLOCKED_BY_AI_RISK" = "CRITICAL_RISK"
  }

  $out = New-Object System.Collections.Generic.List[string]

  foreach($r in @(@($ReasonCodes))){
    $s = [string]$r
    if([string]::IsNullOrWhiteSpace($s)){ continue }

    if($map.Contains($s)){
      $out.Add([string]$map[$s]) | Out-Null
    } else {
      $out.Add($s) | Out-Null
    }
  }

  return @(@($out.ToArray()) | Sort-Object -Unique)
}
