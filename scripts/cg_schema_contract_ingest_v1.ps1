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
  $OutDir = Join-Path $RepoRoot "proofs\receipts\cg_schema_contract"
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

$sqlFiles = @(@(Get-ChildItem -LiteralPath $TargetRepo -Recurse -File -Include "*.sql" -ErrorAction SilentlyContinue) | Sort-Object FullName)

$tables = New-Object System.Collections.Generic.List[object]
$functions = New-Object System.Collections.Generic.List[object]
$rawSql = New-Object System.Collections.Generic.List[string]

foreach($f in @($sqlFiles)){
  $text = Get-Content -LiteralPath $f.FullName -Raw
  $rawSql.Add($text) | Out-Null

  foreach($m in [regex]::Matches($text, '(?is)\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?("?[\w]+"?\.)?"?([\w]+)"?\s*\((.*?)\);')){
    $schemaName = "public"
    $fullPrefix = [string]$m.Groups[1].Value
    if(-not [string]::IsNullOrWhiteSpace($fullPrefix)){
      $schemaName = $fullPrefix.Trim(".").Trim('"')
    }

    $tableName = ([string]$m.Groups[2].Value).Trim('"')
    $body = [string]$m.Groups[3].Value

    $cols = New-Object System.Collections.Generic.List[string]
    foreach($line in @($body -split "`n")){
      $l = $line.Trim()
      if([string]::IsNullOrWhiteSpace($l)){ continue }
      if($l -match '^(constraint|primary|foreign|unique|check)\b'){ continue }
      if($l -match '^"?([\w]+)"?\s+'){
        $cols.Add($Matches[1]) | Out-Null
      }
    }

    $tables.Add([ordered]@{
      schema = $schemaName
      table = $tableName
      columns = @(@($cols.ToArray()) | Sort-Object -Unique)
      source = $f.FullName.Substring($TargetRepo.Length).TrimStart("\").Replace("\","/")
    }) | Out-Null
  }

  foreach($m in [regex]::Matches($text, '(?is)\bcreate\s+(?:or\s+replace\s+)?function\s+("?[\w]+"?\.)?"?([\w]+)"?\s*\(')){
    $schemaName = "public"
    $fullPrefix = [string]$m.Groups[1].Value
    if(-not [string]::IsNullOrWhiteSpace($fullPrefix)){
      $schemaName = $fullPrefix.Trim(".").Trim('"')
    }
    $functions.Add([ordered]@{
      schema = $schemaName
      function = ([string]$m.Groups[2].Value).Trim('"')
      source = $f.FullName.Substring($TargetRepo.Length).TrimStart("\").Replace("\","/")
    }) | Out-Null
  }
}

$contractCore = [ordered]@{
  schema = "covenantgate.schema_contract.v1"
  target_repo = $TargetRepo
  sql_file_count = @($sqlFiles).Count
  tables = @(@($tables.ToArray()) | Sort-Object schema,table)
  functions = @(@($functions.ToArray()) | Sort-Object schema,function)
}

$contractJson = ($contractCore | ConvertTo-Json -Depth 80 -Compress)
$contractHash = Sha256Text $contractJson

$contract = [ordered]@{
  schema = $contractCore.schema
  target_repo = $contractCore.target_repo
  sql_file_count = $contractCore.sql_file_count
  tables = $contractCore.tables
  functions = $contractCore.functions
  contract_hash = $contractHash
}

$outPath = Join-Path $OutDir ("cg_schema_contract_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss_fffZ") + ".json")
Write-Utf8NoBomLf $outPath (($contract | ConvertTo-Json -Depth 80 -Compress))

Write-Host ("CG_SCHEMA_CONTRACT_OUTPUT: " + $outPath) -ForegroundColor Cyan
Write-Host ("CG_SCHEMA_CONTRACT_TABLES: " + @($tables.ToArray()).Count)
Write-Host ("CG_SCHEMA_CONTRACT_FUNCTIONS: " + @($functions.ToArray()).Count)
Write-Host ("CG_SCHEMA_CONTRACT_HASH: " + $contractHash)
Write-Host "CG_SCHEMA_CONTRACT_INGEST_OK" -ForegroundColor Green
