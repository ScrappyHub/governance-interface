param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$ContractPath,
  [Parameter(Mandatory=$true)][string]$AiOutputText,
  [string]$OutDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$ContractPath = (Resolve-Path $ContractPath).Path
if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_ai_schema_guard"
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
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

Ensure-Dir $OutDir

$contract = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json -ErrorAction Stop

$tableSet = @{}
$columnSet = @{}

foreach($t in @($contract.tables)){
  $full = (([string]$t.schema) + "." + ([string]$t.table)).ToLowerInvariant()
  $bare = ([string]$t.table).ToLowerInvariant()
  $tableSet[$full] = $true
  $tableSet[$bare] = $true

  foreach($c in @($t.columns)){
    $columnSet[($bare + "." + ([string]$c).ToLowerInvariant())] = $true
    $columnSet[($full + "." + ([string]$c).ToLowerInvariant())] = $true
  }
}

$unknownTables = New-Object System.Collections.Generic.List[string]
$unknownColumns = New-Object System.Collections.Generic.List[string]

$text = $AiOutputText

foreach($m in [regex]::Matches($text, '(?i)\b(from|join|update|into)\s+("?[\w]+"?(?:\."?[\w]+"?)?)')){
  $name = ([string]$m.Groups[2].Value).Replace('"','').ToLowerInvariant()
  if(-not $tableSet.ContainsKey($name)){
    $unknownTables.Add($name) | Out-Null
  }
}

foreach($m in [regex]::Matches($text, '(?i)\b([\w]+)\.([\w]+)\b')){
  $pair = (([string]$m.Groups[1].Value) + "." + ([string]$m.Groups[2].Value)).ToLowerInvariant()
  if($tableSet.ContainsKey(([string]$m.Groups[1].Value).ToLowerInvariant())){
    if(-not $columnSet.ContainsKey($pair)){
      $unknownColumns.Add($pair) | Out-Null
    }
  }
}

$decision = "allow"
$reasons = New-Object System.Collections.Generic.List[string]

if(@($unknownTables.ToArray()).Count -gt 0){
  $decision = "deny"
  $reasons.Add("UNKNOWN_TABLE") | Out-Null
}
if(@($unknownColumns.ToArray()).Count -gt 0){
  $decision = "deny"
  $reasons.Add("UNKNOWN_COLUMN") | Out-Null
}

$result = [ordered]@{
  schema = "covenantgate.ai_schema_guard.v1"
  contract_path = $ContractPath
  contract_hash = [string]$contract.contract_hash
  ai_output_sha256 = Sha256Text $AiOutputText
  decision = $decision
  reason_codes = @(@($reasons.ToArray()) | Sort-Object -Unique)
  unknown_tables = @(@($unknownTables.ToArray()) | Sort-Object -Unique)
  unknown_columns = @(@($unknownColumns.ToArray()) | Sort-Object -Unique)
}

$outPath = Join-Path $OutDir ("cg_ai_schema_guard_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($result | ConvertTo-Json -Depth 50 -Compress))

Write-Host ("CG_AI_SCHEMA_GUARD_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_AI_SCHEMA_GUARD_DECISION: " + $decision)
Write-Host ("CG_AI_SCHEMA_GUARD_REASON_CODES: " + ((@($reasons.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_AI_SCHEMA_GUARD_UNKNOWN_TABLES: " + ((@($unknownTables.ToArray()) | Sort-Object -Unique) -join ","))
Write-Host ("CG_AI_SCHEMA_GUARD_UNKNOWN_COLUMNS: " + ((@($unknownColumns.ToArray()) | Sort-Object -Unique) -join ","))

if($decision -eq "deny"){
  Write-Host "CG_AI_SCHEMA_GUARD_DENY" -ForegroundColor Yellow
  exit 2
}

Write-Host "CG_AI_SCHEMA_GUARD_OK" -ForegroundColor Green
exit 0
