$ErrorActionPreference='Continue'
$rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
$rows=@()
@(Select-String -LiteralPath $rpt -Pattern 'SRVPERF\|v1\|') | ForEach-Object {
  if($_.Line -match 'SRVPERF\|v1\|(\d+)\|fps=(\d+)\|units=(\d+)\|groups=(\d+)\|veh=(\d+)\|dead=(\d+)\|activeTowns=(\d+)'){
    $rows += [pscustomobject]@{min=[int]$Matches[1];fps=[int]$Matches[2];units=[int]$Matches[3];groups=[int]$Matches[4];veh=[int]$Matches[5];towns=[int]$Matches[7]}
  }
}
Write-Output ("SRVPERF samples: " + $rows.Count)
if($rows.Count -gt 0){
  $u=$rows.units|Measure-Object -Min -Max -Average; $f=$rows.fps|Measure-Object -Min -Max -Average
  Write-Output ("units: min=" + $u.Minimum + " max=" + $u.Maximum + " avg=" + [int]$u.Average + "  |  fps: min=" + $f.Minimum + " max=" + $f.Maximum + " avg=" + [int]$f.Average)
  Write-Output "--- MEASURED FPS vs total server UNITS (test box) ---"
  $bins=@(0,60,100,140,180,220,260,300,360,420,9999)
  for($i=0;$i -lt $bins.Count-1;$i++){
    $lo=$bins[$i];$hi=$bins[$i+1]
    $b=@($rows|Where-Object{$_.units -ge $lo -and $_.units -lt $hi})
    if($b.Count -gt 0){
      $bf=$b.fps|Measure-Object -Average -Min -Max
      $bt=($b.towns|Measure-Object -Average).Average; $bg=($b.groups|Measure-Object -Average).Average
      Write-Output ("  units " + $lo + "-" + $hi + " : n=" + $b.Count + "  fps avg=" + [int]$bf.Average + " min=" + $bf.Minimum + " max=" + $bf.Maximum + "  | groups~" + [int]$bg + " towns~" + [int]$bt)
    }
  }
  Write-Output "--- worst 5 (lowest fps) samples ---"
  $rows | Sort-Object fps | Select-Object -First 5 | ForEach-Object { Write-Output ("  fps=" + $_.fps + " units=" + $_.units + " groups=" + $_.groups + " veh=" + $_.veh + " towns=" + $_.towns + " @min " + $_.min) }
}
# HC fps (the HC carries ~half the AI compute)
Write-Output "--- HC fps (HCSTAT) ---"
@(Select-String -LiteralPath $rpt -Pattern 'HCSTAT\|v1\|') | Select-Object -Last 4 | ForEach-Object { if($_.Line -match 'HCSTAT\|v1\|([^|]+)\|fps=(\d+)\|units=(\d+)\|groups=(\d+)'){ Write-Output ("  " + $Matches[1] + " fps=" + $Matches[2] + " units=" + $Matches[3] + " groups=" + $Matches[4]) } }
# current snapshot
$mi=@(Select-String -LiteralPath $rpt -Pattern 'MISSINIT') | Select-Object -Last 1
if($mi){ Write-Output ("mission=" + (($mi.Line -replace '.*missionName=','') -replace ',.*','')) }
$fi=Get-Item -LiteralPath $rpt; Write-Output ("RPT size_MB=" + [math]::Round($fi.Length/1MB,2) + " age_min=" + [math]::Round(((Get-Date)-$fi.LastWriteTime).TotalMinutes,1))
