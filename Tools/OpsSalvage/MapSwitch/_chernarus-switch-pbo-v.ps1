$ErrorActionPreference='Stop'
$VER='b51'
$stem='[55-2hc]warfarev2_073v48co'   # mission-name stem (version goes HERE, before the world)
$world='chernarus'                    # the world is the FINAL dot-token - must stay valid
$newName="${stem}_${VER}.${world}"     # STABLE: fresh name [55-2hc]warfarev2_073v48co_stable.chernarus (world stays chernarus)
$baseFolder="${stem}.${world}"        # original unversioned folder name (to park if present)
$log='C:\WASP\deploy-chernarus.log'
function L($m){ Add-Content -LiteralPath $log -Value ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$m) }
function End-Task($n){ schtasks /End /TN $n 2>$null | Out-Null }
function Run-Task($n){ schtasks /Run /TN $n | Out-Null }
$mp='C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
$park='C:\WASP\mission-park'
$newPbo="$mp\$newName.pbo"
$pbosrc="C:\WASP\staging\$VER-ch.pbo"
$cfg='C:\WASP\profiles-pr8\server-pr8.cfg'
$stamp=Get-Date -Format 'yyyyMMdd-HHmm'
try {
  L "CHERNARUS $VER VERSIONED SWITCH START (mission=$newName, world=$world)"
  if(-not [IO.File]::Exists($pbosrc)){ throw "staged pbo missing: $pbosrc" }
  if(((Get-Item $pbosrc).Length) -lt 5MB){ throw 'staged pbo too small' }
  if(-not [IO.Directory]::Exists("$park\old-baks")){ [IO.Directory]::CreateDirectory("$park\old-baks")|Out-Null }
  End-Task 'MiksuuPR8'; End-Task 'MiksuuHC'; End-Task 'MiksuuHC2'
  Stop-Process -Name arma2oaserver,ArmA2OA -Force -ErrorAction SilentlyContinue
  Start-Sleep 8; L 'chain stopped'
  try { $bc='C:\WASP\profiles-pr8\basic.cfg'; if([IO.File]::Exists($bc)){ $nl=(Get-Content $bc)|ForEach-Object{ if($_ -match '^\s*MaxMsgSend\s*='){'MaxMsgSend=1024;'}else{$_} }; Set-Content -LiteralPath $bc -Value $nl } } catch {}
  # park old folder + ALL prior warfarev2 chernarus pbos (any version/suffix, incl the broken ..chernarus_b50)
  if([IO.Directory]::Exists("$mp\$baseFolder")){ [IO.Directory]::Move("$mp\$baseFolder","$park\old-baks\$baseFolder.folder.bak-$stamp"); L 'parked folder' }
  Get-ChildItem $mp -File -EA SilentlyContinue | Where-Object { $_.Name -like '*warfarev2_073v48co*chernarus*.pbo' } | ForEach-Object { [IO.File]::Move($_.FullName, "$park\old-baks\$($_.Name).bak-$stamp"); L ("parked old pbo "+$_.Name) }
  # deploy corrected versioned pbo
  [IO.File]::Copy($pbosrc,$newPbo,$true)
  if(-not [IO.File]::Exists($newPbo)){ throw 'new pbo missing post-copy' }
  L ("deployed " + $newName + ".pbo - " + [math]::Round(((Get-Item $newPbo).Length/1MB),2) + " MB, sole copy")
  # point server.cfg PR8_Chernarus template at the corrected name (matches ANY current chernarus form)
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
  L "CHERNARUS $VER VERSIONED SWITCH DONE"
  Write-Output 'SWITCH_DONE'
} catch { L ('VERSIONED SWITCH FAILED: '+$_.Exception.Message); Write-Output ('SWITCH_FAILED: '+$_.Exception.Message); throw }
