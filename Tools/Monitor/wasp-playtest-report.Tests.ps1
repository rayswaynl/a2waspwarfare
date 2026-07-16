#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$box=Join-Path $root 'wasp-playtest-box.ps1'
$work=Join-Path $env:TEMP ('wasp-playtest-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $lines=@(
        'MISSINIT: missionName=[55] Warfare V48 Chernarus, worldName=chernarus',
        '"WASPSCALE|v2|1|tier=0|players=2|AI_W=10|AI_E=12|AI_GUER=3|AI_TOT=25|groups=4|fps=18|map=chernarus|hc_fps=22|townsW=4|townsE=5|townsG=2"',
        '"[Performance Audit] NAME=snapshot FPS=18 PLAYERS=2 AI=25 UNITS=27 VEHICLES=4 TOWNS_ACTIVE=3"',
        '"WASPSTAT|v1|2|76561198000000001:0~"HC-AI-Control-1"|76561198000000002:0~"HC-AI-Control-2""',
        '  Error in expression: Undefined variable in expression: _boom',
        '  File mpmissions\\x\\Server\\x.sqf, line 42',
        'Player without identity "HC-AI-Control-1"'
    )
    foreach($name in 'arma2oaserver.RPT','hc1-ArmA2OA.RPT','hc2-ArmA2OA.RPT'){[IO.File]::WriteAllLines((Join-Path $work $name),$lines,[Text.Encoding]::GetEncoding(1252))}
    $output=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $box -SrvFrom -1 -Hc1From -1 -Hc2From -1 -SrvRpt (Join-Path $work 'arma2oaserver.RPT') -Hc1Rpt (Join-Path $work 'hc1-ArmA2OA.RPT') -Hc2Rpt (Join-Path $work 'hc2-ArmA2OA.RPT'))
    if(-not ($output -match 'collectorStatus=ok')){throw 'collector status missing'}
    if(-not ($output -match 'scale_AI_TOT=25')){throw 'scale AI missing'}
    if(-not ($output -match 'roster_hc=2\|roster_humans=0')){throw 'HC/human split failed'}
    $state=Join-Path $work 'state.json'; $out=Join-Path $work 'out'; $report=Join-Path $root 'wasp-playtest-report.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $report -Action Start -StatePath $state -OutputDirectory $out -LocalCollector $box -LocalSourceDirectory $work -NoSend | Out-Null
    Add-Content -LiteralPath (Join-Path $work 'arma2oaserver.RPT') -Value '  Error in expression: Undefined variable in expression: _boom' -Encoding UTF8
    Add-Content -LiteralPath (Join-Path $work 'arma2oaserver.RPT') -Value '  File mpmissions\\x\\Server\\x.sqf, line 42' -Encoding UTF8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $report -Action Tick -StatePath $state -OutputDirectory $out -LocalCollector $box -LocalSourceDirectory $work -NoSend | Out-Null
    if(-not (Test-Path $state)){throw 'state not written'}
    $s=Get-Content -Raw $state|ConvertFrom-Json
    if([int]$s.peakPlayers -ne 0){throw 'peak player baseline wrong'}
    if(-not (@($s.errorCounts | Where-Object {$_.signature -match 'x.sqf:42'}).Count)){throw 'error signature missing'}
    Write-Output 'ALL TESTS PASSED'
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
