$ErrorActionPreference = 'SilentlyContinue'
$ts = Get-Date -Format 'HH:mm:ss'
Write-Output "==== HC RECON $ts ===="

# --- service ---
$svc = Get-Service Arma2OA-PR8
Write-Output ("SVC Arma2OA-PR8 = " + $svc.Status)

# --- processes ---
$srv = @(Get-Process arma2oaserver)
$hc  = @(Get-Process ArmA2OA)
Write-Output ("PROC arma2oaserver=" + $srv.Count + "  ArmA2OA(HC clients)=" + $hc.Count)
foreach ($p in ($hc | Sort-Object StartTime)) {
    Write-Output ("   HC pid " + $p.Id + "  started " + $p.StartTime)
}

# --- tasks ---
foreach ($t in 'MiksuuHC','MiksuuHC2','HC2SteamLogin','WASP PR8 Test Server','ClaudeDeployAicom2') {
    $q = schtasks /query /tn $t /fo list /v 2>$null
    if ($q) {
        $st  = (($q | Select-String 'Status:') -join ' ').Trim()
        $lr  = (($q | Select-String 'Last Run Time:') -join ' ').Trim()
        $res = (($q | Select-String 'Last Result:') -join ' ').Trim()
        Write-Output ("[$t] $st | $lr | $res")
        if ($t -eq 'ClaudeDeployAicom2') {
            $tr = (($q | Select-String 'Task To Run:') -join ' ').Trim()
            Write-Output ("   TR: $tr")
        }
    } else {
        Write-Output "[$t] (not found)"
    }
}

# --- served pbo + cfg template ---
$mp = 'C:\Program Files (x86)\Steam\steamapps\common\Arma 2 Operation Arrowhead\MPMissions'
foreach ($f in (Get-ChildItem $mp -Filter '*warfarev2*' -ErrorAction SilentlyContinue)) {
    Write-Output ("PBO " + $f.Name + "   " + $f.LastWriteTime)
}
Write-Output '-- cfg missions structure (no secrets) --'
$cfgRaw = Get-Content 'C:\WASP\profiles-pr8\server-pr8.cfg' -ErrorAction SilentlyContinue
for ($i = 0; $i -lt $cfgRaw.Count; $i++) {
    $line = $cfgRaw[$i]
    if (($line -match 'class\s|Mission|template|difficulty|=\s*\{|\}') -and ($line -notmatch 'passw')) {
        Write-Output ("  cfg[$i] " + $line.Trim())
    }
}
Write-Output '-- box deploy assets --'
foreach ($a in 'C:\WASP\_freshname_pbo_deploy_b742aicom.ps1','C:\WASP\staging\b74.2aicom-ch.pbo') {
    Write-Output ("  " + (Test-Path $a) + "  " + $a)
}
foreach ($dt in 'DismissACR') {
    $dq = schtasks /query /tn $dt /fo list 2>$null
    Write-Output ("  task $dt present=" + [bool]$dq)
}

# --- RPT headless tail ---
$rpt = 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\arma2oaserver.RPT'
if (Test-Path $rpt) {
    $it = Get-Item $rpt
    Write-Output ("RPT mtime " + $it.LastWriteTime + "  size " + $it.Length)
    $tail = Get-Content $rpt -Tail 900
    $hcl  = @($tail | Select-String -Pattern 'eadless','connected-hc','Functionary','HEADLESS' | Select-Object -ExpandProperty Line)
    Write-Output ("RPT_HC_LINES=" + $hcl.Count)
    $n = $hcl.Count
    $start = [Math]::Max(0, $n - 18)
    for ($i = $start; $i -lt $n; $i++) { Write-Output ("RPT " + $hcl[$i]) }
} else {
    Write-Output "RPT not found"
}
Write-Output "==== END ===="
