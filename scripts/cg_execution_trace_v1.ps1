param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ContextContractPath,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [string]$AiOutputText = "",
  [string]$Decision = "unknown",
  [string[]]$ReasonCodes = @(),
  [string[]]$Events = @(),
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$ContextContractPath = (Resolve-Path $ContextContractPath).Path
if([string]::IsNullOrWhiteSpace($OutDir)){ $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_execution_trace" }

function Ensure-Dir([string]$p){ if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
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
$ctxText = Get-Content -LiteralPath $ContextContractPath -Raw
$runId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ")

$core = [ordered]@{
  schema = "cg.execution.trace.v1"
  run_id = $runId
  context_contract_path = $ContextContractPath
  context_contract_sha256 = Sha256Text $ctxText
  prompt_sha256 = Sha256Text $Prompt
  ai_output_sha256 = Sha256Text $AiOutputText
  decision = $Decision
  reason_codes = @($ReasonCodes | Sort-Object -Unique)
  events = @($Events)
}

$traceHash = Sha256Text (($core | ConvertTo-Json -Depth 50 -Compress))
$trace = [ordered]@{
  schema = $core.schema
  run_id = $core.run_id
  context_contract_path = $core.context_contract_path
  context_contract_sha256 = $core.context_contract_sha256
  prompt_sha256 = $core.prompt_sha256
  ai_output_sha256 = $core.ai_output_sha256
  decision = $core.decision
  reason_codes = $core.reason_codes
  events = $core.events
  trace_hash = $traceHash
}

$outPath = Join-Path $OutDir ("cg_execution_trace_" + $runId + ".json")
Write-Utf8NoBomLf $outPath (($trace | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_EXECUTION_TRACE_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_EXECUTION_TRACE_DECISION: " + $Decision)
Write-Host ("CG_EXECUTION_TRACE_HASH: " + $traceHash)
Write-Host "CG_EXECUTION_TRACE_OK" -ForegroundColor Green
