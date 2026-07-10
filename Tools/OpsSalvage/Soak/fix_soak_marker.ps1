$p = 'C:\WASP\incoming\soak1-deploy.ps1'
$t = [IO.File]::ReadAllText($p)
$orig = $t
$t = $t -replace 'build89-soakv2-20260706', 'build89-soakv2r3-20260706'
if ($t -ne $orig) {
    [IO.File]::WriteAllText($p, $t)
    Write-Output "SOAK MARKER STRING FIXED -> build89-soakv2r3-20260706"
} else {
    Write-Output "no soakv2-20260706 string found; current marker refs:"
    Get-Content $p | Select-String 'soakv2|MARKER|candidate' -SimpleMatch | Select-Object -First 6 | ForEach-Object { Write-Output ("  " + $_) }
}
