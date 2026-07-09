$ErrorActionPreference='Continue'
$rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$L=Get-Content -LiteralPath $rpt -EA SilentlyContinue
'  procs srv='+@(Get-Process arma2oaserver -EA SilentlyContinue).Count+' HC(ArmA2OA)='+@(Get-Process ArmA2OA -EA SilentlyContinue).Count
@($L|Where-Object{$_ -match 'MISSINIT'}|Select-Object -Last 1)|ForEach-Object{$t=$_.Trim();'  MISSINIT '+$t.Substring(0,[Math]::Min(110,$t.Length))}
'=== recent SRVPERF (server fps / units / AI / groups) ==='
@($L|Where-Object{$_ -match 'SRVPERF'})|Select-Object -Last 8|ForEach-Object{'  '+$_.Trim()}
'=== recent fps-ish lines (fallback if no SRVPERF) ==='
@($L|Where-Object{$_ -match 'fps|FPS' -and $_ -notmatch 'TFPS'})|Select-Object -Last 4|ForEach-Object{$t=$_.Trim();'  '+$t.Substring(0,[Math]::Min(130,$t.Length))}
'=== filtered errors (per-frame error spam tanks client fps too) ==='
$errs=$L|Where-Object{$_ -match 'Error in expression|Undefined variable|Type .* expected' -and $_ -notmatch 'asr_ai|sys_aiskill|_shooter|nearEntities|RadioProtocol'}
'  filtered-errs='+@($errs).Count+'  (total RPT lines='+$L.Count+')'
@($errs)|Select-Object -Last 6|ForEach-Object{$t=$_.Trim();'  ERR '+$t.Substring(0,[Math]::Min(160,$t.Length))}
'  rpt ageMin='+[math]::Round(((Get-Date)-(Get-Item -LiteralPath $rpt).LastWriteTime).TotalMinutes,1)
'SRVPERF_DONE'
