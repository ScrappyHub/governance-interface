Set-StrictMode -Version Latest

function CG-Die([string]$msg){ throw $msg }

function CG-ReadUtf8NoBom([string]$p){
  $b=[System.IO.File]::ReadAllBytes($p)
  if($b.Length -ge 3 -and $b[0]-eq 0xEF -and $b[1]-eq 0xBB -and $b[2]-eq 0xBF){ $b=$b[3..($b.Length-1)] }
  $u=New-Object System.Text.UTF8Encoding($false,$true)
  $u.GetString($b)
}

function CG-Sha256HexBytes([byte[]]$bytes){
  if($null -eq $bytes){ $bytes = @() }
  $sha=[System.Security.Cryptography.SHA256]::Create()
  try{ $h=$sha.ComputeHash($bytes) } finally { $sha.Dispose() }
  $sb=New-Object System.Text.StringBuilder
  for($i=0;$i -lt $h.Length;$i++){ [void]$sb.Append($h[$i].ToString("x2")) }
  $sb.ToString()
}

function CG-ToCanonJsonValue($v){
  if($null -eq $v){ return $null }
  if($v -is [System.Collections.IDictionary]){
    $keys = @(@($v.Keys | ForEach-Object { [string]$_ }) | Sort-Object)
    $h = New-Object System.Collections.Specialized.OrderedDictionary
    foreach($k in $keys){ $h[$k] = CG-ToCanonJsonValue $v[$k] }
    return $h
  }
  if($v -is [pscustomobject]){
    $props = @(@($v.PSObject.Properties | Select-Object -ExpandProperty Name) | Sort-Object)
    $h = New-Object System.Collections.Specialized.OrderedDictionary
    foreach($k in $props){ $h[$k] = CG-ToCanonJsonValue ($v.$k) }
    return $h
  }
  if($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])){
    $arr = @()
    foreach($x in $v){ $arr += ,(CG-ToCanonJsonValue $x) }
    return ,$arr
  }
  return $v
}

function CG-ToCanonJson([Parameter(Mandatory=$true)]$obj){
  $norm = CG-ToCanonJsonValue $obj
  $j = ($norm | ConvertTo-Json -Depth 40 -Compress)
  (($j -replace "`r`n","`n") -replace "`r","`n")
}

function CG-CanonBytes([Parameter(Mandatory=$true)]$obj){
  $j = CG-ToCanonJson $obj
  $u = New-Object System.Text.UTF8Encoding($false)
  $u.GetBytes($j + "`n")
}

function CG-JsonPointerGet($root,[string]$ptr,[ref]$found){
  $found.Value = $false
  if($ptr -eq "" -or $ptr -eq "/"){ $found.Value = $true; return $root }
  if(-not $ptr.StartsWith("/")){ return $null }
  $parts = $ptr.Substring(1).Split("/")
  $cur = $root
  foreach($raw in $parts){
    $p = $raw.Replace("~1","/").Replace("~0","~")
    if($null -eq $cur){ return $null }
    if($cur -is [System.Collections.IDictionary]){ if($cur.Contains($p)){ $cur = $cur[$p]; continue } ; return $null }
    if($cur -is [pscustomobject]){ if(@(@($cur.PSObject.Properties.Match($p))).Count -gt 0){ $cur = $cur.$p; continue } ; return $null }
    if(($cur -is [System.Collections.IEnumerable]) -and -not ($cur -is [string])){
      $idx = -1; if(-not [int]::TryParse($p,[ref]$idx)){ return $null }
      $arr = @($cur); if($idx -lt 0 -or $idx -ge $arr.Count){ return $null }
      $cur = $arr[$idx]; continue
    }
    return $null
  }
  $found.Value = $true
  $cur
}

function CG-CondValidate($c){
  if($null -eq $c){ return $false }
  if($c -isnot [pscustomobject] -and $c -isnot [System.Collections.IDictionary]){ return $false }
  $hasAll=$false; $hasAny=$false; $hasNot=$false; $hasOp=$false
  if(@(@($c.PSObject.Properties.Match("all"))).Count -gt 0){ $hasAll=$true }
  if(@(@($c.PSObject.Properties.Match("any"))).Count -gt 0){ $hasAny=$true }
  if(@(@($c.PSObject.Properties.Match("not"))).Count -gt 0){ $hasNot=$true }
  if(@(@($c.PSObject.Properties.Match("op"))).Count -gt 0){ $hasOp=$true }
  $forms = @($hasAll,$hasAny,$hasNot,$hasOp) | Where-Object { $_ }
  if(@(@($forms)).Count -ne 1){ return $false }
  if($hasAll){ $arr=@($c.all); if(@(@($arr)).Count -lt 1){ return $false }; foreach($x in $arr){ if(-not (CG-CondValidate $x)){ return $false } }; return $true }
  if($hasAny){ $arr=@($c.any); if(@(@($arr)).Count -lt 1){ return $false }; foreach($x in $arr){ if(-not (CG-CondValidate $x)){ return $false } }; return $true }
  if($hasNot){ return (CG-CondValidate $c.not) }
  $op=[string]$c.op; $path=[string]$c.path
  if([string]::IsNullOrWhiteSpace($op) -or [string]::IsNullOrWhiteSpace($path)){ return $false }
  $allowed=@("exists","eq","in","starts_with","contains","lt","lte","gt","gte")
  if($allowed -notcontains $op){ return $false }
  if(-not ($path -match "^(/([^~/]|~0|~1)*)*$")){ return $false }
  if($op -eq "in"){ if(@(@($c.PSObject.Properties.Match("values"))).Count -le 0){ return $false }; $vals=@($c.values); if(@(@($vals)).Count -lt 1){ return $false } }
  if(@("eq","starts_with","contains","lt","lte","gt","gte") -contains $op){ if(@(@($c.PSObject.Properties.Match("value"))).Count -le 0){ return $false } }
  return $true
}

function CG-CondEval($input,$cond){
  if(-not (CG-CondValidate $cond)){ return $false }
  if(@(@($cond.PSObject.Properties.Match("all"))).Count -gt 0){ foreach($x in @($cond.all)){ if(-not (CG-CondEval $input $x)){ return $false } }; return $true }
  if(@(@($cond.PSObject.Properties.Match("any"))).Count -gt 0){ foreach($x in @($cond.any)){ if(CG-CondEval $input $x){ return $true } }; return $false }
  if(@(@($cond.PSObject.Properties.Match("not"))).Count -gt 0){ return (-not (CG-CondEval $input $cond.not)) }
  $op=[string]$cond.op; $path=[string]$cond.path; $found=$false
  $v = CG-JsonPointerGet $input $path ([ref]$found)
  if($op -eq "exists"){ return $found }
  if(-not $found){ return $false }
  if($op -eq "eq"){
    $canonA = CG-ToCanonJsonValue $v; $canonB = CG-ToCanonJsonValue $cond.value
    return ((CG-ToCanonJson $canonA) -eq (CG-ToCanonJson $canonB))
  }
  if($op -eq "in"){
    foreach($x in @($cond.values)){
      $canonA = CG-ToCanonJsonValue $v; $canonB = CG-ToCanonJsonValue $x
      if((CG-ToCanonJson $canonA) -eq (CG-ToCanonJson $canonB)){ return $true }
    }
    return $false
  }
  if($op -eq "starts_with"){ if($v -isnot [string]){ return $false }; return $v.StartsWith([string]$cond.value) }
  if($op -eq "contains"){
    if(($v -is [string]) -or -not ($v -is [System.Collections.IEnumerable])){ return $false }
    foreach($x in @($v)){
      $canonA = CG-ToCanonJsonValue $x; $canonB = CG-ToCanonJsonValue $cond.value
      if((CG-ToCanonJson $canonA) -eq (CG-ToCanonJson $canonB)){ return $true }
    }
    return $false
  }
  if(($v -isnot [double]) -and ($v -isnot [int]) -and ($v -isnot [long]) -and ($v -isnot [decimal])){ return $false }
  $a=[double]$v; $bRaw=$cond.value
  if(($bRaw -isnot [double]) -and ($bRaw -isnot [int]) -and ($bRaw -isnot [long]) -and ($bRaw -isnot [decimal])){ return $false }
  $b=[double]$bRaw
  switch($op){ "lt" {return ($a -lt $b)} "lte" {return ($a -le $b)} "gt" {return ($a -gt $b)} "gte" {return ($a -ge $b)} }
  return $false
}

# ---- Eval Engine V1 (validators + derive + eval) ----

function CG-ValidateEvalInputV1($inp,[ref]$err){
  $err.Value=$null
  try{
    if($null -eq $inp){ throw "INPUT_NULL" }
    if([string]$inp.schema -ne "covenantgate.eval_input.v1"){ throw "INPUT_SCHEMA_TAG_INVALID" }
    $ep=[string]$inp.enforcement_point
    $allowed=@("ingest.packet","policy.update.overlay","eval.request")
    if($allowed -notcontains $ep){ throw "INPUT_ENFORCEMENT_POINT_INVALID" }
    if($null -eq $inp.subject -or [string]$inp.subject.type -eq ""){ throw "INPUT_SUBJECT_INVALID" }
    if($null -eq $inp.action  -or [string]$inp.action.type  -eq ""){ throw "INPUT_ACTION_INVALID" }
    return $true
  } catch { $err.Value=[string]$_.Exception.Message; return $false }
}

function CG-ValidateRuleCommon($r,[ref]$err){
  $err.Value=$null
  try{
    $id=[string]$r.id
    if([string]::IsNullOrWhiteSpace($id) -or -not ($id -match "^[a-z0-9][a-z0-9_.:-]{2,80}$")){ throw "RULE_ID_INVALID" }
    $eps=@($r.enforcement_points); if(@(@($eps)).Count -lt 1){ throw "RULE_ENFORCEMENT_POINTS_EMPTY" }
    $allowed=@("ingest.packet","policy.update.overlay","eval.request")
    foreach($e in $eps){ if($allowed -notcontains ([string]$e)){ throw "RULE_ENFORCEMENT_POINT_INVALID" } }
    if(-not (CG-CondValidate $r.when)){ throw "RULE_WHEN_INVALID" }
    return $true
  } catch { $err.Value=[string]$_.Exception.Message; return $false }
}

function CG-ValidatePolicyBaseV1($pol,[ref]$err){
  $err.Value=$null
  try{
    if($null -eq $pol){ throw "POLICY_NULL" }
    if([string]$pol.schema -ne "covenantgate.policy.base.v1"){ throw "POLICY_SCHEMA_TAG_INVALID" }
    if([int]$pol.version -ne 1){ throw "POLICY_VERSION_INVALID" }
    if($null -eq $pol.defaults){ throw "POLICY_DEFAULTS_MISSING" }
    if([string]$pol.defaults.default_decision -ne "deny"){ throw "POLICY_DEFAULT_DECISION_INVALID" }
    foreach($r in @($pol.allow_rules)){
      if([string]$r.effect -ne "allow"){ throw "ALLOW_RULE_EFFECT_INVALID" }
      $e=$null; if(-not (CG-ValidateRuleCommon $r ([ref]$e))){ throw ("ALLOW_RULE_INVALID:"+$e) }
    }
    foreach($r in @($pol.deny_rules)){
      if([string]$r.effect -ne "deny"){ throw "DENY_RULE_EFFECT_INVALID" }
      $e=$null; if(-not (CG-ValidateRuleCommon $r ([ref]$e))){ throw ("DENY_RULE_INVALID:"+$e) }
    }
    return $true
  } catch { $err.Value=[string]$_.Exception.Message; return $false }
}

function CG-ValidateOverlayV1($ov,[ref]$err){
  $err.Value=$null
  try{
    if($null -eq $ov){ return $true }
    if([string]$ov.schema -ne "covenantgate.policy.overlay.v1"){ throw "OVERLAY_SCHEMA_TAG_INVALID" }
    if([int]$ov.version -ne 1){ throw "OVERLAY_VERSION_INVALID" }
    if($ov.tighten_only -ne $true){ throw "OVERLAY_WIDEN_FORBIDDEN" }
    foreach($r in @($ov.deny_rules)){
      if([string]$r.effect -ne "deny"){ throw "OVERLAY_DENY_RULE_EFFECT_INVALID" }
      $e=$null; if(-not (CG-ValidateRuleCommon $r ([ref]$e))){ throw ("OVERLAY_DENY_RULE_INVALID:"+$e) }
    }
    foreach($c in @($ov.allow_constraints)){ if(-not (CG-CondValidate $c)){ throw "OVERLAY_ALLOW_CONSTRAINT_INVALID" } }
    return $true
  } catch { $err.Value=[string]$_.Exception.Message; return $false }
}

function CG-DeriveEffectivePolicyV1($base,$overlay){
  $allow=@($base.allow_rules); $deny=@($base.deny_rules)
  if($null -ne $overlay){ $deny=@(@($deny)+@($overlay.deny_rules)) }
  $allow2=@(@($allow) | Sort-Object { [string]$_.id })
  $deny2 =@(@($deny)  | Sort-Object { [string]$_.id })
  $acs=@(); if($null -ne $overlay){ $acs=@(@($overlay.allow_constraints)) }
  [pscustomobject]@{ schema="covenantgate.policy.effective.v1"; version=1; defaults=$base.defaults; allow_constraints=$acs; allow_rules=$allow2; deny_rules=$deny2 }
}

function CG-EvalV1($basePolicy,$overlayPolicy,$evalInput){
  $engine="covenantgate.eval.v1"
  $e=$null; if(-not (CG-ValidateEvalInputV1 $evalInput ([ref]$e))){
    $ih=CG-Sha256HexBytes (CG-CanonBytes $evalInput)
    $u=New-Object System.Text.UTF8Encoding($false)
    $eid=CG-Sha256HexBytes ($u.GetBytes((("0")*64)+"`n"+$ih+"`n"+$engine))
    return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="deny"; reason_codes=@("INPUT_SCHEMA_INVALID"); policy_hash=(("0")*64); input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@();deny=@()} }
  }
  $pe=$null; if(-not (CG-ValidatePolicyBaseV1 $basePolicy ([ref]$pe))){
    $ih=CG-Sha256HexBytes (CG-CanonBytes $evalInput)
    $u=New-Object System.Text.UTF8Encoding($false)
    $eid=CG-Sha256HexBytes ($u.GetBytes((("0")*64)+"`n"+$ih+"`n"+$engine))
    return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="deny"; reason_codes=@("POLICY_SCHEMA_INVALID"); policy_hash=(("0")*64); input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@();deny=@()} }
  }
  $oe=$null; if(-not (CG-ValidateOverlayV1 $overlayPolicy ([ref]$oe))){
    $ih=CG-Sha256HexBytes (CG-CanonBytes $evalInput)
    $u=New-Object System.Text.UTF8Encoding($false)
    $eid=CG-Sha256HexBytes ($u.GetBytes((("0")*64)+"`n"+$ih+"`n"+$engine))
    $code=$oe; if([string]::IsNullOrWhiteSpace($code)){ $code="OVERLAY_SCHEMA_INVALID" }
    return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="deny"; reason_codes=@($code); policy_hash=(("0")*64); input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@();deny=@()} }
  }
  $eff=CG-DeriveEffectivePolicyV1 $basePolicy $overlayPolicy
  $ph=CG-Sha256HexBytes (CG-CanonBytes $eff)
  $ih=CG-Sha256HexBytes (CG-CanonBytes $evalInput)
  $u=New-Object System.Text.UTF8Encoding($false)
  $eid=CG-Sha256HexBytes ($u.GetBytes($ph+"`n"+$ih+"`n"+$engine))
  $ep=[string]$evalInput.enforcement_point
  $allowRules=@(@($eff.allow_rules) | Where-Object { @($_.enforcement_points) -contains $ep } | Sort-Object { [string]$_.id })
  $denyRules =@(@($eff.deny_rules)  | Where-Object { @($_.enforcement_points) -contains $ep } | Sort-Object { [string]$_.id })
  $constraints=@(@($eff.allow_constraints))
  $matchedDeny=@(); foreach($r in $denyRules){ if(CG-CondEval $evalInput $r.when){ $matchedDeny += ,([string]$r.id) } }
  if(@(@($matchedDeny)).Count -gt 0){
    $md=@(@($matchedDeny)|Sort-Object); $reasons=@()
    foreach($id in $md){
      $reasons += ,("DENY_RULE_MATCH:"+$id)
      $rr = $denyRules | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
      if($rr -and @(@($rr.PSObject.Properties.Match("reason_codes"))).Count -gt 0){ foreach($rc in @(@($rr.reason_codes)|Sort-Object)){ $reasons += ,([string]$rc) } }
    }
    return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="deny"; reason_codes=@($reasons); policy_hash=$ph; input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@();deny=@($md)} }
  }
  $matchedAllow=@(); foreach($r in $allowRules){
    $ok=$true; foreach($c in $constraints){ if(-not (CG-CondEval $evalInput $c)){ $ok=$false; break } }
    if(-not $ok){ continue }
    if(CG-CondEval $evalInput $r.when){ $matchedAllow += ,([string]$r.id) }
  }
  if(@(@($matchedAllow)).Count -gt 0){
    $ma=@(@($matchedAllow)|Sort-Object); $reasons=@()
    foreach($id in $ma){
      $reasons += ,("ALLOW_RULE_MATCH:"+$id)
      $rr = $allowRules | Where-Object { [string]$_.id -eq $id } | Select-Object -First 1
      if($rr -and @(@($rr.PSObject.Properties.Match("reason_codes"))).Count -gt 0){ foreach($rc in @(@($rr.reason_codes)|Sort-Object)){ $reasons += ,([string]$rc) } }
    }
    return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="allow"; reason_codes=@($reasons); policy_hash=$ph; input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@($ma);deny=@()} }
  }
  return [pscustomobject]@{ schema="covenantgate.eval_output.v1"; decision="deny"; reason_codes=@("DEFAULT_DENY"); policy_hash=$ph; input_hash=$ih; engine_version=$engine; evaluation_id=$eid; matched_rules=@{allow=@();deny=@()} }
}

# --- BEGIN_OVERRIDE_CG_VALIDATEPOLICYBASEV1_ARRAY_MAT_V3 ---
function CG-ValidatePolicyBaseV1([object]$Policy,[ref]$Err){
  $Err.Value = $null
  try {
    if($null -eq $Policy){ $Err.Value = "POLICY_NULL"; return $false }
    if(@(@($Policy.PSObject.Properties.Match("schema"))).Count -lt 1){ $Err.Value = "POLICY_SCHEMA_MISSING"; return $false }
    if([string]$Policy.schema -ne "covenantgate.policy.base.v1"){ $Err.Value = "POLICY_SCHEMA_UNSUPPORTED:" + [string]$Policy.schema; return $false }
    if(@(@($Policy.PSObject.Properties.Match("version"))).Count -lt 1){ $Err.Value = "POLICY_VERSION_MISSING"; return $false }
    if([int]$Policy.version -ne 1){ $Err.Value = "POLICY_VERSION_UNSUPPORTED:" + [string]$Policy.version; return $false }
    if(@(@($Policy.PSObject.Properties.Match("defaults"))).Count -lt 1 -or $null -eq $Policy.defaults){ $Err.Value = "DEFAULTS_MISSING"; return $false }
    if(@(@($Policy.defaults.PSObject.Properties.Match("default_decision"))).Count -lt 1){ $Err.Value = "DEFAULT_DECISION_MISSING"; return $false }
    $dd = [string]$Policy.defaults.default_decision
    if($dd -ne "allow" -and $dd -ne "deny"){ $Err.Value = "DEFAULT_DECISION_INVALID:" + $dd; return $false }

    $allow = @(@($Policy.allow_rules))
    $deny  = @(@($Policy.deny_rules))

    function _ValidateRule([object]$r,[string]$kind,[ref]$E){
      if($null -eq $r){ $E.Value = ($kind + "_RULE_NULL"); return $false }
      if(@(@($r.PSObject.Properties.Match("id"))).Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$r.id)){ $E.Value = ($kind + "_RULE_ID_MISSING"); return $false }
      if(@(@($r.PSObject.Properties.Match("effect"))).Count -lt 1){ $E.Value = ($kind + "_RULE_EFFECT_MISSING:" + [string]$r.id); return $false }
      $eff = [string]$r.effect
      if($eff -ne "allow" -and $eff -ne "deny"){ $E.Value = ($kind + "_RULE_EFFECT_INVALID:" + [string]$r.id + ":" + $eff); return $false }
      $eps = @(@($r.enforcement_points))
      if(@(@($eps)).Count -lt 1){ $E.Value = ($kind + "_RULE_EP_EMPTY:" + [string]$r.id); return $false }
      foreach($ep in $eps){ if([string]::IsNullOrWhiteSpace([string]$ep)){ $E.Value = ($kind + "_RULE_EP_INVALID:" + [string]$r.id); return $false } }
      if(@(@($r.PSObject.Properties.Match("when"))).Count -lt 1 -or $null -eq $r.when){ $E.Value = ($kind + "_RULE_WHEN_MISSING:" + [string]$r.id); return $false }
      if(@(@($r.when.PSObject.Properties.Match("op"))).Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$r.when.op)){ $E.Value = ($kind + "_RULE_WHEN_OP_MISSING:" + [string]$r.id); return $false }
      $rcs = @(@($r.reason_codes))
      if(@(@($rcs)).Count -lt 1){ $E.Value = ($kind + "_RULE_REASON_CODES_EMPTY:" + [string]$r.id); return $false }
      foreach($rc in $rcs){ if([string]::IsNullOrWhiteSpace([string]$rc)){ $E.Value = ($kind + "_RULE_REASON_CODE_INVALID:" + [string]$r.id); return $false } }
      return $true
    }

    foreach($r in $allow){ if($null -eq $r){ continue }; $e2=$null; if(-not (_ValidateRule $r "ALLOW" ([ref]$e2))){ $Err.Value = ("ALLOW_RULE_INVALID:" + $e2); return $false }; if([string]$r.effect -ne "allow"){ $Err.Value = ("ALLOW_RULE_EFFECT_MISMATCH:" + [string]$r.id); return $false } }
    foreach($r in $deny ){ if($null -eq $r){ continue }; $e3=$null; if(-not (_ValidateRule $r "DENY"  ([ref]$e3))){ $Err.Value = ("DENY_RULE_INVALID:"  + $e3); return $false }; if([string]$r.effect -ne "deny" ){ $Err.Value = ("DENY_RULE_EFFECT_MISMATCH:"  + [string]$r.id); return $false } }
    return $true
  } catch { $Err.Value = "POLICY_VALIDATE_EXCEPTION:" + $_.Exception.Message; return $false }
}
# --- END_OVERRIDE_CG_VALIDATEPOLICYBASEV1_ARRAY_MAT_V3 ---



