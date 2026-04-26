param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$TargetRepo,
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = (Resolve-Path $TargetRepo).Path

if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_repo_context_contract"
}

$SchemaIngest = Join-Path $RepoRoot "scripts\cg_schema_contract_ingest_v1.ps1"
$DndPolicy = Join-Path $RepoRoot "policy\dnd_policy_v1.json"
$DynamicDndPolicy = Join-Path $RepoRoot "policy\dynamic_dnd_policy_v1.json"
$AiOverlay = Join-Path $RepoRoot "policy\ai_overlay_v1.json"

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
function Sha256File([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return "" }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Sha256Text([string]$Text){
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir

$files = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -ErrorAction Stop) | Where-Object {
  $_.FullName -notmatch "\\\.git\\" -and
  $_.FullName -notmatch "\\node_modules\\" -and
  $_.FullName -notmatch "\\proofs\\" -and
  $_.FullName -notmatch "\\release\\"
})

$langs = New-Object System.Collections.Generic.List[string]
foreach($f in @($files)){
  $e = $f.Extension.ToLowerInvariant()
  if($e -eq ".ps1"){ $langs.Add("powershell") | Out-Null }
  if($e -eq ".sql"){ $langs.Add("sql") | Out-Null }
  if($e -eq ".ts" -or $e -eq ".tsx" -or $e -eq ".js" -or $e -eq ".jsx"){ $langs.Add("typescript_javascript") | Out-Null }
  if($e -eq ".py"){ $langs.Add("python") | Out-Null }
  if($e -eq ".cs"){ $langs.Add("csharp") | Out-Null }
  if($e -eq ".go"){ $langs.Add("go") | Out-Null }
  if($e -eq ".rs"){ $langs.Add("rust") | Out-Null }
  if($e -eq ".java"){ $langs.Add("java") | Out-Null }
}

$langList = @(@($langs.ToArray()) | Sort-Object -Unique)

$schemaContractPath = ""
$schemaContractHash = ""
if(Test-Path -LiteralPath $SchemaIngest -PathType Leaf){
  $schemaOut = Join-Path $OutDir "_schema_contract"
  Ensure-Dir $schemaOut
  $PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source
  & $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
    -File $SchemaIngest `
    -RepoRoot $RepoRoot `
    -TargetRepo $TargetRepo `
    -OutDir $schemaOut | Out-Null

  if($LASTEXITCODE -eq 0){
    $c = @(Get-ChildItem -LiteralPath $schemaOut -Filter "cg_schema_contract_*.json" -File | Sort-Object Name | Select-Object -Last 1)
    if(@($c).Count -gt 0){
      $schemaContractPath = $c[0].FullName
      $schemaContractHash = Sha256File $schemaContractPath
    }
  }
}

$rulePacks = [ordered]@{
  dnd_policy = [ordered]@{
    path = $DndPolicy
    sha256 = Sha256File $DndPolicy
  }
  dynamic_dnd_policy = [ordered]@{
    path = $DynamicDndPolicy
    sha256 = Sha256File $DynamicDndPolicy
  }
  ai_overlay = [ordered]@{
    path = $AiOverlay
    sha256 = Sha256File $AiOverlay
  }
}

$languageRules = [ordered]@{
  powershell = @(
    "Use Set-StrictMode -Version Latest and ErrorActionPreference Stop.",
    "Use deterministic write-to-disk scripts, not fragile interactive patching.",
    "Parse-gate every generated ps1 before execution.",
    "Do not use reserved variables like $PID as locals.",
    "Do not print success tokens unless parse and execution succeeded."
  )
  sql = @(
    "Schema and migration contract is authoritative.",
    "Do not invent tables, columns, RPCs, policies, or feature flags.",
    "RLS-aware changes require explicit policy reasoning.",
    "Migrations must be deterministic and auditable."
  )
  python = @(
    "Prefer typed, testable functions with explicit inputs and outputs.",
    "Do not introduce hidden network or filesystem side effects."
  )
  csharp = @(
    "Respect project structure and strong typing.",
    "Do not add runtime mutation without an explicit governed action."
  )
  go = @(
    "Prefer explicit error handling and deterministic output.",
    "Do not add undeclared external dependencies."
  )
  rust = @(
    "Prefer safe types and explicit error paths.",
    "Do not bypass compiler/lint feedback."
  )
  java = @(
    "Respect package structure and typed interfaces.",
    "Do not add undeclared framework assumptions."
  )
}

$contractCore = [ordered]@{
  schema = "covenantgate.repo_context_contract.v1"
  target_repo = $TargetRepo
  target_name = (Split-Path -Leaf $TargetRepo)
  assistant_role = "You are an AI assistant operating inside this repo. You must read and obey this Covenant Gate context contract before proposing, editing, executing, or explaining repo work."
  repo_bound = $true
  decision = "context_loaded"
  execution_rule = "No mutation or execution may occur unless a governed runner or execution gate allows it."
  hallucination_rule = "Do not invent files, schemas, tables, columns, policies, feature flags, or repo conventions not present in this context contract or target repo artifacts."
  languages = @($langList)
  language_rules = $languageRules
  rule_packs = $rulePacks
  schema_contract = [ordered]@{
    path = $schemaContractPath
    sha256 = $schemaContractHash
  }
  required_ai_adapter_behavior = @(
    "Adapter must require ContextContractPath.",
    "Adapter must refuse prompt processing if context contract is missing.",
    "Adapter must classify intent and risk before action.",
    "Adapter must run schema guard for SQL/RPC/action outputs when schema contract exists.",
    "Adapter must run dynamic DND before governed action.",
    "Adapter must emit receipts."
  )
}

$coreJson = ($contractCore | ConvertTo-Json -Depth 80 -Compress)
$contractHash = Sha256Text $coreJson

$contract = [ordered]@{
  schema = $contractCore.schema
  target_repo = $contractCore.target_repo
  target_name = $contractCore.target_name
  assistant_role = $contractCore.assistant_role
  repo_bound = $contractCore.repo_bound
  decision = $contractCore.decision
  execution_rule = $contractCore.execution_rule
  hallucination_rule = $contractCore.hallucination_rule
  languages = $contractCore.languages
  language_rules = $contractCore.language_rules
  rule_packs = $contractCore.rule_packs
  schema_contract = $contractCore.schema_contract
  required_ai_adapter_behavior = $contractCore.required_ai_adapter_behavior
  context_contract_hash = $contractHash
}

$outPath = Join-Path $OutDir ("cg_repo_context_contract_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($contract | ConvertTo-Json -Depth 80 -Compress))

Write-Host ("CG_REPO_CONTEXT_CONTRACT_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_REPO_CONTEXT_TARGET: " + $TargetRepo)
Write-Host ("CG_REPO_CONTEXT_LANGUAGES: " + (@($langList) -join ","))
Write-Host ("CG_REPO_CONTEXT_SCHEMA_CONTRACT: " + $schemaContractPath)
Write-Host ("CG_REPO_CONTEXT_HASH: " + $contractHash)
Write-Host "CG_REPO_CONTEXT_CONTRACT_OK" -ForegroundColor Green
