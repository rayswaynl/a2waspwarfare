<#
  harvest-town-coords.ps1 — one-shot: pull the TOWNPOS|v1| lines the boot-logger
  (WFBE_C_LOG_TOWN_COORDS=1, PR #116) writes to the server RPT, and print a ready-to-paste
  Python dict for matchdata.TOWN_COORDS[<world>]. Run AFTER a server restart with the flag on.

  Line shape (Server/Init/Init_Towns.sqf):  TOWNPOS|v1|<world>|<name>|<x>|<y>

  Usage:
    pwsh -File harvest-town-coords.ps1                 # ssh-pull the live RPT
    pwsh -File harvest-town-coords.ps1 -RptFile x.rpt  # parse a local RPT/log
#>
param(
  [string]$RptFile,
  [string]$Host_ = 'Administrator@78.46.107.142',
  [string]$RemoteRpt = 'C:/Users/Administrator/AppData/Local/ArmA 2 OA/arma2oaserver.RPT'
)
$lines = if ($RptFile) { Get-Content -LiteralPath $RptFile } else {
  ssh -o BatchMode=yes -o ConnectTimeout=20 $Host_ "findstr /C:`"TOWNPOS|v1|`" `"$RemoteRpt`""
}
$towns = @{}   # world -> ordered list of "Name":(x,y)
foreach ($ln in $lines) {
  if ($ln -match 'TOWNPOS\|v1\|([^|]+)\|([^|]+)\|(-?\d+)\|(-?\d+)') {
    $world=$Matches[1].Trim(); $name=$Matches[2].Trim()
    if ($name -eq '__COUNT__') { continue }
    if (-not $towns.ContainsKey($world)) { $towns[$world]=[ordered]@{} }
    $towns[$world][$name] = @([int]$Matches[3], [int]$Matches[4])   # last wins (dedupe)
  }
}
if ($towns.Count -eq 0) { Write-Host "No TOWNPOS lines found — has the server booted with WFBE_C_LOG_TOWN_COORDS=1?"; return }
foreach ($world in $towns.Keys) {
  $entries = $towns[$world].GetEnumerator() | ForEach-Object { '  "{0}":({1},{2}),' -f $_.Key, $_.Value[0], $_.Value[1] }
  Write-Host ""
  Write-Host ('# paste into matchdata.TOWN_COORDS  ({0} towns, world={1})' -f $towns[$world].Count, $world)
  Write-Host (' "{0}": {{' -f $world.ToLower())
  $entries | ForEach-Object { Write-Host $_ }
  Write-Host ' },'
}
