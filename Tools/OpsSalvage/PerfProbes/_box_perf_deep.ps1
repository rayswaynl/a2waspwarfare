$ErrorActionPreference='Continue'
$rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$L = Get-Content -LiteralPath $rpt
"=== RPT lines=$($L.Count) ==="

# ---------- 1. FULL PerformanceAudit bracket profile: rank by cumulative total ms (CALLS*AVG) ----------
"`n-- [1] SERVER perf brackets ranked by CUMULATIVE total ms (CALLS x AVG_MS) --"
$byName=@{}
foreach($ln in $L){
  $s="$ln"
  if($s -match 'NAME=([A-Za-z0-9_]+).*CALLS=([0-9]+).*AVG_MS=([0-9.]+).*MAX_MS=([0-9.]+)'){
    $n=$matches[1]; $c=[int]$matches[2]; $a=[double]$matches[3]; $mx=[double]$matches[4]
    # keep the latest (largest CALLS = most recent cumulative) per name
    if((-not $byName.ContainsKey($n)) -or ($c -ge $byName[$n].Calls)){ $byName[$n]=[pscustomobject]@{Name=$n;Calls=$c;Avg=$a;Max=$mx;Total=[math]::Round($c*$a,1)} }
  }
}
$byName.Values | Sort-Object Total -Descending | Select-Object -First 25 | ForEach-Object { "  {0,-30} calls={1,-6} avg={2,6} ms  max={3,6}  TOTAL={4,9} ms" -f $_.Name,$_.Calls,$_.Avg,$_.Max,$_.Total }

# ---------- 2. SRVPERF curve: fps vs units AND vs groups (binned) ----------
"`n-- [2] SRVPERF fps-vs-load curve (this session) --"
$rows=@()
foreach($ln in $L){ $s="$ln"; if($s -match 'SRVPERF\|v1\|.*fps=([0-9]+).*units=([0-9]+).*groups=([0-9]+).*veh=([0-9]+)'){ $rows+=[pscustomobject]@{fps=[int]$matches[1];u=[int]$matches[2];g=[int]$matches[3];v=[int]$matches[4]} } }
"  samples=$($rows.Count)"
if($rows.Count){
  "  by UNIT bin:  bin -> avg fps (n)"
  foreach($b in @(@(0,150),@(150,250),@(250,350),@(350,9999))){ $sub=$rows | Where-Object { $_.u -ge $b[0] -and $_.u -lt $b[1] }; if($sub){ "    {0,4}-{1,-4} fps={2,5} (n={3})" -f $b[0],$b[1],[math]::Round(($sub|Measure-Object fps -Average).Average,1),$sub.Count } }
  "  by GROUP bin: bin -> avg fps (n)"
  foreach($b in @(@(0,90),@(90,110),@(110,130),@(130,9999))){ $sub=$rows | Where-Object { $_.g -ge $b[0] -and $_.g -lt $b[1] }; if($sub){ "    {0,4}-{1,-4} fps={2,5} (n={3})" -f $b[0],$b[1],[math]::Round(($sub|Measure-Object fps -Average).Average,1),$sub.Count } }
  $maxu=($rows|Measure-Object u -Max).Maximum; $atmax=$rows | Where-Object { $_.u -ge ($maxu-30) }
  "  peak load: units max=$maxu  groups max=$(($rows|Measure-Object g -Max).Maximum)  veh max=$(($rows|Measure-Object v -Max).Maximum)  | fps at top-30u band avg=$([math]::Round(($atmax|Measure-Object fps -Average).Average,1)) min=$(($atmax|Measure-Object fps -Min).Minimum)"
  $uPerG=[math]::Round((($rows|Measure-Object u -Average).Average)/(($rows|Measure-Object g -Average).Average),2)
  "  avg units/group = $uPerG  (fragmentation: lower groups for same units = cheaper)"
}

# ---------- 3. Headless-client load (is the cliff HC-bound?) ----------
"`n-- [3] HC / client FPS + delegation --"
"  HCFPS/clientfps refs: $(@($L | Select-String 'HCFPS|hc_fps|HC_FPS|CLIENTFPS|HEADLESS.*fps|fps.*[Hh]eadless').Count)"
@($L | Select-String 'HCFPS|HC_FPS|hc_fps|CLIENTFPS|FPSREPORT|FPS_REPORT|delegate.*headless|DELEGATE|Headless.*delegate') | Select-Object -Last 10 | ForEach-Object { $s=$_.Line.Trim(); if($s.Length -gt 180){$s=$s.Substring(0,180)}; "  $s" }
"  SCOPE=CLIENT perf lines (HC-side brackets reported to server, if any): $(@($L | Select-String 'SCOPE=CLIENT').Count)"
@($L | Select-String 'SCOPE=CLIENT' | Select-String 'NAME=') | Select-Object -Last 6 | ForEach-Object { $s=$_.Line.Trim(); if($s.Length -gt 200){$s=$s.Substring(0,200)}; "  $s" }

# ---------- 4. Group/unit source breakdown (where do the ~110 groups live?) ----------
"`n-- [4] group-source / GC accounting --"
@($L | Select-String 'GCSTAT|GROUPSRC|by-source|srcCounts|server_groupsGC|untagged|editor-player-slot|town-garrison|aicom-team') | Select-Object -Last 12 | ForEach-Object { $s=$_.Line.Trim(); if($s.Length -gt 200){$s=$s.Substring(0,200)}; "  $s" }

# ---------- 5. AICOM team footprint ----------
"`n-- [5] AICOM team counts / founding --"
@($L | Select-String 'AICOMSTAT|wfbe_teams_count|founded|TEAM_FOUNDED|TEAM_RETIRED|teams=' ) | Select-Object -Last 10 | ForEach-Object { $s=$_.Line.Trim(); if($s.Length -gt 180){$s=$s.Substring(0,180)}; "  $s" }
