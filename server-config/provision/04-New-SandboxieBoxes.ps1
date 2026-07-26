# 04-New-SandboxieBoxes.ps1 - ensure Sandboxie boxes HC2/HC3/HC4 exist (idempotent)
# If the synced C:\WASP carried an old Sandboxie.ini with a proven [HC2] section it is
# NOT read automatically - this script edits the LIVE ini of the local install.
# Clones the local [HC2] for HC3/HC4 when present, else writes a minimal section
# (defaults + templates from GlobalSettings apply; verify once in the Plus UI).
# PowerShell 5.1 compatible. Run elevated.
$ErrorActionPreference = 'Stop'

$iniCandidates = @(
    'C:\ProgramData\Sandboxie-Plus\Sandboxie.ini',
    'C:\Windows\Sandboxie.ini'
)
$ini = $null
foreach ($c in $iniCandidates) { if ((Test-Path $c) -and ($null -eq $ini)) { $ini = $c } }
if ($null -eq $ini) {
    # A fresh install does not write Sandboxie.ini until the GUI runs once, which is not
    # possible over a service session. Seed it with the same minimal structure the proven
    # live box uses (verified 2026-07-25: UTF-16 LE + BOM, template list + per-box sections).
    $ini = 'C:\Windows\Sandboxie.ini'
    Write-Host ("Sandboxie.ini absent - seeding {0}" -f $ini)
    $seed = @(
        '#',
        '# Sandboxie configuration file',
        '#',
        '',
        '[GlobalSettings]',
        'Template=WindowsRasMan',
        'Template=WindowsLive',
        'Template=Edge_Fix',
        'Template=OfficeLicensing',
        ''
    ) -join "`r`n"
    [System.IO.File]::WriteAllText($ini, $seed + "`r`n", [System.Text.Encoding]::Unicode)
}
Write-Host ("Using ini: {0}" -f $ini)

$raw = Get-Content -LiteralPath $ini -Raw
$nl = "`r`n"

function Get-Section {
    Param([String]$Text, [String]$Name)
    # Pattern built by concatenation: a double-quoted "$(...)" would be evaluated by
    # PowerShell as a subexpression instead of reaching the regex engine.
    $pattern = '(?ms)^\[' + [Regex]::Escape($Name) + '\]\r?\n(.*?)(?=^\[|\z)'
    $m = [Regex]::Match($Text, $pattern)
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

$hc2 = Get-Section -Text $raw -Name 'HC2'
# Minimal section matches the PROVEN live [HC2] on the old box byte-for-byte
# (read 2026-07-25: Enabled=y / ConfigLevel=10 / AutoRecover=n - nothing else needed
# for a sandboxed Steam + A2OA HC).
$minimal = $nl + 'Enabled=y' + $nl + 'ConfigLevel=10' + $nl + 'AutoRecover=n' + $nl

$changed = $false
foreach ($box in @('HC2', 'HC3', 'HC4')) {
    $existing = Get-Section -Text $raw -Name $box
    if ($null -ne $existing) { Write-Host ("OK: [{0}] already present." -f $box); continue }
    if (($null -ne $hc2) -and ($box -ne 'HC2')) { $body = $hc2 } else { $body = $minimal }
    $raw = $raw.TrimEnd() + $nl + $nl + ('[' + $box + ']') + $body
    $changed = $true
    Write-Host ("ADDED: [{0}] ({1})" -f $box, $(if (($null -ne $hc2) -and ($box -ne 'HC2')) { 'cloned from HC2' } else { 'minimal defaults' }))
}

if ($changed) {
    Copy-Item -LiteralPath $ini -Destination ($ini + '.bak-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    # Preserve the ini's original encoding: UTF-16 LE BOM -> Unicode, UTF-8 BOM -> UTF8,
    # anything else -> ANSI (Sandboxie accepts UTF-16 or ANSI; never introduce a new BOM).
    $bytes = [System.IO.File]::ReadAllBytes($ini)
    $enc = 'Default'
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $enc = 'Unicode' }
    elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $enc = 'UTF8' }
    Set-Content -LiteralPath $ini -Value $raw -Encoding $enc
    $start = 'C:\Program Files\Sandboxie-Plus\Start.exe'
    if (Test-Path $start) { & $start /reload; Write-Host 'Sandboxie config reloaded.' }
    else { Write-Warning 'Start.exe not found - reload Sandboxie config manually.' }
} else {
    Write-Host 'No changes needed.'
}
Write-Host 'DONE 04-New-SandboxieBoxes'
