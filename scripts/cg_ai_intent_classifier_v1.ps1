param(
  [Parameter(Mandatory=$true)][string]$Text,
  [string]$OutPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

function Sha256Text([string]$Text){
  if($null -eq $Text){ $Text = "" }
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

$lower = $Text.ToLowerInvariant()

$intent = "informational"
$risk = "low"
$confidence = "medium"
$requiresConfirmation = $false
$reasonCodes = New-Object System.Collections.Generic.List[string]

if($lower -match "delete|wipe|format|destroy|remove-item|drop table|truncate|rm -rf"){
  $intent = "destructive"
  $risk = "critical"
  $confidence = "high"
  $requiresConfirmation = $true
  $reasonCodes.Add("INTENT_DESTRUCTIVE") | Out-Null
  $reasonCodes.Add("REQUIRES_OPERATOR_CONFIRMATION") | Out-Null
}
elseif($lower -match "commit|push|tag|release|ship|deploy|apply migration|migrate"){
  $intent = "operational"
  $risk = "medium"
  $confidence = "high"
  $requiresConfirmation = $false
  $reasonCodes.Add("INTENT_OPERATIONAL") | Out-Null
}
elseif($lower -match "policy|schema|overlay|reason code|decision code|audit|governance"){
  $intent = "governance"
  $risk = "low"
  $confidence = "high"
  $requiresConfirmation = $false
  $reasonCodes.Add("INTENT_GOVERNANCE") | Out-Null
}
elseif($lower -match "model|prompt|memory|adapter|ai|llm|claude|openai|pie|koios"){
  $intent = "ai_adapter"
  $risk = "medium"
  $confidence = "medium"
  $requiresConfirmation = $false
  $reasonCodes.Add("INTENT_AI_ADAPTER") | Out-Null
}
else {
  $reasonCodes.Add("INTENT_INFORMATIONAL") | Out-Null
}

$result = [ordered]@{
  schema = "covenantgate.ai.intent.v1"
  text_sha256 = Sha256Text $Text
  intent = $intent
  risk_level = $risk
  confidence = $confidence
  requires_confirmation = $requiresConfirmation
  reason_codes = @(@($reasonCodes.ToArray()))
}

$json = ($result | ConvertTo-Json -Depth 20 -Compress)

if(-not [string]::IsNullOrWhiteSpace($OutPath)){
  Write-Utf8NoBomLf $OutPath $json
}

Write-Output $json
