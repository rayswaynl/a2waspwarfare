$ErrorActionPreference='Stop'
$VER='b53'                                # stable-folder
$stem='[55-2hc]warfarev2_073v48co'
$world='chernarus'
$newName="${stem}.${world}"           # RESTORE: original yesterday name [55-2hc]warfarev2_073v48co.chernarus
$srcZip='C:\WASP\staging\b53-ch.zip'   # + B53 persistent fade watchdog
$log='C:\WASP\deploy-chernarus.log'
function L($m){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }
function End-Task($n){ schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task($n){ schtasks /Run /TN $n | Out-Null }
$mp='C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
$park='C:\WASP\mission-park'
$newFolder="$mp\$newName"
$cfg='C:\WASP\profiles-pr8\server-pr8.cfg'
$stamp=Get-Date -Format 'yyyyMMdd-HHmm'
try {
  L "CHERNARUS $VER FOLDER SWITCH START (mission=$newName FOLDER, world=$world)"
  if(-not [IO.File]::Exists($srcZip)){ throw "src zip missing: $srcZip" }
  if(((Get-Item $srcZip).Length) -lt 5MB){ throw 'src zip too small' }
  if(-not [IO.Directory]::Exists("$park\old-baks")){ [IO.Directory]::CreateDirectory("$park\old-baks")|Out-Null }
  End-Task 'MiksuuPR8'; End-Task 'MiksuuHC'; End-Task 'MiksuuHC2'
  Stop-Process -Name arma2oaserver,ArmA2OA -Force -ErrorAction SilentlyContinue
  Start-Sleep 8; L 'chain stopped'
  # REVERT MaxMsgSend to 512 (yesterday's value) during the stop window (file is locked while server runs)
  try { $bc='C:\WASP\profiles-pr8\basic.cfg'; if([IO.File]::Exists($bc)){ $nl=(Get-Content $bc)|ForEach-Object{ if($_ -match '^\s*MaxMsgSend\s*='){'MaxMsgSend=512;'}else{$_} }; Set-Content -LiteralPath $bc -Value $nl; L 'MaxMsgSend reverted to 512' } } catch { L ('MaxMsgSend revert skipped: '+$_.Exception.Message) }
  # park ALL prior warfarev2 chernarus pbos AND folders
  Get-ChildItem $mp -Force -EA SilentlyContinue | Where-Object { $_.Name -like '*warfarev2_073v48co*chernarus*' } | ForEach-Object {
    $dest="$park\old-baks\$($_.Name).bak-$stamp"
    if($_.PSIsContainer){ [IO.Directory]::Move($_.FullName,$dest) } else { [IO.File]::Move($_.FullName,$dest) }
    L ("parked "+$_.Name)
  }
  # extract the known-good zip into the FRESH folder (literal paths; brackets are not wildcards here)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if([IO.Directory]::Exists($newFolder)){ [IO.Directory]::Delete($newFolder,$true) }
  [System.IO.Compression.ZipFile]::ExtractToDirectory($srcZip,$newFolder)
  if(-not [IO.File]::Exists("$newFolder\mission.sqm")){ throw 'extract failed (no mission.sqm at folder root)' }
  $cnt=@(Get-ChildItem -LiteralPath $newFolder -Recurse -File).Count
  L ("deployed FOLDER $newName - $cnt files")
  # point cfg PR8_Chernarus template at the fresh folder name (matches ANY current chernarus form)
  $c = Get-Content $cfg -Raw
  $pat = 'template = "\[55-2hc\]warfarev2_073v48co[^"]*chernarus[^"]*";'
  $rep = 'template = "' + $newName + '";'
  $c2 = [regex]::Replace($c, $pat, $rep)
  Set-Content -LiteralPath $cfg -Value $c2 -NoNewline
  if(-not (Select-String -LiteralPath $cfg -Pattern $newName -SimpleMatch -Quiet)){ throw 'server.cfg template update failed (newName not found)' }
  L ("server.cfg PR8_Chernarus template -> " + $newName)
  $rpt='C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
  if([IO.File]::Exists($rpt)){ try { $arch='C:\WASP\rpt-archive'; if(-not [IO.Directory]::Exists($arch)){[IO.Directory]::CreateDirectory($arch)|Out-Null}; [IO.File]::Move($rpt,"$arch\arma2oaserver-$VER-$stamp.RPT") } catch {} }
  L 'relaunching chain'
  Run-Task 'MiksuuPR8'; Start-Sleep 40
  Run-Task 'MiksuuHC'; Start-Sleep 55
  Run-Task 'DismissACR'
  Run-Task 'MiksuuHC2'; Start-Sleep 50
  Run-Task 'DismissACR'
  $hc1=Get-Process ArmA2OA -EA SilentlyContinue | Sort-Object StartTime | Select-Object -First 1
  if($hc1){ Stop-Process -Id $hc1.Id -Force }
  End-Task 'MiksuuHC'; Run-Task 'MiksuuHC'; Start-Sleep 55; Run-Task 'DismissACR'
  $clients=@(Get-Process ArmA2OA -EA SilentlyContinue | Sort-Object StartTime)
  if($clients.Count -gt 1){ $clients | Select-Object -SkipLast 1 | Stop-Process -Force }
  End-Task 'MiksuuHC2'; Run-Task 'MiksuuHC2'; Start-Sleep 50; Run-Task 'DismissACR'
  Start-Sleep 10
  $procs=@(Get-Process arma2oaserver,ArmA2OA -EA SilentlyContinue).Count
  L "relaunch complete - $procs/3 up"
  Start-Sleep 6; try { L ('AFFINITY: '+((& 'C:\WASP\Set-WaspServerTuning.ps1') -join ' ')) } catch {}
  L "CHERNARUS $VER FOLDER SWITCH DONE"
  Write-Output 'SWITCH_DONE'
} catch { L ('FOLDER SWITCH FAILED: '+$_.Exception.Message); Write-Output ('SWITCH_FAILED: '+$_.Exception.Message); throw }
