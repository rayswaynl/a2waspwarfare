# WaspSoakWatch - B48 all-day Chernarus soak reporter -> Ray's Peach+ DM.
# Gaming-PC scheduled task, every 30 min: SMALL report each tick, BIG deep-dive every 4th tick (~2h).
# Durable (survives Claude session ending): ssh box -> read RPT (scoped to last MISSINIT) -> rich status
# + heuristic IMPROVEMENT FINDINGS -> Peach+ DM (OMIT user_id => RAY 834428635896610886; never 1498...).
# Appends every report to wasp-soakwatch-findings.md. Self-heals the dashboard if down.
$ErrorActionPreference='Continue'
$log='C:\Users\Game\wasp-soakwatch.log'
$state='C:\Users\Game\wasp-soakwatch-state.json'
function L($m){ try{ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }catch{} }
L 'tick start'
$H='Administrator@78.46.107.142'

# ---- tick counter (BIG every 4th = ~2h) ----
$tick=0
try{ if(Test-Path $state){ $tick=[int]((Get-Content $state -Raw|ConvertFrom-Json).tick) } }catch{}
$tick++
$big = ($tick % 4 -eq 0)
$bigtag=''; $bigmark=''; if($big){ $bigtag=' BIG'; $bigmark=' [BIG]' }

# ---- box-side gather, SCOPED to the last MISSINIT (current round) ----
$box=@'
$r=Get-Item 'C:\Users\Administrator\AppData\Local\Arma 2 OA\arma2oaserver.RPT' -EA SilentlyContinue
'PROCS='+(@(Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue).Count)
if(-not $r){'AGE=na';return}
'AGE='+([math]::Round(((Get-Date)-$r.LastWriteTime).TotalMinutes,1))
$c=@(Get-Content $r.FullName)
$mi=($c|Select-String 'MISSINIT'|Select-Object -Last 1)
$s=if($mi){[Math]::Max(0,$mi.LineNumber-1)}else{0}
$cc=$c[$s..($c.Count-1)]
'ERR='+(($cc|Select-String 'Error in expression').Count)
'CAP='+(($cc|Select-String 'CAPTURED').Count)
'SVCENR='+(($cc|Select-String 'SERVICE_ENROUTE').Count)
'SVCDONE='+(($cc|Select-String 'SERVICE_DONE').Count)
'ABANDON='+(($cc|Select-String 'TARGET_ABANDON').Count)
'ARTYTHR='+(($cc|Select-String 'ARTY_THREAT_ARMED').Count)
'ARTRAD='+(($cc|Select-String 'ArtilleryRadar|SCAFFOLD_BUILD').Count)
'UNSTUCK='+(($cc|Select-String 'UNSTUCK_FIRED').Count)
'RETIRE='+(($cc|Select-String 'TEAM_RETIRE').Count)
'STUCK='+(($cc|Select-String 'STUCKSTAT').Count)
$cc|Select-String 'SRVPERF\|'|Select-Object -Last 1|ForEach-Object{'SRV='+($_.Line -replace '.*SRVPERF\|','' -replace '"','')}
$cc|Select-String 'GRPBUDGET'|Select-Object -Last 1|ForEach-Object{'GRP='+($_.Line -replace '.*GRPBUDGET\|','' -replace '"','')}
$cc|Select-String 'AICOMSTAT\|v1\|TICK\|WEST'|Select-Object -Last 1|ForEach-Object{'TWEST='+($_.Line -replace '.*TICK\|','' -replace '"','')}
$cc|Select-String 'AICOMSTAT\|v1\|TICK\|EAST'|Select-Object -Last 1|ForEach-Object{'TEAST='+($_.Line -replace '.*TICK\|','' -replace '"','')}
$cc|Select-String 'AICOMDBG\|v1\|SPEARHEAD'|Select-Object -Last 3|ForEach-Object{'SPEAR='+($_.Line -replace '.*SPEARHEAD\|','' -replace '"','')}
$cc|Select-String 'CMDRSTAT\|v1'|Select-Object -Last 2|ForEach-Object{'CMDR='+($_.Line -replace '.*CMDRSTAT\|','' -replace '"','')}
$cc|Select-String 'POSTURE'|Select-Object -Last 2|ForEach-Object{'POST='+($_.Line -replace '.*POSTURE\|','' -replace '"','')}
$cc|Select-String 'File [^,]*, line'|ForEach-Object{$_.Line -replace '.*(File [^"]*)','$1'}|Group-Object|Sort-Object Count -Desc|Select-Object -First 3|ForEach-Object{'ECLS='+$_.Count+'x '+$_.Name}
'@
$b64=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($box))
$raw=(@(& ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 $H powershell -NoProfile -EncodedCommand $b64 2>$null) -join "`n")
function GF($k){ @($raw -split "`n"|Where-Object{$_ -like "$k=*"}|ForEach-Object{$_.Substring($k.Length+1).Trim()}) }
$procs=(GF 'PROCS'|Select-Object -First 1); $age=(GF 'AGE'|Select-Object -First 1); $err=(GF 'ERR'|Select-Object -First 1)
$cap=(GF 'CAP'|Select-Object -First 1); $svcenr=(GF 'SVCENR'|Select-Object -First 1); $svcdone=(GF 'SVCDONE'|Select-Object -First 1)
$abandon=(GF 'ABANDON'|Select-Object -First 1); $artythr=(GF 'ARTYTHR'|Select-Object -First 1); $unstuck=(GF 'UNSTUCK'|Select-Object -First 1)
$retire=(GF 'RETIRE'|Select-Object -First 1); $stuck=(GF 'STUCK'|Select-Object -First 1)
$srv=(GF 'SRV'|Select-Object -First 1); $grp=(GF 'GRP'|Select-Object -First 1)
$twest=(GF 'TWEST'|Select-Object -First 1); $teast=(GF 'TEAST'|Select-Object -First 1)
$spear=@(GF 'SPEAR'); $cmdr=@(GF 'CMDR'); $post=@(GF 'POST'); $ecls=@(GF 'ECLS')
# parse SRVPERF: fps=..|units=..|groups=..|veh=..|dead=..|activeTowns=..
function SrvVal($name){ if($srv -match ("$name=([0-9]+)")){[int]$Matches[1]}else{$null} }
$fps=SrvVal 'fps'; $units=SrvVal 'units'; $groups=SrvVal 'groups'; $veh=SrvVal 'veh'; $act=SrvVal 'activeTowns'

# ---- dashboard health + self-heal ----
$dash='up'
try{ $dr=Invoke-WebRequest -Uri 'http://78.46.107.142:8080/' -TimeoutSec 8 -UseBasicParsing; if($dr.StatusCode -ne 200){$dash='HTTP'+$dr.StatusCode} }catch{ $dash='down' }
if($dash -ne 'up'){ try{ & ssh -o BatchMode=yes -o ConnectTimeout=20 $H 'schtasks /Run /TN WaspStatsWeb' 2>$null|Out-Null; $dash=$dash+'->restarted'; L 'dashboard restarted' }catch{} }

# ---- trends vs last snapshot ----
$prev=$null; try{ if(Test-Path $state){ $prev=Get-Content $state -Raw|ConvertFrom-Json } }catch{}
$capDelta=''; if($prev -and $prev.cap -ne $null -and $cap){ $d=[int]$cap-[int]$prev.cap; $capDelta=" (+$d since last)" }
$fpsTrend=''; if($prev -and $prev.fps -ne $null -and $fps -ne $null){ $d=$fps-[int]$prev.fps; if($d -ge 0){$fpsTrend=" (+$d)"}else{$fpsTrend=" ($d)"} }

# ---- heuristic IMPROVEMENT FINDINGS ----
$find=@()
if($procs -and [int]$procs -lt 3){ $find+="[server] only $procs/3 processes up - an HC or the server may have dropped; check the chain." }
if($err -and [int]$err -gt 0){ $eTop=''; if($ecls.Count){$eTop=' - top: '+$ecls[0]}; $find+="[bug] $err 'Error in expression' this round$eTop -> worth fixing." }
if($fps -ne $null -and $fps -lt 30){ $find+="[perf] server FPS $fps is low (units=$units groups=$groups veh=$veh activeTowns=$act) - group/unit count is the usual lever." }
elseif($fps -ne $null -and $groups -ne $null -and $groups -gt 160){ $find+="[perf] groups=$groups is high (fps still $fps) - watch for the FPS cliff; commander-team consolidation is the rank-2 lever." }
if($svcenr -and [int]$svcenr -gt 0){ $r=0; if($svcdone){$r=[int]$svcdone}; $svcNote=' Looks healthy.'; if([int]$svcenr -gt ($r+3)){$svcNote=' Many detours not completing -> watch for armour oscillating instead of fighting.'}; $find+="[B48 self-repair] $svcenr service detours, $r completed - the new rearm/heal feature is active.$svcNote" }
if($abandon -and [int]$abandon -gt 5){ $find+="[aicom] $abandon target-abandons - the AI is repeatedly failing to flip towns (too-hard targets or pathing); A8 should help, monitor which towns." }
if($cap -and [int]$cap -eq 0 -and [int]$tick -gt 4){ $find+="[aicom] 0 town captures so far this round - the front may be stalled; check spearhead picks + economy." }
if($unstuck -and [int]$unstuck -gt 8){ $find+="[aicom] $unstuck unstuck events - teams wedging on the way out; check base exit / routing." }
if($spear.Count){ $find+="[A8] recent spearhead picks: "+(($spear|Select-Object -Last 2) -join ' | ') }
if($find.Count -eq 0){ $find+="[ok] no red flags this tick - server healthy, no script errors, war progressing." }

# ---- build message ----
$ts=(Get-Date -Format 'HH:mm')
if(-not $procs -or $procs -eq '0'){
  $msg="**WASP SoakWatch $ts** - WARN: server shows 0 processes (down or restarting). Will recheck next tick."
} elseif($big){
  $lines=@("**WASP SoakWatch - 2h DEEP DIVE ($ts)** - B48 Chernarus soak",
    "**Server:** $procs/3 procs | FPS=$fps$fpsTrend | units=$units groups=$groups veh=$veh | activeTowns=$act | dash=$dash | RPTage=${age}m | SQFerr=$err",
    "**War:** captures=$cap$capDelta",
    ("WEST tick: "+$twest), ("EAST tick: "+$teast))
  if($cmdr.Count){ $lines+="**Commanders:** "+($cmdr -join ' || ') }
  if($post.Count){ $lines+="**Posture:** "+($post -join ' || ') }
  $lines+="**B48 features:** A8 picks + CB-gate(artyThreat=$artythr,radar=$artrad) + self-repair(enroute=$svcenr done=$svcdone)"
  if($spear.Count){ $lines+="**Spearhead (A8):** "+(($spear) -join "`n") }
  $lines+="**FINDINGS / what to improve:**`n- "+($find -join "`n- ")
  $msg=($lines -join "`n")
} else {
  $lines=@("**WASP SoakWatch $ts** - B48 Chernarus",
    "$procs/3 procs | FPS=$fps$fpsTrend | grp=$groups veh=$veh | activeTowns=$act | captures=$cap$capDelta | dash=$dash | err=$err",
    "self-repair: enroute=$svcenr done=$svcdone | abandons=$abandon | unstuck=$unstuck")
  # surface the single most important finding inline
  $top=@($find|Where-Object{$_ -notlike '*[A8]*' -and $_ -notlike '*[ok]*'})
  if($top.Count){ $lines+=$top[0] } else { $lines+=$find[0] }
  $msg=($lines -join "`n")
}

# ---- Peach+ DM (omit user_id => Ray) ----
try{
  $kl=Get-Content 'C:\Users\Game\Complete-discord-bot\.env'|Where-Object{$_ -like 'PEACH_OPS_API_KEY=*'}|Select-Object -First 1
  $key=($kl -replace '^PEACH_OPS_API_KEY=','').Trim().Trim('"')
  $body=@{content=$msg}|ConvertTo-Json -Compress
  $resp=Invoke-WebRequest -Uri 'http://127.0.0.1:5001/api/peach/admin/dm' -Method POST -Headers @{'Content-Type'='application/json';'X-Ops-Key'=$key} -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15 -UseBasicParsing
  L ('DM HTTP '+$resp.StatusCode+' (tick '+$tick+$bigtag+')')
}catch{ L ('DM FAIL '+$_.Exception.Message) }

# ---- persist state + findings ----
try{ @{tick=$tick; cap=$cap; fps=$fps; groups=$groups; at=(Get-Date -Format 'yyyy-MM-dd HH:mm')}|ConvertTo-Json -Compress|Set-Content -LiteralPath $state }catch{}
try{ Add-Content -LiteralPath 'C:\Users\Game\wasp-soakwatch-findings.md' -Value ("`n## "+(Get-Date -Format 'yyyy-MM-dd HH:mm')+$bigmark+"`n"+$msg) }catch{}
L 'tick done'
