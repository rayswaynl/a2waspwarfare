Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'arma2' } | ForEach-Object {
    Write-Output ("PROC: " + $_.ProcessId)
    Write-Output ("  CMD: " + $_.CommandLine)
}
Get-ChildItem C:\WASP -Filter *.ps1 | Select-Object -ExpandProperty Name
