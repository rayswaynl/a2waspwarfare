$p = 'C:\WASP\incoming\soak1-restore.ps1'
$t = [IO.File]::ReadAllText($p)
$orig = $t
$t = $t -replace 'cc48a-ch\.pbo', 'rc12-ch.pbo'
$t = $t -replace 'cc48a-tk\.pbo', 'rc12-tk.pbo'
$t = $t -replace 'cc48a-zg\.pbo', 'rc12-zg.pbo'
$t = $t -replace 'cmdcon48a', 'cmdconRC12'
$t = $t -replace 'release-1\.0-rc2-20260706', 'release-1.0-rc3-20260707'
if ($t -ne $orig) {
    [IO.File]::WriteAllText($p, $t)
    Write-Output "RESTORE-TARGET REPOINTED to rc12"
} else {
    Write-Output "NO CHANGES MADE - inspect manually:"
}
# show the resulting swap lines for verification
Get-Content $p | Select-String 'rc12|cc48a|cmdcon|marker|release-1.0' -SimpleMatch | Select-Object -First 10 | ForEach-Object { Write-Output ("LINE: " + $_) }
