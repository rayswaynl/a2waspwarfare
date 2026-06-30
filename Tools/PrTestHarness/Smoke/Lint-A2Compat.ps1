<#
.SYNOPSIS
    Scan a mission folder's *.sqf files for Arma 3-only idioms that crash or
    silently misbehave on Arma 2 OA, and report file:line findings.

.DESCRIPTION
    Arma 2 OA and Arma 3 share SQF syntax but diverge significantly in
    available commands.  This linter catches the highest-value patterns with
    low false-positive rates, categorised as:

    FAIL  — command is definitively A3-only; any match is a hard blocker.
            Causes exit 1.
    REVIEW — usage is ambiguous (could be A2-legal array-find, or A3 string-find).
            Logged but does not block; exit 0 unless FAIL hits also exist.

    FAIL patterns checked
    ─────────────────────
    - findIf          A3 only (throws "Type Array, expected Code" on A2)
    - params [        Statement-style params command (A2 has no params command)
    - apply {         A3-only array apply
    - select {        Code-block select (A2 select is index-based only)
    - count {         count with a code block over an array (A2 count is size-of)
    - pushBack        A3 only (throws "Type Array, expected Array")
    - deleteAt        A3 only
    - getOrDefault    A3 only
    - isEqualTo       A3 only
    - remoteExec      A3 only
    - findAny         A3 only
    - BIS_fnc_inString  A3 BIS function not present in A2

    REVIEW patterns checked
    ───────────────────────
    - String-find heuristic: variable named *_str / *Lower / *Text (or assigned
      via toLower/format/str on the same line) appearing as the left operand of
        find "
      A2 find on arrays is legal; A2 find on strings is not.
    - Secondary: all occurrences of  find "  anywhere (marked REVIEW so the
      operator can confirm whether the left operand is a string or array).

    NOT flagged (intentional exclusions)
    ─────────────────────────────────────
    - toUpper / toLower   — A2-legal string commands
    - count <array>       — only `count {` (code block) is blocked
    - str                 — A2-legal

    Comment stripping
    ─────────────────
    Single-line (//) and block (/* */) comments are stripped before pattern
    matching to avoid false positives from commented-out code.  String literals
    are also stripped to avoid matching keywords inside strings.

.PARAMETER MissionPath
    Path to the mission folder root.  Use -LiteralPath if the folder name
    contains square brackets (e.g. [55-2hc]warfarev2_073v48co.chernarus).
    Cannot be used together with -MissionLiteralPath.

.PARAMETER MissionLiteralPath
    Literal path to the mission folder (no wildcard expansion).  Use this for
    paths with bracket characters.

.EXAMPLE
    .\Lint-A2Compat.ps1 -MissionLiteralPath "C:\Games\a2waspwarfare\Missions\[55-2hc]warfarev2_073v48co.chernarus"

.EXAMPLE
    .\Lint-A2Compat.ps1 -MissionPath "C:\Games\a2waspwarfare\Missions\warfarev2_073v48co.chernarus"
#>

[CmdletBinding(DefaultParameterSetName = "Path")]
param(
    [Parameter(ParameterSetName = "Path",        Mandatory)][string]$MissionPath,
    [Parameter(ParameterSetName = "LiteralPath", Mandatory)][string]$MissionLiteralPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve the mission root
$missionRoot = if ($PSCmdlet.ParameterSetName -eq "LiteralPath") {
    if (-not (Test-Path -LiteralPath $MissionLiteralPath)) {
        Write-Error "Mission folder not found: $MissionLiteralPath"
        exit 1
    }
    (Resolve-Path -LiteralPath $MissionLiteralPath).Path
} else {
    if (-not (Test-Path -Path $MissionPath)) {
        Write-Error "Mission folder not found: $MissionPath"
        exit 1
    }
    (Resolve-Path -Path $MissionPath).Path
}

Write-Host ""
Write-Host "=== Lint-A2Compat ==="
Write-Host "Mission: $missionRoot"
Write-Host ""

# ---------------------------------------------------------------------------
# Comment / string stripping helpers
# ---------------------------------------------------------------------------
function Strip-CommentAndStrings {
    param(
        [string]$line,
        [ref]$inBlock
    )
    $remaining = $line
    $out       = ""

    while ($remaining.Length -gt 0) {
        if ($inBlock.Value) {
            $end = $remaining.IndexOf("*/")
            if ($end -lt 0) { return $out }        # rest of line is block comment
            $remaining = $remaining.Substring($end + 2)
            $inBlock.Value = $false
            continue
        }

        # Find earliest of: // block-start /*  string-double "  string-single '
        $lineComm  = $remaining.IndexOf("//")
        $blockOpen = $remaining.IndexOf("/*")

        # Prefer the one that appears first
        $first = [int]::MaxValue
        $kind  = "none"
        if ($lineComm  -ge 0 -and $lineComm  -lt $first) { $first = $lineComm;  $kind = "lc" }
        if ($blockOpen -ge 0 -and $blockOpen -lt $first) { $first = $blockOpen; $kind = "bc" }

        switch ($kind) {
            "lc" { $out += $remaining.Substring(0, $first); return $out }
            "bc" { $out += $remaining.Substring(0, $first); $remaining = $remaining.Substring($first + 2); $inBlock.Value = $true; continue }
            default { $out += $remaining; return $out }
        }
    }
    return $out
}

function Strip-StringLiterals {
    param([string]$line)
    # Replace double-quoted strings with empty placeholder ""
    $s = [regex]::Replace($line, '"[^"]*"', '""')
    # Replace single-quoted strings with ''
    $s = [regex]::Replace($s,   "'[^']*'", "''")
    return $s
}

# ---------------------------------------------------------------------------
# FAIL patterns (word-boundary where sensible)
# ---------------------------------------------------------------------------
$failPatterns = [ordered]@{
    # findIf - word boundary
    "findIf"         = [regex]::new('\bfindIf\b',          [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # params followed by [ - the statement-level params command (params with array arg)
    "params ["       = [regex]::new('\bparams\s*\[',        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # apply { - A3-only
    "apply {"        = [regex]::new('\bapply\s*\{',         [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # select { - code-block select
    "select {"       = [regex]::new('\bselect\s*\{',        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # count { - code-block count (NOT `count _array` which is legal)
    "count {"        = [regex]::new('\bcount\s*\{',         [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # pushBack
    "pushBack"       = [regex]::new('\bpushBack\b',         [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # deleteAt
    "deleteAt"       = [regex]::new('\bdeleteAt\b',         [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # getOrDefault
    "getOrDefault"   = [regex]::new('\bgetOrDefault\b',     [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # isEqualTo
    "isEqualTo"      = [regex]::new('\bisEqualTo\b',        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # remoteExec
    "remoteExec"     = [regex]::new('\bremoteExec\b',       [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # findAny
    "findAny"        = [regex]::new('\bfindAny\b',          [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # BIS_fnc_inString
    "BIS_fnc_inString" = [regex]::new('\bBIS_fnc_inString\b', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    # private _x = ...  - A3 inline declaration; A2 needs Private "_x"; / Private ["_x",...]
    # (live-burned 2026-06-12: killed Common_CreateVehicle -> no MHQ -> AI commanders stopped)
    "private _x ="   = [regex]::new('\bprivate\s+_\w+\s*=',  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

# REVIEW pattern — blunt: any  find "  (could be string or array find)
$reviewFindQuote = [regex]::new('find\s+"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

# REVIEW heuristic — variable that looks like a string (named *_str/*Lower/*Text,
# or assigned via toLower/format/str) used before  find "  on the same line.
# Pattern: (<varname>_str|_lower|_text|...) ... find "
$reviewStringFind = [regex]::new(
    '(?i)(?:(?:\b\w+(?:_str|lower|text)\b)|(?:toLower|format|str\s*\(|\bstr\b))\b.*?\bfind\s+"',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------
$failHits   = [System.Collections.Generic.List[string]]::new()
$reviewHits = [System.Collections.Generic.List[string]]::new()

# Enumerate SQF files — use literal-path aware API to handle [ ] in paths
$sqfFiles = [System.IO.Directory]::GetFiles($missionRoot, "*.sqf", [System.IO.SearchOption]::AllDirectories)

Write-Host "Scanning $($sqfFiles.Count) SQF files..."
Write-Host ""

foreach ($filePath in $sqfFiles) {
    $relPath     = $filePath.Substring($missionRoot.Length).TrimStart('\/')
    $lineNum     = 0
    $inBlock     = $false
    $inBlockRef  = [ref]$inBlock

    foreach ($rawLine in [System.IO.File]::ReadLines($filePath)) {
        $lineNum++

        # Strip comments then string literals for pattern matching
        $stripped = Strip-CommentAndStrings $rawLine $inBlockRef
        $code     = Strip-StringLiterals $stripped

        # FAIL checks
        foreach ($entry in $failPatterns.GetEnumerator()) {
            if ($entry.Value.IsMatch($code)) {
                $patName = $entry.Key
                $failHits.Add("FAIL  ${relPath}:${lineNum} [$patName]  $($rawLine.Trim())")
            }
        }

        # REVIEW: string-find heuristic (higher confidence)
        if ($reviewStringFind.IsMatch($code)) {
            $reviewHits.Add("REVIEW-LIKELY  ${relPath}:${lineNum} [string-find heuristic]  $($rawLine.Trim())")
        } elseif ($reviewFindQuote.IsMatch($code)) {
            # Blunt secondary: any find " at all
            $reviewHits.Add("REVIEW  ${relPath}:${lineNum} [find-quote]  $($rawLine.Trim())")
        }
    }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if ($failHits.Count -gt 0) {
    Write-Host "--- FAIL (A3-only commands - hard blockers) ---"
    foreach ($h in $failHits) { Write-Host $h }
    Write-Host ""
}

if ($reviewHits.Count -gt 0) {
    Write-Host "--- REVIEW (string/array find ambiguity - manual check needed) ---"
    foreach ($h in $reviewHits) { Write-Host $h }
    Write-Host ""
}

$failCount   = $failHits.Count
$reviewCount = $reviewHits.Count

Write-Host "=== RESULT ==="
Write-Host "FAIL  : $failCount"
Write-Host "REVIEW: $reviewCount"
Write-Host ""

if ($failCount -gt 0) {
    Write-Host "LINT RESULT: FAIL ($failCount blocker(s))"
    exit 1
} else {
    if ($reviewCount -gt 0) {
        Write-Host "LINT RESULT: PASS with $reviewCount REVIEW item(s) - inspect find-quote usages manually"
    } else {
        Write-Host "LINT RESULT: PASS - no A3-only idioms detected"
    }
    exit 0
}
