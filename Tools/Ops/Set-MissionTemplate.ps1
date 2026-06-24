#requires -Version 5.1
<#
.SYNOPSIS
    Idempotently repoint the active mission `template = "...";` line in an Arma 2 OA
    dedicated-server cfg (e.g. server.cfg). Safe to re-run against a build that is
    already deployed: an unchanged template is reported as SUCCESS, not an error.

.DESCRIPTION
    "Freshname"-style deploy scripts all hand-copy the same cfg-repoint step: read the
    cfg, regex-replace the mission `template = "<old>"` line with the new PBO name, write
    it back. The historical hand-copied guard was:

        $new = $raw -replace <pattern>, ('template = "' + $MissionName + '";')
        if ($new -eq $raw) { throw 'template regex no match' }   # <-- BUG

    That `throw` fires whenever the replacement is a NO-OP — which includes the common,
    harmless case of re-deploying the SAME build (template already correct). Because the
    deploy has already stopped the server + HCs by that point, the throw leaves the
    server DOWN. (Observed live 2026-06-23: a same-build redeploy stranded the server.)

    This helper fixes the guard properly by distinguishing the three cases:
      - pattern matches NOTHING           -> genuine error (template missing/renamed) -> throw
      - pattern matches, value unchanged  -> already correct -> success, no write
      - pattern matches, value differs    -> rewrite the line

    SAFE BY DEFAULT: reports what it would do unless -Apply is passed.

    Host-agnostic (pass the cfg path + target mission name; nothing here is box-specific).
    Centralised so deploy scripts call ONE correct implementation instead of re-copying
    the buggy guard -- same motivation as Restart-MiksuuChain.ps1 for the restart sequence.

.PARAMETER CfgPath
    Path to the server cfg file containing the `class Missions { ... template = "..."; }` block.

.PARAMETER MissionName
    Target mission template value WITHOUT surrounding quotes, e.g.
    [55-2hc]warfarev2_073v48co_b742aicom.chernarus

.PARAMETER Pattern
    Regex identifying WHICH `template = "...";` line to repoint. Default targets the WASP
    Chernarus mission family (`[55-2hc]...chernarus`) and will not touch a Takistan
    (`[61-2hc]...takistan`) or other-named template line. Override for other maps. The
    default is line-anchored (`(?m)(?<=^[ \t]*)`) so a commented-out `// template = ...`
    line is NOT matched - only a live directive at the start of a line. The pattern
    should match exactly the one line you intend to change.

.PARAMETER Apply
    Actually write the cfg. Without this switch the script only reports (dry run).

.OUTPUTS
    [pscustomobject] @{ CfgPath; MissionName; Matches; AlreadyCorrect; Changed; Applied }

.EXAMPLE
    .\Set-MissionTemplate.ps1 -CfgPath C:\WASP\server.cfg -MissionName '[55-2hc]warfarev2_073v48co_b742aicom.chernarus'
    # dry run - reports whether a change is needed, writes nothing

.EXAMPLE
    .\Set-MissionTemplate.ps1 -CfgPath C:\WASP\server.cfg -MissionName '[55-2hc]warfarev2_073v48co_b742aicom.chernarus' -Apply
    # applies the repoint; a no-op (already correct) exits 0 without throwing

.NOTES
    PowerShell 5.1-compatible (box runs PS 5.1). Reads and writes the cfg as ISO-8859-1
    (Latin-1) - a byte-preserving round-trip that retains every original byte (line
    endings, any extended characters) and changes only the matched ASCII template line.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CfgPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$MissionName,
    [string]$Pattern = '(?m)(?<=^[ \t]*)template\s*=\s*"\[55-2hc\][^"]*chernarus[^"]*"\s*;',
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $CfgPath)) { throw "cfg not found: $CfgPath" }

# Read & write as ISO-8859-1 (Latin-1): a byte-preserving round-trip (every byte 0-255
# maps 1:1 to a char and back), so any extended characters elsewhere in the cfg
# (e.g. an accented hostName) are retained exactly - only the matched ASCII line changes.
$enc = [System.Text.Encoding]::GetEncoding(28591)
$raw = [System.IO.File]::ReadAllText($CfgPath, $enc)

$tplMatches = [regex]::Matches($raw, $Pattern)
if ($tplMatches.Count -eq 0) {
    throw "no mission template line matching /$Pattern/ found in '$CfgPath' - refusing to proceed (template line missing or renamed). This is a genuine error, distinct from an already-correct no-op."
}
if ($tplMatches.Count -gt 1) {
    Write-Warning "[Set-MissionTemplate] pattern matched $($tplMatches.Count) template lines in '$CfgPath'; all will be repointed to the same mission."
}

$newLine = 'template = "' + $MissionName + '";'
# Escape '$' so .NET treats the mission name literally: in a regex replacement string a
# bare '$' introduces a backreference ($1, $&, ...). Mission names have no '$' today, but
# this keeps the shared helper safe for any caller.
$replacement = $newLine.Replace('$', '$$')
$new = [regex]::Replace($raw, $Pattern, $replacement)

$alreadyCorrect = ($new -eq $raw)
$applied = $false

if ($alreadyCorrect) {
    Write-Host "[Set-MissionTemplate] template already = '$MissionName' ($($tplMatches.Count) match) - no change needed (idempotent)."
} elseif ($Apply) {
    [System.IO.File]::WriteAllText($CfgPath, $new, $enc)
    $applied = $true
    Write-Host "[Set-MissionTemplate] template repointed to '$MissionName' ($($tplMatches.Count) match) - cfg written."
} else {
    Write-Host "[Set-MissionTemplate] DRY RUN: would repoint template to '$MissionName' ($($tplMatches.Count) match). Pass -Apply to write."
}

[pscustomobject]@{
    CfgPath        = $CfgPath
    MissionName    = $MissionName
    Matches        = $tplMatches.Count
    AlreadyCorrect = $alreadyCorrect
    Changed        = (-not $alreadyCorrect)
    Applied        = $applied
}
