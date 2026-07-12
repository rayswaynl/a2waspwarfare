$t = Get-Content 'C:\Users\Administrator\AppData\Local\ArmA 2 OA\ArmA2OA.RPT' -Tail 3000
Write-Output "=== HC RPT: static-defence / manning lines ==="
$t | Select-String -Pattern 'StaticDefence|static.defence|moveInGunner|boarding|Server_HandleDefense' -CaseSensitive:$false | Select-Object -Last 12 | ForEach-Object { $_.Line.Substring(0,[Math]::Min(145,$_.Line.Length)) }
Write-Output "=== HC RPT: recent errors ==="
$t | Select-String -Pattern 'Error in expression|Error Undefined' | Select-Object -Last 5 | ForEach-Object { $_.Line.Substring(0,[Math]::Min(145,$_.Line.Length)) }
