# Find all HC RPT files on the live box
$candidates = @(
    "C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT",
    "C:\Sandbox\Administrator\HC2\user\current\AppData\Local\ArmA 2 OA\ArmA2OA.RPT",
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

# Also do a broader search
Write-Host ""
Write-Host "=== Broad search for ArmA2OA.RPT ==="
Get-ChildItem -Path "C:\Users\Administrator" -Recurse -Filter "ArmA2OA.RPT" -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime | Format-List

Get-ChildItem -Path "C:\Sandbox" -Recurse -Filter "ArmA2OA.RPT" -ErrorAction SilentlyContinue |
    Select-Object FullName, Length, LastWriteTime | Format-List

Write-Host "=== DONE ==="
