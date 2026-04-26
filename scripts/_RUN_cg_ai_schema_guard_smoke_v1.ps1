param([Parameter(Mandatory=$true)][string]$RepoRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$TargetRepo = "C:\dev\shutterwall"

$Ingest = Join-Path $RepoRoot "scripts\cg_schema_contract_ingest_v1.ps1"
$Guard  = Join-Path $RepoRoot "scripts\cg_ai_schema_guard_v1.ps1"
$TmpDir = Join-Path $RepoRoot "proofs\_tmp\schema_guard_smoke"

function Ensure-Dir([string]$p){
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

Ensure-Dir $TmpDir

# Synthetic migration added to temp repo copy for deterministic positive/negative guard proof.
$Fixture = Join-Path $TmpDir "fixture_repo"
if(Test-Path -LiteralPath $Fixture){ Remove-Item -LiteralPath $Fixture -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $Fixture "supabase\migrations") | Out-Null

Write-Utf8NoBomLf (Join-Path $Fixture "supabase\migrations\0001_schema.sql") @"
create table if not exists pods_core.memberships (
  id uuid primary key,
  user_id uuid not null,
  role text not null
);

create table if not exists pods_ops.appointments (
  id uuid primary key,
  membership_id uuid not null,
  starts_at timestamptz not null
);

create or replace function pods_public.create_booking()
returns void
language sql
as `$`$ select 1; `$`$;
"@

$PSExe = (Get-Command powershell.exe -ErrorAction Stop).Source

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Ingest `
  -RepoRoot $RepoRoot `
  -TargetRepo $Fixture `
  -OutDir $TmpDir | Out-Host

if($LASTEXITCODE -ne 0){ throw ("INGEST_FAILED: " + $LASTEXITCODE) }

$Contract = @(Get-ChildItem -LiteralPath $TmpDir -Filter "cg_schema_contract_*.json" -File | Sort-Object Name | Select-Object -Last 1)[0].FullName

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Guard `
  -RepoRoot $RepoRoot `
  -ContractPath $Contract `
  -AiOutputText "select memberships.id, memberships.role from memberships join appointments on appointments.membership_id = memberships.id;" | Out-Host

if($LASTEXITCODE -ne 0){ throw ("VALID_QUERY_DENIED: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Guard `
  -RepoRoot $RepoRoot `
  -ContractPath $Contract `
  -AiOutputText "select users.password_hash from users;" | Out-Host

if($LASTEXITCODE -ne 2){ throw ("UNKNOWN_TABLE_EXPECTED_DENY_GOT: " + $LASTEXITCODE) }

& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File $Guard `
  -RepoRoot $RepoRoot `
  -ContractPath $Contract `
  -AiOutputText "select memberships.fake_column from memberships;" | Out-Host

if($LASTEXITCODE -ne 2){ throw ("UNKNOWN_COLUMN_EXPECTED_DENY_GOT: " + $LASTEXITCODE) }

Write-Host "CG_AI_SCHEMA_GUARD_SMOKE_OK" -ForegroundColor Green
