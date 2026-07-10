$ErrorActionPreference='Stop'
$log='C:\WASP\deploy-chernarus.log'
function L($m){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }
function End-Task($n){ schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task($n){ schtasks /Run /TN $n | Out-Null }
$mp='C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
$park='C:\WASP\mission-park'
$ch="$mp\[55-2hc]warfarev2_073v48co.chernarus"
$tk="$mp\[61-2hc]warfarev2_073v48co.takistan"
$exp="$mp\WASP_Experital_TEST.Chernarus"
$zip='C:\WASP\staging\aicom-chernarus-b361.zip'
$stamp=Get-Date -Format 'yyyyMMdd-HHmm'
try {
  L 'CHERNARUS B36 SWITCH START'
  if(-not [IO.File]::Exists($zip)){ throw 'aicom-chernarus-b361.zip missing' }
  if(-not [IO.Directory]::Exists("$park\old-baks")){ [IO.Directory]::CreateDirectory("$park\old-baks") | Out-Null }
  # 1. stop chain
  End-Task 'MiksuuPR8'; End-Task 'MiksuuHC'; End-Task 'MiksuuHC2'
  Stop-Process -Name arma2oaserver,ArmA2OA -Force -ErrorAction SilentlyContinue
  Start-Sleep 8
  L 'chain stopped'
  # 2. park takistan + experital so chernarus is the sole boot mission
  if([IO.Directory]::Exists($exp)){ [IO.Directory]::Move($exp,"$park\WASP_Experital_TEST.Chernarus"); L 'parked experital' }
  if([IO.Directory]::Exists($tk)){ [IO.Directory]::Move($tk,"$park\old-baks\[61-2hc]warfarev2_073v48co.takistan.bak-$stamp"); L 'parked+backed up takistan' }
  # 3. deploy B36 chernarus (back up any stale copy first)
  if([IO.Directory]::Exists($ch)){ [IO.Directory]::Move($ch,"$park\old-baks\[55-2hc]warfarev2_073v48co.chernarus.bak-$stamp"); L 'backed up old chernarus' }
  $tmp='C:\WASP\staging\unpack-ch'; if([IO.Directory]::Exists($tmp)){ [IO.Directory]::Delete($tmp,$true) }
  Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
  [IO.Directory]::Move($tmp,$ch)
  if(-not [IO.File]::Exists("$ch\mission.sqm")){ throw 'chernarus mission.sqm missing post-extract' }
  if(-not [IO.File]::Exists("$ch\Common\Functions\Common_RunCommanderTeam.sqf")){ throw 'chernarus RunCommanderTeam missing' }
  if(-not (Select-String -LiteralPath "$ch\initJIPCompatible.sqf" -Pattern 'SUPPLY_START_WEST", 12800' -SimpleMatch -Quiet)){ throw 'B36.1 economy marker (initJIP supply 12800) missing - WRONG BUILD' }
  if(-not (Select-String -LiteralPath "$ch\initJIPCompatible.sqf" -Pattern 'FUNDS_START_WEST", 30000' -SimpleMatch -Quiet)){ throw 'B36.1 economy marker (initJIP funds 30000) missing - WRONG BUILD' }
  if(-not (Select-String -LiteralPath "$ch\Common\Init\Init_CommonConstants.sqf" -Pattern 'WFBE_C_AICOM_TEAMS_PC_LOW  = 10' -SimpleMatch -Quiet)){ throw 'B36.1 curve marker (TEAMS_PC_LOW=5) missing - WRONG BUILD' }
  L 'B36 chernarus deployed + verified - sole mission in MPMissions'
  # 4. rotate RPT for a clean boot log
  $rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
  if([IO.File]::Exists($rpt)){ try { $arch='C:\WASP\rpt-archive'; if(-not [IO.Directory]::Exists($arch)){[IO.Directory]::CreateDirectory($arch)|Out-Null}; [IO.File]::Move($rpt,"$arch\arma2oaserver-ch-$stamp.RPT"); L 'rotated RPT' } catch { L 'RPT rotate skipped' } }
  # 5. relaunch chain (proven both-HC reslot bounce)
  L 'relaunching chain on chernarus'
  Run-Task 'MiksuuPR8'; Start-Sleep 40
  Run-Task 'MiksuuHC'; Start-Sleep 55
  Run-Task 'DismissACR'
  Run-Task 'MiksuuHC2'; Start-Sleep 50
  Run-Task 'DismissACR'
  $hc1=Get-Process ArmA2OA -ErrorAction SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
  if($hc1){ Stop-Process -Id $hc1.Id -Force }
  End-Task 'MiksuuHC'; Run-Task 'MiksuuHC'; Start-Sleep 55
  Run-Task 'DismissACR'
  $clients=@(Get-Process ArmA2OA -ErrorAction SilentlyContinue | Sort-Object StartTime)
  if($clients.Count -gt 1){ $clients | Select-Object -SkipLast 1 | Stop-Process -Force }
  End-Task 'MiksuuHC2'; Run-Task 'MiksuuHC2'; Start-Sleep 50
  Run-Task 'DismissACR'
  Start-Sleep 10
  $procs=@(Get-Process arma2oaserver,ArmA2OA -ErrorAction SilentlyContinue).Count
  L "relaunch complete - $procs/3 processes up"
  Start-Sleep 6; try { L ('AFFINITY: '+((& 'C:\WASP\Set-WaspServerTuning.ps1') -join ' ')) } catch { L 'affinity skip' }
  L 'CHERNARUS B36 SWITCH DONE'
  Write-Output 'SWITCH_DONE'
} catch { L ('CHERNARUS SWITCH FAILED: '+$_.Exception.Message); Write-Output ('SWITCH_FAILED: '+$_.Exception.Message); throw }
