#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free tests for Deploy-Wasp.ps1 pure logic (no Pester required, no live box).
.DESCRIPTION
    Dot-sources Deploy-Wasp.ps1 with -LoadFunctionsOnly (defines helpers, skips the deploy
    body) and asserts the naming, build-token and archive-rotation logic. These are the parts
    that decide WHICH file gets deployed and WHICH archive is kept for rollback, so they are
    the parts worth pinning. The live phases (copy/repoint/restart/verify) are integration-only
    and are covered by the runbook + dry-run, not here.
.EXAMPLE
    .\Deploy-Wasp.Tests.ps1     # exits 0 if all pass, 1 otherwise
#>
$ErrorActionPreference = 'Stop'
$deploy = Join-Path $PSScriptRoot 'Deploy-Wasp.ps1'
if (-not (Test-Path -LiteralPath $deploy)) { throw "Deploy-Wasp.ps1 not found next to tests" }

# Load helpers only (this also parse-checks the whole script).
. $deploy -LoadFunctionsOnly

$script:fails = 0
function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

Write-Host "== map table =="
Assert ($MAPS.Keys.Count -eq 3) "three maps registered"
foreach ($k in 'ch','tk','zg') { Assert ($MAPS.ContainsKey($k)) "map '$k' present" }
Assert ($MAPS.ch.Prefix -eq '[55-2hc]warfarev2_073v48co') "ch prefix (55-2hc)"
Assert ($MAPS.tk.Prefix -eq '[61-2hc]warfarev2_073v48co') "tk prefix (61-2hc)"
Assert ($MAPS.zg.Ext -eq 'zargabad') "zg ext"

Write-Host "== mission / pbo naming =="
Assert ((Get-MissionName $MAPS.ch 'cmdcon48aicom') -eq '[55-2hc]warfarev2_073v48co_cmdcon48aicom.chernarus') "ch mission name"
Assert ((Get-PboName     $MAPS.ch 'cmdcon48aicom') -eq '[55-2hc]warfarev2_073v48co_cmdcon48aicom.chernarus.pbo') "ch pbo name"
Assert ((Get-MissionName $MAPS.tk 'b86')           -eq '[61-2hc]warfarev2_073v48co_b86.takistan')             "tk mission name"
Assert ((Get-PboName     $MAPS.zg 'b86')           -eq '[61-2hc]warfarev2_073v48co_b86.zargabad.pbo')         "zg pbo name"

Write-Host "== WASPSCALE build= token (mirrors AI_Commander.sqf parser) =="
# cmdcon token is sliced to the next _ or . ; matches the on-server parse.
Assert ((Get-ExpectedBuildToken 'cmdcon48aicom')                 -eq 'cmdcon48aicom') "cmdcon token, no separator"
Assert ((Get-ExpectedBuildToken 'foo_cmdcon36aicom.chernarus')   -eq 'cmdcon36aicom') "cmdcon token sliced at . after mixed prefix"
Assert ((Get-ExpectedBuildToken 'cmdcon42_extra')                -eq 'cmdcon42')      "cmdcon token sliced at _"
Assert ((Get-ExpectedBuildToken 'b86')                           -eq 'b86')           "no cmdcon -> full tag (build= falls back to mission name)"

Write-Host "== archive rotation (rollback retention) =="
# names carry a sortable yyyyMMdd-HHmmss prefix; prune keeps the newest N.
$names = @(
    '20260610-101500__a.pbo',
    '20260611-101500__b.pbo',
    '20260612-101500__c.pbo',
    '20260613-101500__d.pbo',
    '20260614-101500__e.pbo',
    '20260615-101500__f.pbo'
)
$prune3 = @(Get-ArchivesToPrune $names 5)
Assert ($prune3.Count -eq 1 -and $prune3[0] -eq '20260610-101500__a.pbo') "keep 5 -> prune oldest 1"
$prune2 = @(Get-ArchivesToPrune $names 2)
Assert ($prune2.Count -eq 4 -and ($prune2 -contains '20260613-101500__d.pbo') -and -not ($prune2 -contains '20260614-101500__e.pbo')) "keep 2 -> prune oldest 4, retain newest 2"
Assert (@(Get-ArchivesToPrune $names 10).Count -eq 0) "keep more than present -> prune nothing"
Assert (@(Get-ArchivesToPrune @() 5).Count -eq 0) "empty archive -> prune nothing"
Assert (@(Get-ArchivesToPrune $names 0).Count -eq 6) "keep 0 -> prune all"

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL PASS" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) FAILED" -ForegroundColor Red; exit 1 }
