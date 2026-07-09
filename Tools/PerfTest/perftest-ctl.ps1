# perftest-ctl.ps1 <action> - WASP perf-pack A/B livetest controller (box-side)
# Actions: deploy-off | switch-on | restore | status
$ErrorActionPreference = "Stop"
$action = $args[0]
$cfgPath = "C:\WASP\profiles-pr8\server-pr8.cfg"
$mp = "C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions"
$dir = "C:\WASP\perftest"
$rpt = "C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT"
New-Item -ItemType Directory -Force $dir | Out-Null

function Stop-ServerForCfgEdit {
    sc.exe stop Arma2OA-PR8 | Out-Null
    $tries = 0
    while ($tries -lt 30) {
        $state = (sc.exe query Arma2OA-PR8 | Select-String "STATE").ToString()
        if ($state -match "STOPPED") { break }
        Start-Sleep -Seconds 2; $tries++
    }
    Write-Output "service stopped (waited $($tries*2)s)"
}

function Set-MissionBlock([string]$template) {
    Stop-ServerForCfgEdit
    $cfg = Get-Content $cfgPath -Raw
    $pattern = '(?s)class Missions\s*\{.*?\n\};'
    $block = "class Missions`r`n{`r`n`tclass PerfTest`r`n`t{`r`n`t`ttemplate = `"$template`";`r`n`t`tdifficulty = `"Veteran`";`r`n`t};`r`n};"
    $newCfg = [regex]::Replace($cfg, $pattern, $block.Replace('$', '$$'))
    if ($newCfg -eq $cfg) { throw "class Missions block not replaced" }
    Set-Content -Path $cfgPath -Value $newCfg -NoNewline
    Write-Output "cfg mission -> $template"
}

function Restart-Stack {
    schtasks /Run /TN WaspServiceRestart | Out-Null
    Write-Output "WaspServiceRestart triggered"
}

switch ($action) {
    "deploy-off" {
        if (-not (Test-Path "$dir\server-pr8.cfg.bak")) { Copy-Item $cfgPath "$dir\server-pr8.cfg.bak" }
        foreach ($v in @("PerfOFF", "PerfON")) {
            $zip = "$dir\$v.zip"
            if (-not (Test-Path $zip)) { throw "missing $zip" }
            $dest = "$mp\WASP_Perf$($v.Substring(4))_TEST.Chernarus"
            if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
            Expand-Archive -Path $zip -DestinationPath $mp -Force
        }
        Write-Output ("extracted: " + ((Get-ChildItem $mp -Directory -Filter "WASP_Perf*").Name -join ", "))
        Set-MissionBlock "WASP_PerfOFF_TEST.Chernarus"
        Restart-Stack
    }
    "switch-on" {
        Copy-Item $rpt "$dir\rptA-off.txt" -Force
        Write-Output ("rptA-off saved: " + [int]((Get-Item "$dir\rptA-off.txt").Length / 1KB) + " KB")
        Set-MissionBlock "WASP_PerfON_TEST.Chernarus"
        Restart-Stack
    }
    "restore" {
        Copy-Item $rpt "$dir\rptB-on.txt" -Force
        Write-Output ("rptB-on saved: " + [int]((Get-Item "$dir\rptB-on.txt").Length / 1KB) + " KB")
        Copy-Item "$dir\server-pr8.cfg.bak" $cfgPath -Force
        Write-Output "cfg restored from backup"
        Restart-Stack
    }
    "status" {
        sc.exe query Arma2OA-PR8 | Select-String "STATE"
        Get-Process | Where-Object { $_.ProcessName -like "*arma*" } | Select-Object ProcessName, Id, @{n="MB";e={[int]($_.WorkingSet64/1MB)}} | Format-Table -AutoSize
        $cfg = Get-Content $cfgPath -Raw
        $m = [regex]::Match($cfg, 'template = "([^"]+)"')
        Write-Output ("active template: " + $m.Groups[1].Value)
        Write-Output "--- RPT tail ---"
        Get-Content $rpt -Tail 30 -ErrorAction SilentlyContinue
    }
    default { throw "unknown action: $action" }
}
