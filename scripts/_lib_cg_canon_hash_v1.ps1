Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function CG-CanonicalJsonV1 {
  param([Parameter(Mandatory=$true)]$Value)

  if($null -eq $Value){ return "null" }

  if($Value -is [string]){
    return ($Value | ConvertTo-Json -Compress)
  }

  if($Value -is [bool]){
    if($Value){ return "true" }
    return "false"
  }

  if($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]){
    return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0}", $Value))
  }

  if($Value -is [System.Collections.IDictionary]){
    $parts = New-Object System.Collections.Generic.List[string]
    foreach($k in @($Value.Keys | Sort-Object)){
      $keyJson = ([string]$k | ConvertTo-Json -Compress)
      $valJson = CG-CanonicalJsonV1 $Value[$k]
      $parts.Add($keyJson + ":" + $valJson) | Out-Null
    }
    return "{" + ((@($parts.ToArray())) -join ",") + "}"
  }

  if($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])){
    $items = New-Object System.Collections.Generic.List[string]
    foreach($i in @($Value)){
      $items.Add((CG-CanonicalJsonV1 $i)) | Out-Null
    }
    return "[" + ((@($items.ToArray())) -join ",") + "]"
  }

  $props = [ordered]@{}
  foreach($p in @($Value.PSObject.Properties | Sort-Object Name)){
    $props[$p.Name] = $p.Value
  }
  return CG-CanonicalJsonV1 $props
}

function CG-Sha256TextV1 {
  param([Parameter(Mandatory=$true)][string]$Text)
  $norm = ($Text -replace "`r`n","`n") -replace "`r","`n"
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($norm)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant() }
  finally { $sha.Dispose() }
}

function CG-HashObjectV1 {
  param([Parameter(Mandatory=$true)]$Value)
  return CG-Sha256TextV1 (CG-CanonicalJsonV1 $Value)
}
