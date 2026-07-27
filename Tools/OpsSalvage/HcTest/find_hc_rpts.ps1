# Find all HC RPT files on the live box (Sandboxie-aware, 2026-07-27)
# Live RPTs land inside Sandboxie containers after HC1/HC2 sandbox cutover.
# Host-visible C:\WASP\hc*-profile and AppData paths are DECOYS when HCs run sandboxed.
$candidates = @(
    "C:\Sandbox\Administrator\HC1\drive\C\WASP\hc1-profile\ArmA2OA.RPT",
    "C:\Sandbox\Administrator\HC2\drive\C\WASP\hc2-profile\ArmA2OA.RPT",
    "C:\WASP\hc1-profile\ArmA2OA.RPT",
    "C:\WASP\hc2-profile\ArmA2OA.RPT",
    "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT",
    "C:\Users\Administrator\Documents\ArmA 2 Other Profiles\HC-AI-Control-1\ArmA2OA.RPT",
    "C:\Users\Administrator\Documents\ArmA 2 Other Profiles\HC-AI-Control-2\ArmA2OA.RPT"
)

Write-Host "=== HC RPT DISCOVERY ==="
foreach ($p in $candidates) {
    if (Test-Path $p) {
        $f = Get-Item $p
        Write-Host "FOUND: $p | Size: $($f.Length) bytes | LastWrite: $($f.LastWriteTime)"
    } else {
        Write-Host "NOT FOUND: $p"
    }
}

# Container globs (user may differ; box name HC1/HC2 is the contract)
Write-Host ""
Write-Host "=== Sandboxie container globs ==="
foreach ($pat in @(
    'C:\Sandbox\*\HC1\drive\C\WASP\hc1-profile\ArmA2OA.RPT',
    'C:\Sandbox\*\HC2\drive\C\WASP\hc2-profile\ArmA2OA.RPT'
)) {
    Get-ChildItem -Path $pat -File -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host "GLOB: $($_.FullName) | Size: $($_.Length) | LastWrite: $($_.LastWriteTime)" }
}

Write-Host ""
Write-Host "=== Broad search for ArmA2OA.RPT under C:\Sandbox ==="
Get-ChildItem -Path "C:\Sandbox" -Recurse -Filter "ArmA2OA.RPT" -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime | Format-List

Write-Host "=== DONE ==="
