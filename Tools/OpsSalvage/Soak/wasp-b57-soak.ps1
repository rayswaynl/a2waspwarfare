# WaspB57Soak - B66 24h Chernarus soak monitor/reporter (GAMING PC, durable scheduled task).
# Every 30 min: gather a rich B66 snapshot from the Hetzner box RPT (scoped to the last MISSINIT),
# APPEND an "impression for myself" (snapshot + heuristic findings) to wasp-b57-soak\impressions.md.
#   - NO Peach+ DM on the 30-min impression ticks.
#   - PERF DM only every 4th tick (~2h): concise 'WASP Perf' to Ray's Peach+ (OMIT user_id => RAY
#     834428635896610886; never add a user_id or it routes to his partner 1498945495970615386).
# RERUN-ON-WIN / keep-alive: on round-end (WASPSTAT ROUNDEND / GAME OVER / victory / MISSINIT change)
#   OR server-down (PROCS<3), trigger schtasks /Run /TN WaspServiceRestart on the box to CONTINUE the
#   soak on the SAME B66 mission. Guarded by a state flag + ~8 min cooldown (no double-fire).
# Does NOT deploy or change the live mission - monitor + rerun only. A2-safe / PS-5.1 + pwsh-safe.
$ErrorActionPreference='Continue'
$log='C:\Users\Game\wasp-b57-soak.log'
$state='C:\Users\Game\wasp-b57-soak-state.json'
$dir='C:\Users\Game\wasp-b57-soak'
$imp="$dir\impressions.md"
$H='Administrator@78.46.107.142'
$MISSION='[55-2hc]warfarev2_073v48co_b68.chernarus'
$MISSIONNAME='[55-2hc]warfarev2_073v48co_b68'   # MISSINIT records use this (no .chernarus suffix)
$RESTART_COOLDOWN_MIN=8

function L($m){ try{ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }catch{} }
try{ if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null } }catch{}
L 'tick start'

# ---- load prev state ----
$prev=$null
try{ if(Test-Path $state){ $prev=Get-Content $state -Raw|ConvertFrom-Json } }catch{}

# ---- tick counter (PERF DM every 4th = ~2h) ----
$tick=0
try{ if($prev -and $prev.tick -ne $null){ $tick=[int]$prev.tick } }catch{}
$tick++
$isPerf = ($tick % 4 -eq 0)
$perftag=''; if($isPerf){ $perftag=' [PERF-DM]' }

# ---- box-side gather, SCOPED to the last MISSINIT (current round) ----
$box=@'
$r=Get-Item 'C:\Users\Administrator\AppData\Local\Arma 2 OA\arma2oaserver.RPT' -EA SilentlyContinue
'PROCS='+(@(Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue).Count)
if(-not $r){'AGE=na';return}
'AGE='+([math]::Round(((Get-Date)-$r.LastWriteTime).TotalMinutes,1))
$c=@(Get-Content $r.FullName)
$mi=($c|Select-String 'MISSINIT'|Select-Object -Last 1)
if($mi){'MISSINIT='+($mi.Line -replace '"','')}
$s=if($mi){[Math]::Max(0,$mi.LineNumber-1)}else{0}
$cc=$c[$s..($c.Count-1)]
# errors
'ERR='+(($cc|Select-String 'Error in expression').Count)
'UNDEF='+(($cc|Select-String 'Undefined variable').Count)
# captures
'CAP='+(($cc|Select-String 'CAPTURED').Count)
'WCAP='+(($cc|Select-String 'WASPSTAT.*CAPTURE').Count)
# B66 founding-pad + team founding
'PAD='+(($cc|Select-String 'padded infantry team to (floor|found-size)').Count)
$cc|Select-String 'padded infantry team to (floor|found-size)'|Select-Object -Last 1|ForEach-Object{'PADSAMPLE='+($_.Line -replace '"','')}
'FOUNDED='+(($cc|Select-String 'TEAM_FOUNDED').Count)
# round-end / victory markers (rerun-on-win triggers)
'ROUNDEND='+(($cc|Select-String 'WASPSTAT.*ROUNDEND|\bROUNDEND\b').Count)
'GAMEOVER='+(($cc|Select-String 'GAME OVER|gameOver|side won|wins the|VICTORY').Count)
# perf
$cc|Select-String 'SRVPERF'|Select-Object -Last 1|ForEach-Object{'SRV='+($_.Line -replace '.*SRVPERF\|','' -replace '"','')}
$cc|Select-String 'HCSTAT'|Select-Object -Last 1|ForEach-Object{'HC='+($_.Line -replace '.*HCSTAT\|','' -replace '"','')}
# aicom posture/spearhead/cmdr
$cc|Select-String 'AICOMSTAT\|v1\|POSTURE\|WEST'|Select-Object -Last 1|ForEach-Object{'POSTW='+($_.Line -replace '.*POSTURE\|','' -replace '"','')}
$cc|Select-String 'AICOMSTAT\|v1\|POSTURE\|EAST'|Select-Object -Last 1|ForEach-Object{'POSTE='+($_.Line -replace '.*POSTURE\|','' -replace '"','')}
$cc|Select-String 'AICOMDBG\|v1\|SPEARHEAD'|Select-Object -Last 2|ForEach-Object{'SPEAR='+($_.Line -replace '.*SPEARHEAD\|','' -replace '"','')}
$cc|Select-String 'CMDRSTAT\|v1\|WEST'|Select-Object -Last 1|ForEach-Object{'CMDRW='+($_.Line -replace '.*CMDRSTAT\|','' -replace '"','')}
$cc|Select-String 'CMDRSTAT\|v1\|EAST'|Select-Object -Last 1|ForEach-Object{'CMDRE='+($_.Line -replace '.*CMDRSTAT\|','' -replace '"','')}
# top recurring error classes
$cc|Select-String 'File [^,]*, line'|ForEach-Object{$_.Line -replace '.*(File [^"]*)','$1'}|Group-Object|Sort-Object Count -Desc|Select-Object -First 3|ForEach-Object{'ECLS='+$_.Count+'x '+$_.Name}
'@
$b66=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($box))
$raw=''
try{ $raw=(@(& ssh -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 $H powershell -NoProfile -EncodedCommand $b66 2>$null) -join "`n") }catch{ L ('SSH FAIL '+$_.Exception.Message) }

function GF($k){ @($raw -split "`n"|Where-Object{$_ -like "$k=*"}|ForEach-Object{$_.Substring($k.Length+1).Trim()}) }
$procs=(GF 'PROCS'|Select-Object -First 1); $age=(GF 'AGE'|Select-Object -First 1)
$missinit=(GF 'MISSINIT'|Select-Object -First 1)
$err=(GF 'ERR'|Select-Object -First 1); $undef=(GF 'UNDEF'|Select-Object -First 1)
$cap=(GF 'CAP'|Select-Object -First 1); $wcap=(GF 'WCAP'|Select-Object -First 1)
$pad=(GF 'PAD'|Select-Object -First 1); $padsample=(GF 'PADSAMPLE'|Select-Object -First 1)
$founded=(GF 'FOUNDED'|Select-Object -First 1)
$roundend=(GF 'ROUNDEND'|Select-Object -First 1); $gameover=(GF 'GAMEOVER'|Select-Object -First 1)
$srv=(GF 'SRV'|Select-Object -First 1); $hc=(GF 'HC'|Select-Object -First 1)
$postw=(GF 'POSTW'|Select-Object -First 1); $poste=(GF 'POSTE'|Select-Object -First 1)
$spear=@(GF 'SPEAR'); $cmdrw=(GF 'CMDRW'|Select-Object -First 1); $cmdre=(GF 'CMDRE'|Select-Object -First 1)
$ecls=@(GF 'ECLS')

# parse SRVPERF: fps=..|units=..|groups=..|veh=..|dead=..|activeTowns=..
function SrvVal($name){ if($srv -match ("$name=([0-9]+)")){[int]$Matches[1]}else{$null} }
$fps=SrvVal 'fps'; $units=SrvVal 'units'; $groups=SrvVal 'groups'; $veh=SrvVal 'veh'; $act=SrvVal 'activeTowns'
# unitsPerTeam from CMDRSTAT (prefer WEST, fall back EAST), else HCSTAT-derived
function Upt($s){ if($s -and $s -match 'unitsPerTeam=([0-9.]+)'){$Matches[1]}else{$null} }
$uptW=Upt $cmdrw; $uptE=Upt $cmdre
$upt = if($uptW){$uptW}elseif($uptE){$uptE}else{$null}

# ---- determine server up / down ----
# The server is now a Windows Service (Arma2OA-PR8) but still spawns an arma2oaserver process,
# so the PROCS<3 heuristic (1 arma2oaserver + 2 HC clients) stays valid. WaspServiceRestart
# stops+starts the service and re-seats the 2 HCs, restoring the 3-proc end state.
$procN = 0; if($procs -and ($procs -as [int]) -ne $null){ $procN=[int]$procs }
$serverDown = ($procN -lt 3)

# ---- trends vs last snapshot ----
$capDelta=''; $capDeltaN=$null
if($prev -and $prev.cap -ne $null -and $cap){ try{ $capDeltaN=[int]$cap-[int]$prev.cap; $capDelta=" (+$capDeltaN since last)" }catch{} }
$fpsTrend=''
if($prev -and $prev.fps -ne $null -and $fps -ne $null){ try{ $d=$fps-[int]$prev.fps; if($d -ge 0){$fpsTrend=" (+$d)"}else{$fpsTrend=" ($d)"} }catch{} }

# ---- RERUN-ON-WIN / keep-alive detection ----
# triggers: round end markers, OR MISSINIT changed (mission cycled), OR server down.
$prevMiss = if($prev){ $prev.missinit }else{ $null }
$missChanged = ($missinit -and $prevMiss -and ($missinit -ne $prevMiss))
$roundEnded = (($roundend -and [int]$roundend -gt 0) -or ($gameover -and [int]$gameover -gt 0))
$restartReasons=@()
if($roundEnded){ $restartReasons+="round end detected (roundend=$roundend gameover=$gameover)" }
if($missChanged){ $restartReasons+="MISSINIT changed (mission cycled)" }
if($serverDown){ $restartReasons+="server down (procs=$procN/3)" }
$wantRestart = ($restartReasons.Count -gt 0)

# cooldown guard (don't re-fire within RESTART_COOLDOWN_MIN)
$lastRestart=$null
try{ if($prev -and $prev.lastRestart){ $lastRestart=[datetime]::Parse($prev.lastRestart) } }catch{}
$cooldownActive = ($lastRestart -ne $null -and ((Get-Date)-$lastRestart).TotalMinutes -lt $RESTART_COOLDOWN_MIN)

$restartFired=$false; $restartNote=''
if($wantRestart){
  if($cooldownActive){
    $restartNote="rerun WANTED ("+($restartReasons -join '; ')+") but SUPPRESSED by cooldown (last "+([math]::Round(((Get-Date)-$lastRestart).TotalMinutes,1))+"m ago)"
    L $restartNote
  } else {
    try{
      & ssh -o BatchMode=yes -o ConnectTimeout=20 $H 'schtasks /Run /TN WaspServiceRestart' 2>$null | Out-Null
      $restartFired=$true
      $restartNote="RERUN FIRED via WaspServiceRestart - reason: "+($restartReasons -join '; ')+" (same B66 mission, soak continues)"
      L $restartNote
    }catch{ $restartNote="rerun TRIGGER FAILED: "+$_.Exception.Message; L $restartNote }
  }
}
# carry forward the lastRestart timestamp
$newLastRestart = if($restartFired){ (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') } elseif($lastRestart){ $prev.lastRestart } else { $null }

# ---- heuristic FINDINGS ----
$find=@()
if($serverDown){ $find+="[server] only $procN/3 processes up - the server or an HC dropped; rerun-on-win logic handles a clean restart." }
if($err -and [int]$err -gt 0){ $eTop=''; if($ecls.Count){$eTop=' - top: '+$ecls[0]}; $find+="[bug] $err 'Error in expression' this round$eTop -> worth fixing." }
if($undef -and [int]$undef -gt 0){ $find+="[bug] $undef 'Undefined variable' warnings this round -> check the new B66 code paths." }
if($fps -ne $null -and $fps -lt 30){ $find+="[perf] server FPS $fps is low (units=$units groups=$groups veh=$veh activeTowns=$act) - group/unit count is the usual lever." }
elseif($fps -ne $null -and $groups -ne $null -and $groups -gt 160){ $find+="[perf] groups=$groups is high (fps still $fps) - watch for the FPS cliff; commander-team consolidation is the rank-2 lever." }
if($pad -and [int]$pad -gt 0){ $find+="[B66 founding] $pad infantry teams padded to found-size (e.g. $padsample) - larger groups confirmed; founded=$founded teams, unitsPerTeam=$upt." }
elseif([int]$tick -gt 2){ $find+="[B66 founding] 0 founding-pad events seen yet this round (founded=$founded) - confirm the larger-group change is firing." }
if($upt -and ([double]$upt -lt 8) -and [int]$tick -gt 2){ $find+="[aicom] unitsPerTeam=$upt is below the 8-12 target floor - teams may still be dribbling; centrepiece of the punchy-AICOM work." }
if($cap -and [int]$cap -eq 0 -and [int]$tick -gt 4){ $find+="[aicom] 0 town captures so far this round - the front may be stalled; check spearhead picks + economy." }
if($spear.Count){ $find+="[spearhead] recent picks: "+(($spear|Select-Object -Last 2) -join ' | ') }
if($restartNote){ $find=@("[RERUN] $restartNote")+$find }
if($find.Count -eq 0){ $find+="[ok] no red flags this tick - server healthy, no script errors, war progressing, larger groups founding." }

# ---- the single most important finding (skip informational ones) ----
# NOTE: use .Contains (literal) not -like; the tags contain [ ] which are -like wildcard metachars.
$topFind = @($find|Where-Object{ -not $_.Contains('[spearhead]') -and -not $_.Contains('[ok]') -and -not $_.Contains('[B66 founding]') })
$topMsg = if($topFind.Count){$topFind[0]}else{$find[0]}

# ---- uptime (RPT age == round uptime proxy if mission == B66) ----
$uptimeNote=''
if($age -and $age -ne 'na'){ $uptimeNote="RPTage=${age}m" }

$ts=(Get-Date -Format 'HH:mm')

# ---- build the impression block (always written) ----
# IMPORTANT: build the array with one $impLines+= per line (pure interpolation, no inline
# "x"+(expr)+"y" inside an @() literal). That PS parser quirk collapses the whole literal into a
# single element (the trailing + concatenation swallows following comma-separated elements).
$missMatch = if($missinit -and $missinit.Contains($MISSIONNAME)){'yes'}else{'NO - mission='+$missinit}
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$impLines=@()
$impLines += "## $stamp - tick $tick$perftag"
$impLines += "Mission: $MISSION (onB66=$missMatch)"
$impLines += "Server: $procN/3 procs | FPS=$fps$fpsTrend | units=$units groups=$groups veh=$veh | activeTowns=$act | $uptimeNote | err=$err undef=$undef"
$impLines += "War: captures=$cap$capDelta | WASPSTAT-captures=$wcap"
$impLines += "B66 founding: padded=$pad | founded=$founded | unitsPerTeam=$upt | sample=$padsample"
$impLines += "Posture: WEST $postw || EAST $poste"
$impLines += "Cmdr: WEST $cmdrw || EAST $cmdre"
$impLines += "HCSTAT: $hc"
if($spear.Count){ $impLines += ("Spearhead: "+(($spear) -join ' | ')) }
if($restartNote){ $impLines += "RERUN: $restartNote" }
$impLines += "Findings:"
foreach($f in $find){ $impLines += ("- "+$f) }
# write as a string array so Add-Content emits one physical line per element (robust on PS5.1 + pwsh);
# coerce every element to a single-line string first (strip any stray CR/LF in captured RPT data).
$impOut=@('') + @($impLines|ForEach-Object{ ([string]$_) -replace "[`r`n]+",' ' })
try{ Add-Content -LiteralPath $imp -Value $impOut }catch{ L ('impression write FAIL '+$_.Exception.Message) }
L ("impression appended (tick $tick"+$perftag+")")

# ---- PERF DM (only on the 2h tick) - omit user_id => Ray ----
if($isPerf){
  $rer = if($restartFired){' | RERUN fired'}elseif($restartNote){' | rerun: see note'}else{''}
  $padConfirm = if($pad -and [int]$pad -gt 0){' (larger groups CONFIRMED)'}else{' (not seen yet)'}
  # build with per-line += (no inline +(expr) inside an @() literal - that collapses the array)
  $dmLines=@()
  # emoji built via ConvertFromUtf32 so PS5.1's codepage can't mangle them (script stays ASCII; chars made at runtime)
  $E=@{ sat=[char]::ConvertFromUtf32(0x1F6F0); srv=[char]::ConvertFromUtf32(0x1F5A5); war=[char]::ConvertFromUtf32(0x2694); nav=[char]::ConvertFromUtf32(0x1F9ED); sol=[char]::ConvertFromUtf32(0x1FA96); eye=[char]::ConvertFromUtf32(0x1F50E); warn=[char]::ConvertFromUtf32(0x26A0) }
  $fpsIcon = if($fps -ne $null -and [int]$fps -lt 35){ $E.warn }else{ $E.srv }
  $dmLines += "$($E.sat) **WASP Perf - B68 Chernarus**  _(tick $tick - ~2h)_  -  $ts"
  $dmLines += "$fpsIcon **Server:** $procN/3 up - **FPS $fps$fpsTrend** - units $units - groups $groups - veh $veh - towns $act - $uptimeNote"
  $dmLines += "$($E.war) **War:** captures $cap$capDelta - errors $err _(undef $undef)_$rer"
  $dmLines += "$($E.nav) **Posture:** WEST $postw  -  EAST $poste"
  $dmLines += "$($E.sol) **Founding:** padded $pad - founded $founded - units/team $upt$padConfirm"
  $dmLines += "$($E.eye) **Watch:** $topMsg"
  $msg=($dmLines -join "`n")
  try{
    $kl=Get-Content 'C:\Users\Game\Complete-discord-bot\.env'|Where-Object{$_ -like 'PEACH_OPS_API_KEY=*'}|Select-Object -First 1
    $key=($kl -replace '^PEACH_OPS_API_KEY=','').Trim().Trim('"')
    $body=@{content=$msg}|ConvertTo-Json -Compress
    $resp=Invoke-WebRequest -Uri 'http://127.0.0.1:5001/api/peach/admin/dm' -Method POST -Headers @{'Content-Type'='application/json';'X-Ops-Key'=$key} -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15 -UseBasicParsing
    L ('PERF DM HTTP '+$resp.StatusCode+' (tick '+$tick+')')
  }catch{ L ('PERF DM FAIL '+$_.Exception.Message) }
} else {
  L ("no DM this tick (impression-only; PERF DM every 4th)")
}

# ---- persist state ----
try{
  @{
    tick=$tick; cap=$cap; fps=$fps; groups=$groups; missinit=$missinit;
    lastRestart=$newLastRestart; at=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  }|ConvertTo-Json -Compress|Set-Content -LiteralPath $state
}catch{ L ('state write FAIL '+$_.Exception.Message) }
L 'tick done'
