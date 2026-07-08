$ErrorActionPreference='Stop'
$log='C:\WASP\deploy-chernarus.log'
function L($m){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }
function End-Task($n){ schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task($n){ schtasks /Run /TN $n | Out-Null }
$mp='C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
$park='C:\WASP\mission-park'
$ch="$mp\[55-2hc]warfarev2_073v48co.chernarus"
$chpbo="$mp\[55-2hc]warfarev2_073v48co.chernarus.pbo"
$pbosrc='C:\WASP\staging\b48-ch.pbo'
$stamp=Get-Date -Format 'yyyyMMdd-HHmm'
try {
  L 'CHERNARUS B48 PBO SWITCH START'
  if(-not [IO.File]::Exists($pbosrc)){ throw 'staged .pbo missing' }
  if(((Get-Item $pbosrc).Length) -lt 5MB){ throw 'staged .pbo too small (<5MB) - bad pack' }
  if(-not [IO.Directory]::Exists("$park\old-baks")){ [IO.Directory]::CreateDirectory("$park\old-baks") | Out-Null }
  # 1. stop chain
  End-Task 'MiksuuPR8'; End-Task 'MiksuuHC'; End-Task 'MiksuuHC2'
  Stop-Process -Name arma2oaserver,ArmA2OA -Force -ErrorAction SilentlyContinue
  Start-Sleep 8
  L 'chain stopped'
  # B49: raise JIP network buffer now the server is stopped (basic.cfg is locked while it runs)
  try {
    $bc='C:\WASP\profiles-pr8\basic.cfg'
    if([IO.File]::Exists($bc)){
      $nl = (Get-Content $bc) | ForEach-Object { if ($_ -match '^\s*MaxMsgSend\s*=') {'MaxMsgSend=1024;'} else {$_} }
      Set-Content -LiteralPath $bc -Value $nl
      L ('basic.cfg MaxMsgSend -> ' + (((Get-Content $bc) | Where-Object {$_ -match 'MaxMsgSend'}) -join ' '))
    }
  } catch { L ('basic.cfg edit skipped: '+$_.Exception.Message) }
  # 2. park the FOLDER mission (fallback) + any stale .pbo so the new .pbo is the sole copy of this name
  if([IO.Directory]::Exists($ch)){ [IO.Directory]::Move($ch,"$park\old-baks\[55-2hc]folder.bak-$stamp"); L 'parked old chernarus FOLDER (fallback)' }
  if([IO.File]::Exists($chpbo)){ [IO.File]::Move($chpbo,"$park\old-baks\[55-2hc]pbo.bak-$stamp.pbo"); L 'backed up old chernarus .pbo' }
  # 3. deploy the .pbo
  [IO.File]::Copy($pbosrc,$chpbo,$true)
  if(-not [IO.File]::Exists($chpbo)){ throw 'chernarus .pbo missing post-copy' }
  if([IO.Directory]::Exists($ch)){ throw 'chernarus FOLDER still present alongside .pbo - would conflict' }
  L ('B48 chernarus .pbo deployed - ' + [math]::Round(((Get-Item $chpbo).Length/1MB),2) + ' MB, sole copy')
  # 4. rotate RPT for a clean boot log
  $rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
  if([IO.File]::Exists($rpt)){ try { $arch='C:\WASP\rpt-archive'; if(-not [IO.Directory]::Exists($arch)){[IO.Directory]::CreateDirectory($arch)|Out-Null}; [IO.File]::Move($rpt,"$arch\arma2oaserver-chpbo-$stamp.RPT"); L 'rotated RPT' } catch { L 'RPT rotate skipped' } }
  # 5. relaunch chain (proven both-HC reslot bounce)
  L 'relaunching chain on chernarus .pbo'
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
  L 'CHERNARUS B48 PBO SWITCH DONE'
  Write-Output 'SWITCH_DONE'
} catch { L ('CHERNARUS PBO SWITCH FAILED: '+$_.Exception.Message); Write-Output ('SWITCH_FAILED: '+$_.Exception.Message); throw }
