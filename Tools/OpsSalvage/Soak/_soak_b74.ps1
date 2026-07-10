$ErrorActionPreference='Continue'
$rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
if(-not [IO.File]::Exists($rpt)){ Write-Host 'RPT MISSING'; exit }
$fi=Get-Item -LiteralPath $rpt
Write-Host ("=== b74 SOAK  rpt="+[math]::Round($fi.Length/1MB,2)+"MB  age="+[math]::Round(((Get-Date)-$fi.LastWriteTime).TotalMinutes,1)+"min ===")
$mi=Select-String -LiteralPath $rpt -Pattern 'MISSINIT' | Select-Object -Last 1
if($mi){ Write-Host ('mission: '+(($mi.Line -replace '.*missionName=','') -replace ',.*','')) }

Write-Host "`n-- ERRORS (rollback gate) --"
$err=@(Select-String -LiteralPath $rpt -Pattern 'Error in expression')
Write-Host ('  ErrInExpr TOTAL: '+$err.Count)
$err | ForEach-Object { $x=($_.Line -replace 'Error in expression <','').Trim(); $x.Substring(0,[math]::Min(55,$x.Length)) } | Group-Object | Sort-Object Count -Descending | Select-Object -First 6 | ForEach-Object { Write-Host ('    '+$_.Count+'x  '+$_.Name) }

Write-Host "`n-- ECONOMY (funds: draining vs hoarding?) --"
foreach($s in @('WEST','EAST')){ $e=@(Select-String -LiteralPath $rpt -Pattern 'ECONOMY\|funds' | Where-Object { $_.Line -match "\|$s\|" }); if($e.Count -gt 0){ $f=($e[0].Line -split 'ECONOMY\|')[-1]; $l=($e[-1].Line -split 'ECONOMY\|')[-1]; Write-Host ("  $s  first: "+$f.Substring(0,[math]::Min(55,$f.Length))); Write-Host ("  $s  last : "+$l.Substring(0,[math]::Min(55,$l.Length))) } else { Write-Host "  $s (no ECONOMY lines yet)" } }

Write-Host "`n-- FOUNDING (cost = are expensive units fielded?) --"
$fnd=@(Select-String -LiteralPath $rpt -Pattern 'team founding dispatched')
Write-Host ('  founding events: '+$fnd.Count)
$costs=@(); $fnd | ForEach-Object { if($_.Line -match 'cost (\d+)'){ $costs += [int]$matches[1] } }
if($costs.Count -gt 0){ $s2=$costs | Sort-Object; Write-Host ('  team cost  min='+$s2[0]+'  max='+$s2[-1]+'  avg='+[int](($costs|Measure-Object -Average).Average)+'  (n='+$costs.Count+')') }
$fnd | Select-Object -Last 4 | ForEach-Object { if($_.Line -match 'template (\d+), cost (\d+), doctrine (\w+)'){ Write-Host ('     tmpl='+$matches[1]+' cost='+$matches[2]+' doc='+$matches[3]) } }

Write-Host "`n-- VETERAN / cost-weight (rich->premium) --"
Write-Host ('  Veteran founding armed: '+@(Select-String -LiteralPath $rpt -Pattern 'Veteran founding armed').Count)
Write-Host ('  VeteranCompany applied: '+@(Select-String -LiteralPath $rpt -Pattern 'VeteranCompany applied').Count)
Write-Host ('  WEALTH_CONVERSION events: '+@(Select-String -LiteralPath $rpt -Pattern 'WEALTH_CONVERSION').Count)

Write-Host "`n-- MHQ RELOC (>=3000m leaps / sub-min aborts) --"
$mhq=@(Select-String -LiteralPath $rpt -Pattern 'MHQRELOC')
Write-Host ('  MHQRELOC lines: '+$mhq.Count)
$mhq | Select-Object -Last 6 | ForEach-Object { Write-Host ('    '+(($_.Line -split 'MHQRELOC\|')[-1]).Trim().Substring(0,[math]::Min(90,(($_.Line -split 'MHQRELOC\|')[-1]).Trim().Length))) }

Write-Host "`n-- FACTORIES (forward rebuild / scaffold) --"
$fac=@(Select-String -LiteralPath $rpt -Pattern 'SCAFFOLD_BUILD|FACTORY_RALLY|base construction|Construction_')
Write-Host ('  factory/construction lines: '+$fac.Count)
$fac | Select-Object -Last 4 | ForEach-Object { $l=$_.Line.Trim(); $st=[math]::Max(0,$l.IndexOf('AICOM')); Write-Host ('    '+$l.Substring($st,[math]::Min(110,$l.Length-$st))) }

Write-Host "`n-- AIRFIELD AIR (helis@AF / jets@field) --"
$af=@(Select-String -LiteralPath $rpt -Pattern 'hasAirfield|AIRFIELD|wfbe_is_airfield|free.air|airfield')
Write-Host ('  airfield-related lines: '+$af.Count)
$airk=@(Select-String -LiteralPath $rpt -Pattern 'AV8B|A10|Su25|F35|Ka52|Mi24|AH64|UH1|MH60|Ka137|Harrier')
Write-Host ('  aircraft-class mentions: '+$airk.Count)

Write-Host "`n-- AICOM activity / posture --"
Write-Host ('  AICOMSTAT lines: '+@(Select-String -LiteralPath $rpt -Pattern 'AICOMSTAT').Count)
foreach($s in @('WEST','EAST')){ $p=Select-String -LiteralPath $rpt -Pattern "POSTURE\|$s\|" | Select-Object -Last 1; if($p){ Write-Host ('  '+$s+' posture: '+(($p.Line -split "POSTURE\|")[-1]).Trim().Substring(0,[math]::Min(70,(($p.Line -split "POSTURE\|")[-1]).Trim().Length))) } }
