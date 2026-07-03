#requires -Version 5.1
<#
.SYNOPSIS
    Dependency-free fixture tests for Test-WaspSlotCountConsistency.ps1.
.EXAMPLE
    .\Test-WaspSlotCountConsistency.Tests.ps1
#>
$ErrorActionPreference = "Stop"
$helper = Join-Path $PSScriptRoot "Test-WaspSlotCountConsistency.ps1"
$script:fails = 0

function Assert($cond, $name) {
    if ($cond) { Write-Host "  PASS  $name" }
    else { Write-Host "  FAIL  $name" -ForegroundColor Red; $script:fails++ }
}

function New-TerrainFixture {
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$MissionRoot,
        [Parameter(Mandatory)] [int]$MaxPlayers,
        [Parameter(Mandatory)] [int]$SlotCount
    )

    $root = Join-Path $RepoRoot $MissionRoot
    New-Item -ItemType Directory -Force -Path $root | Out-Null

    Set-Content -LiteralPath (Join-Path $root "version.sqf.template") `
        -Value ("#define WF_MAXPLAYERS {0}`r`n" -f $MaxPlayers) `
        -Encoding ASCII

    $slotBlocks = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $SlotCount; $i++) {
        $slotBlocks.Add(@"
        class Item$i
        {
            player="PLAY CDG";
        };
"@)
    }

    $sqm = @"
class Mission
{
    class Groups
    {
        items=$SlotCount;
        // player="PLAY CDG";
        class NonSlot
        {
            class Vehicles
            {
                items=1;
                class Item0 {};
            };
        };
$($slotBlocks -join "`r`n")
    };
};
"@

    Set-Content -LiteralPath (Join-Path $root "mission.sqm") -Value $sqm -Encoding ASCII
}

function New-SlotFixtureRepo {
    param(
        [int]$ChernarusSlots,
        [int]$ChernarusMax,
        [int]$TakistanSlots,
        [int]$TakistanMax,
        [int]$ZargabadSlots,
        [int]$ZargabadMax
    )

    $repoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("wasp-slot-fixture-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null

    New-TerrainFixture $repoRoot "Missions\[55-2hc]warfarev2_073v48co.chernarus" $ChernarusMax $ChernarusSlots
    New-TerrainFixture $repoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan" $TakistanMax $TakistanSlots
    New-TerrainFixture $repoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad" $ZargabadMax $ZargabadSlots

    return $repoRoot
}

function Invoke-SlotCheck {
    param([Parameter(Mandatory)] [string]$RepoRoot)

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $helper -RepoRoot $RepoRoot 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output = ($output -join "`n")
    }
}

Write-Host "TEST 1: matching fixtures pass and commented player lines are ignored"
$repo = New-SlotFixtureRepo 2 2 1 1 3 3
try {
    $result = Invoke-SlotCheck $repo
    Assert ($result.ExitCode -eq 0) "T1 exits successfully"
    Assert ($result.Output -match 'PASS\s+Chernarus: WF_MAXPLAYERS=2, playable slots=2') "T1 Chernarus match reported"
    Assert ($result.Output -match 'PASS\s+Takistan: WF_MAXPLAYERS=1, playable slots=1') "T1 Takistan match reported"
    Assert ($result.Output -match 'PASS\s+Zargabad: WF_MAXPLAYERS=3, playable slots=3') "T1 Zargabad match reported"
} finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}

Write-Host "TEST 2: mismatched fixture exits nonzero and names the drifting terrain"
$repo = New-SlotFixtureRepo 2 2 1 1 3 5
try {
    $result = Invoke-SlotCheck $repo
    Assert ($result.ExitCode -eq 1) "T2 exits with mismatch"
    Assert ($result.Output -match 'FAIL\s+Zargabad: WF_MAXPLAYERS=5, playable slots=3') "T2 reports Zargabad drift"
    Assert ($result.Output -match 'Test-WaspSlotCountConsistency: 1 mismatch') "T2 reports mismatch total"
} finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}

Write-Host ""
if ($script:fails -eq 0) { Write-Host "ALL TESTS PASSED" -ForegroundColor Green; exit 0 }
else { Write-Host "$($script:fails) TEST(S) FAILED" -ForegroundColor Red; exit 1 }
