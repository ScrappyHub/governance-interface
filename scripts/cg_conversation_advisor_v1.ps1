param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$EvalInputPath,
  [Parameter(Mandatory=$true)][string]$PolicyBasePath,
  [string]$PolicyOverlayPath = "",
  [switch]$InjectBad,
  [ValidateSet("timestamp","guid","unordered")][string]$BadMode = "timestamp"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ReadText([string]$p){
  if(-not (Test-Path -LiteralPath $p -PathType Leaf)){ throw ("MISSING: " + $p) }
  [System.IO.File]::ReadAllText($p,(New-Object System.Text.UTF8Encoding($false)))
}
function CanonLf([string]$s){ (($s -replace "`r`n","`n") -replace "`r","`n") }
function Sha256HexText([string]$s){
  $b = [System.Text.Encoding]::UTF8.GetBytes((CanonLf $s))
  (Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new($b))).Hash.ToLowerInvariant()
}

$engineVersion = "cg_conversation_advisor_v1"
$inRaw   = ReadText $EvalInputPath
$baseRaw = ReadText $PolicyBasePath
$ovRaw   = ""
if(-not [string]::IsNullOrWhiteSpace($PolicyOverlayPath)){ $ovRaw = ReadText $PolicyOverlayPath }

$input_hash = Sha256HexText $inRaw
$base_hash  = Sha256HexText $baseRaw
$ov_hash    = ""
if(-not [string]::IsNullOrWhiteSpace($ovRaw)){ $ov_hash = Sha256HexText $ovRaw }

$suggestions = @()
$suggestions += ([ordered]@{ kind="note"; code="ADVISORY_NON_AUTHORITATIVE"; message="Suggestions are non-authoritative. Deterministic engine output remains source of truth." })

if($InjectBad){
  if($BadMode -eq "timestamp"){
    $suggestions += ([ordered]@{ kind="debug"; code="INJECT_NONDETERMINISM"; message=("utc=" + ([DateTime]::UtcNow.ToString("o"))) })
  } elseif($BadMode -eq "guid"){
    $suggestions += ([ordered]@{ kind="debug"; code="INJECT_NONDETERMINISM"; message=("guid=" + ([Guid]::NewGuid().ToString())) })
  } else {
    # unordered hashtable (not stable) + changing value for guaranteed mismatch
    $h = @{}
    $h["b"] = "2"
    $h["a"] = ([Guid]::NewGuid().ToString())
    $h["c"] = "3"
    $suggestions += $h
  }
}

$out = [ordered]@{
  schema="covenantgate.advisory.suggestions.v1"
  version=1
  engine_version=$engineVersion
  input_hash=$input_hash
  policy_base_hash=$base_hash
  policy_overlay_hash=$ov_hash
  suggestions=$suggestions
}
($out | ConvertTo-Json -Compress -Depth 20)
