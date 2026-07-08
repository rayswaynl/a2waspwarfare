$files = @(Get-ChildItem 'C:\Users\Game\Downloads\ArmA2OA*.RPT' -EA SilentlyContinue | Sort-Object LastWriteTime)
$cm = Get-Item 'C:\Users\Game\wasp-rpt-reap\client-main.rpt' -EA SilentlyContinue
if ($cm) { $files += $cm }
Write-Output ("{0,-26} {1,-11} {2,-7} {3,-11} {4}" -f 'file','build','VD','mtime','client FPS by AI band")
Write-Output ("-" * 100)
foreach ($f in $files) {
    $L = Get-Content $f.FullName -EA SilentlyContinue
    if (-not $L) { continue }
    $bm = $L | Where-Object { $_ -match 'warfarev2_073v48co_b\d+aicom' } | Select-Object -Last 1
    $b = '?'
    if ($bm -match '(b\d+aicom)') { $b = $matches[1] }
    $vm = $L | Where-Object { $_ -match 'VD=\d+' } | Select-Object -Last 1
    $vd = '?'
    if ($vm -match 'VD=(\d+)') { $vd = $matches[1] }
    $pts = @()
    $clientLines = $L | Where-Object { $_ -match 'SCOPE=CLIENT' -and $_ -match 'FPS=\d+ PLAYERS=\d+ AI=\d+' }
    foreach ($line in $clientLines) {
        if ($line -match 'FPS=(\d+) PLAYERS=\d+ AI=(\d+)') {
            $pts += [pscustomobject]@{ fps = [int]$matches[1]; ai = [int]$matches[2] }
        }
    }
    function BandAvg($lo, $hi) {
        $s = $pts | Where-Object { $_.ai -ge $lo -and $_.ai -lt $hi }
        if ($s) { return [string][math]::Round(($s | Measure-Object fps -Average).Average) }
        return '-'
    }
    $loB = BandAvg 0 200
    $miB = BandAvg 200 300
    $hiB = BandAvg 300 9999
    $mt = $f.LastWriteTime.ToString('MM-dd HH:mm')
    Write-Output ("{0,-26} {1,-11} {2,-7} {3,-11} <200ai={4,-4} 200-300={5,-4} 300+={6,-4} (n={7})" -f $f.Name, $b, $vd, $mt, $loB, $miB, $hiB, $pts.Count)
}
