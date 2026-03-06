param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ Die "ENSURE_DIR_EMPTY" }; if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function Read-Utf8NoBom([string]$p){
  $b=[System.IO.File]::ReadAllBytes($p)
  if($b.Length -ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){ $b=$b[3..($b.Length-1)] }
  $u=New-Object System.Text.UTF8Encoding($false,$true)
  $u.GetString($b)
}
function Write-Utf8NoBomLf([string]$p,[string]$txt){
  $enc=New-Object System.Text.UTF8Encoding($false)
  $t=$txt
  $t=$t.Replace("`r`n","`n").Replace("`r","`n")
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $d=Split-Path -Parent $p
  if($d){ Ensure-Dir $d }
  [System.IO.File]::WriteAllText($p,$t,$enc)
}

if(-not (Test-Path -LiteralPath $RepoRoot -PathType Container)){ Die ("REPO_ROOT_MISSING: " + $RepoRoot) }
$Trust = Join-Path (Join-Path $RepoRoot "proofs") "trust"
Ensure-Dir $Trust
$Bundle = Join-Path $Trust "trust_bundle.json"
$Out    = Join-Path $Trust "allowed_signers"
if(-not (Test-Path -LiteralPath $Bundle -PathType Leaf)){ Die ("MISSING_TRUST_BUNDLE: " + $Bundle) }
$obj = (Read-Utf8NoBom $Bundle | ConvertFrom-Json -ErrorAction Stop)
if([string]$obj.schema -ne "covenantgate.trust_bundle.v1"){ Die ("TRUST_BUNDLE_SCHEMA_INVALID: " + [string]$obj.schema) }
$rows = New-Object System.Collections.Generic.List[string]
foreach($s in @(@($obj.signers))){
  if($null -eq $s){ continue }
  $p=[string]$s.principal; $k=[string]$s.pubkey
  if([string]::IsNullOrWhiteSpace($p) -or [string]::IsNullOrWhiteSpace($k)){ continue }
  $nss = @(@($s.allowed_namespaces) | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object)
  if(@(@($nss)).Count -lt 1){ Die ("TRUST_SIGNER_MISSING_NAMESPACES: " + $p) }
  $opt = 'namespaces="' + ($nss -join ',') + '"'
  [void]$rows.Add(($p + " " + $opt + " " + $k))
}
$rows2 = @(@($rows.ToArray()) | Sort-Object)
Write-Utf8NoBomLf $Out (($rows2 -join "`n") + "`n")
Write-Host ("ALLOWED_SIGNERS_WROTE: " + $Out) -ForegroundColor Green
