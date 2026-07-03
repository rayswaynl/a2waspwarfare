#requires -Version 5.1
<#
.SYNOPSIS
    Validates that AGENTS.md and CLAUDE.md are in sync and that all three core agent
    docs carry the expected GUIDE-REV stamp.

.DESCRIPTION
    AGENTS.md and CLAUDE.md must be byte-identical below line 1 (the first line may
    differ to identify the file). Both files and docs/AGENT-HANDBOOK.md must contain
    the GUIDE-REV string "GR-2026-07-03a".

    Exits 0 on PASS, 1 on any failure.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
$script:fails = 0

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}

$GUIDE_REV = "GR-2026-07-03a"

$agentsPath   = Join-Path $RepoRoot "AGENTS.md"
$claudePath   = Join-Path $RepoRoot "CLAUDE.md"
$handbookPath = Join-Path $RepoRoot "docs\AGENT-HANDBOOK.md"

function Read-RequiredFile {
    param([Parameter(Mandatory)] [string]$Path)
    if (!(Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw
}

# ── 1. Existence checks ────────────────────────────────────────────────────────
foreach ($p in @($agentsPath, $claudePath, $handbookPath)) {
    if (!(Test-Path -LiteralPath $p)) {
        Write-Host ("  FAIL  Missing required file: {0}" -f $p) -ForegroundColor Red
        $script:fails++
    }
}

if ($script:fails -gt 0) {
    Write-Host ""
    Write-Host ("Test-AgentDocsSync: {0} failure(s)" -f $script:fails) -ForegroundColor Red
    exit 1
}

# ── 2. GUIDE-REV stamp present in all three docs ──────────────────────────────
$docsToCheck = @(
    [pscustomobject]@{ Label = "AGENTS.md";           Path = $agentsPath   },
    [pscustomobject]@{ Label = "CLAUDE.md";            Path = $claudePath   },
    [pscustomobject]@{ Label = "docs/AGENT-HANDBOOK.md"; Path = $handbookPath }
)

foreach ($doc in $docsToCheck) {
    $content = Read-RequiredFile $doc.Path
    if ($content -notmatch [regex]::Escape($GUIDE_REV)) {
        Write-Host ("  FAIL  GUIDE-REV '{0}' not found in: {1}" -f $GUIDE_REV, $doc.Label) -ForegroundColor Red
        $script:fails++
    } else {
        Write-Host ("  PASS  GUIDE-REV found in {0}" -f $doc.Label)
    }
}

# ── 3. AGENTS.md and CLAUDE.md are byte-identical below line 1 ────────────────
$agentsLines  = (Read-RequiredFile $agentsPath)  -split "\r?\n"
$claudeLines  = (Read-RequiredFile $claudePath)  -split "\r?\n"

$agentsTail = $agentsLines | Select-Object -Skip 1
$claudeTail = $claudeLines | Select-Object -Skip 1

$agentsTailText = $agentsTail -join "`n"
$claudeTailText = $claudeTail -join "`n"

if ($agentsTailText -ne $claudeTailText) {
    Write-Host "  FAIL  AGENTS.md and CLAUDE.md differ below line 1" -ForegroundColor Red
    # Show first differing line for quick diagnosis
    $maxLen = [Math]::Max($agentsTail.Count, $claudeTail.Count)
    for ($i = 0; $i -lt $maxLen; $i++) {
        $a = if ($i -lt $agentsTail.Count) { $agentsTail[$i] } else { "<missing>" }
        $c = if ($i -lt $claudeTail.Count) { $claudeTail[$i] } else { "<missing>" }
        if ($a -ne $c) {
            Write-Host ("         First diff at line {0}:" -f ($i + 2))
            Write-Host ("         AGENTS.md: {0}" -f $a)
            Write-Host ("         CLAUDE.md:  {0}" -f $c)
            break
        }
    }
    $script:fails++
} else {
    Write-Host "  PASS  AGENTS.md and CLAUDE.md are identical below line 1"
}

# ── Result ────────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:fails -eq 0) {
    Write-Host "Test-AgentDocsSync: PASS" -ForegroundColor Green
    exit 0
}

Write-Host ("Test-AgentDocsSync: {0} failure(s)" -f $script:fails) -ForegroundColor Red
exit 1
