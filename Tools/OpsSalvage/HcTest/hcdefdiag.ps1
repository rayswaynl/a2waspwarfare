$profiles = Get-ChildItem 'C:\WASP\hc-profile' -Recurse -Filter '*.RPT' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2
foreach ($p in $profiles) {
    Write-Output ("=== HC RPT: " + $p.FullName + " (fresh: " + $p.LastWriteTime + ") ===")
    $t = Get-Content $p.FullName -Tail 1500
    $t | Select-String -Pattern 'StaticDefence|static.defence|moveInGunner|DelegateAI' -CaseSensitive:$false | Select-Object -Last 8 | ForEach-Object { $_.Line.Substring(0,[Math]::Min(140,$_.Line.Length)) }
}
if (-not $profiles) {
    Write-Output "no RPT under C:\WASP\hc-profile - searching user dirs"
    Get-ChildItem 'C:\Users\Administrator\AppData\Local' -Recurse -Filter 'ArmA2OA.RPT' -ErrorAction SilentlyContinue | Select-Object -First 4 | ForEach-Object { $_.FullName + " | " + $_.LastWriteTime }
}
