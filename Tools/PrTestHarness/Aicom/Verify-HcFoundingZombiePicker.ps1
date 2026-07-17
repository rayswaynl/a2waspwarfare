<#
.SYNOPSIS
    Post-merge verification gate for the "HC founding zombie-picker" fix
    (Server_PickLeastLoadedHC.sqf / Server_DelegateAITownHeadless.sqf /
    Server_DelegateAIStaticDefenceHeadless.sqf / Common_SendToClient.sqf,
    2026-07-17).

.DESCRIPTION
    Grades a server RPT (+ optional HC RPT) against the exact symptom this
    fix targets: WEST/EAST AICOM team-founding dispatched but never
    acknowledged (foundedTeams stuck at 0 while HCDISPATCH keeps firing).

    This is a READ-ONLY analyzer over RPT text. It does not launch a server,
    does not touch the live box, and makes no deploy/runtime claim by itself
    -- it only grades whatever RPT you feed it. See "HOW TO ACTUALLY PROVE
    THE FIX" below for the box-lab procedure this script is meant to grade
    the output of.

    Signals read (server RPT):
      AICOMSTAT|v2|EVENT|<side>|<min>|HCDISPATCH|pending=N|founded=N|...
      AICOMSTAT|v2|EVENT|<side>|<min>|TEAM_FOUNDED|via=HC|...
      SENDTOCLIENT|v1|DROPPED|func=<f>|owner=0-or-negative   (NEW, this fix)

    Signals read (HC RPT, optional but recommended):
      Common_RunCommanderTeam.sqf: [...] commander team spawned (...)
      Server_HandleSpecial.sqf: [sideID ...] HC commander team ... registered

    VERDICT
      PASS         -- at least one HCDISPATCH window shows founded>0 (i.e.
                       the ack landed for real), OR "commander team spawned"
                       appears in the HC RPT.
      FAIL         -- HCDISPATCH fired (dispatch attempts happened) but
                       founded stayed 0 for the ENTIRE scored window AND no
                       "commander team spawned" ever appears in the HC RPT --
                       i.e. the exact pre-fix symptom, unchanged.
      INCONCLUSIVE -- no HCDISPATCH lines at all (no live HC this session /
                       AICOM never tried to found a team) -- this RPT cannot
                       grade the fix either way; pull a longer session.

    If SENDTOCLIENT|v1|DROPPED appears at all, it is printed verbatim --
    that is direct, first-time-ever RPT proof that a delegate PVF was
    dropped for owner<=0 (the exact zombie-owner mechanism this fix
    excludes from the picker). Before this fix shipped, this exact drop was
    100% silent and unobservable from RPT -- which is why two prior
    diagnosis lanes (aicom-idle-diagnosis-20260717,
    founding-regression-bisect-20260717) could establish "0 acks land" but
    not "why", down to a live-HC-debug-required dead end.

.PARAMETER ServerRpt
    Path to arma2oaserver.RPT.

.PARAMETER HcRpt
    Optional path to the HC's ArmA2OA.RPT (recommended -- adds the
    "commander team spawned" positive-confirmation signal).

.PARAMETER Json
    Emit a machine-readable verdict object instead of the text report.

.PARAMETER SelfTest
    Run the grading logic against three synthetic in-memory RPT fixtures
    (FAIL case / PASS case / INCONCLUSIVE case) and confirm each grades as
    expected. Does not need a real RPT, a live box, or a local Arma
    install -- proves the ANALYZER is correct so a future real RPT pull can
    be trusted. Exit 0 if all three synthetic cases grade correctly.

.EXAMPLE
    # After the fix has soaked on the test box, pull both RPTs and grade:
    scp "Administrator@<test-box-ip>:C:/Users/Administrator/AppData/Local/ArmA 2 Other Profiles/*/arma2oaserver.RPT" ./arma2oaserver.RPT
    scp "Administrator@<test-box-ip>:C:/Users/Administrator/AppData/Local/ArmA 2 OA/ArmA2OA.RPT" ./ArmA2OA.RPT
    pwsh Tools/PrTestHarness/Aicom/Verify-HcFoundingZombiePicker.ps1 -ServerRpt ./arma2oaserver.RPT -HcRpt ./ArmA2OA.RPT

.EXAMPLE
    # Prove the analyzer itself is correct (no live box needed):
    pwsh Tools/PrTestHarness/Aicom/Verify-HcFoundingZombiePicker.ps1 -SelfTest

.NOTES
    Part of the wasp-hc-founding-fix-20260717 lane (Fleet card
    wasp-hc-founding-fix-20260717). Read-only; never modifies the mission,
    HC architecture, or the box. Companion to Score-AicomRounds.ps1 /
    Tools/Soak/analyze_soak.py -- this script narrows to ONE question
    (did delegate-aicom-team founding actually complete this session)
    instead of full-round scoring.
#>

[CmdletBinding(DefaultParameterSetName = "File")]
param(
    [Parameter(ParameterSetName = "File")]
    [string]$ServerRpt = "",

    [Parameter(ParameterSetName = "File")]
    [string]$HcRpt = "",

    [switch]$Json,
    [switch]$SelfTest
)

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

function Read-RptLines([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "RPT not found: $path" }
    # RPTs are typically ISO-8859-1 / ANSI, not UTF-8; match the convention
    # used elsewhere in this tree (aicom-watch.ps1 Run-SelfTest).
    $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::GetEncoding("iso-8859-1"))
        try {
            $lines = New-Object System.Collections.Generic.List[string]
            while (-not $reader.EndOfStream) { $lines.Add($reader.ReadLine()) }
            return $lines
        } finally { $reader.Dispose() }
    } finally { $fs.Dispose() }
}

function Grade-Session([string[]]$serverLines, [string[]]$hcLines) {
    $hcDispatchLines = @($serverLines | Where-Object { $_ -match '\|HCDISPATCH\|' })
    $droppedLines    = @($serverLines | Where-Object { $_ -match '^SENDTOCLIENT\|v1\|DROPPED\|' })
    $foundedPositive = @($hcDispatchLines | Where-Object { $_ -match 'founded=(\d+)' -and [int]$Matches[1] -gt 0 })
    $teamFoundedHc   = @($serverLines | Where-Object { $_ -match '\|TEAM_FOUNDED\|via=HC\|' })
    $hcSpawnedLines  = @($hcLines | Where-Object { $_ -match 'Common_RunCommanderTeam\.sqf:.*commander team spawned' })
    $hcRegisteredLines = @($serverLines | Where-Object { $_ -match 'Server_HandleSpecial\.sqf:.*HC commander team .* registered' })

    $ackLanded = ($foundedPositive.Count -gt 0) -or ($hcSpawnedLines.Count -gt 0) -or ($hcRegisteredLines.Count -gt 0)

    if ($hcDispatchLines.Count -eq 0) {
        $verdict = "INCONCLUSIVE"
        $reason  = "No HCDISPATCH lines found -- AICOM never attempted delegate-aicom-team founding this session (no live HC, or founding target already met). This RPT cannot confirm or refute the fix."
    } elseif ($ackLanded) {
        $verdict = "PASS"
        $reason  = "Ack landed: " + `
            ($(if ($foundedPositive.Count -gt 0) { "$($foundedPositive.Count) HCDISPATCH line(s) show founded>0; " } else { "" })) + `
            ($(if ($hcSpawnedLines.Count -gt 0) { "$($hcSpawnedLines.Count) 'commander team spawned' line(s) on the HC; " } else { "" })) + `
            ($(if ($hcRegisteredLines.Count -gt 0) { "$($hcRegisteredLines.Count) 'HC commander team registered' line(s) on the server." } else { "" }))
    } else {
        $verdict = "FAIL"
        $reason  = "$($hcDispatchLines.Count) HCDISPATCH line(s) fired but founded stayed 0 for the whole window and no HC-side spawn/registration confirmation exists -- this is the exact pre-fix symptom (foundedTeams=0, ack never lands)."
    }

    [PSCustomObject]@{
        Verdict              = $verdict
        Reason               = $reason
        HcDispatchCount      = $hcDispatchLines.Count
        FoundedPositiveCount = $foundedPositive.Count
        TeamFoundedHcCount   = $teamFoundedHc.Count
        HcSpawnedCount       = $hcSpawnedLines.Count
        HcRegisteredCount    = $hcRegisteredLines.Count
        DroppedCount         = $droppedLines.Count
        DroppedLines         = $droppedLines
    }
}

function Print-Report($result) {
    Write-Host ""
    Write-Host "=== HC founding zombie-picker verification ===" -ForegroundColor Cyan
    Write-Host ("  HCDISPATCH lines           : {0}" -f $result.HcDispatchCount)
    Write-Host ("  HCDISPATCH founded>0       : {0}" -f $result.FoundedPositiveCount)
    Write-Host ("  TEAM_FOUNDED via=HC        : {0}" -f $result.TeamFoundedHcCount)
    Write-Host ("  HC 'commander team spawned': {0}" -f $result.HcSpawnedCount)
    Write-Host ("  Server 'HC team registered': {0}" -f $result.HcRegisteredCount)
    Write-Host ("  SENDTOCLIENT DROPPED (new) : {0}" -f $result.DroppedCount)
    if ($result.DroppedCount -gt 0) {
        Write-Host "  --- DROPPED lines (proves the zombie-owner drop happened and was excluded) ---" -ForegroundColor Yellow
        $result.DroppedLines | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
    }
    Write-Host ""
    $color = switch ($result.Verdict) { "PASS" { "Green" } "FAIL" { "Red" } default { "Yellow" } }
    Write-Host ("VERDICT: {0}" -f $result.Verdict) -ForegroundColor $color
    Write-Host ("  {0}" -f $result.Reason)
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Self-test: synthetic fixtures, no live RPT needed.
# ---------------------------------------------------------------------------
function Run-SelfTest {
    $failing = @(
        'AICOMSTAT|v2|EVENT|WEST|1|HCDISPATCH|pending=1|founded=0|target=10|pendingAgeSec=5',
        'AICOMSTAT|v2|EVENT|EAST|1|HCDISPATCH|pending=2|founded=0|target=10|pendingAgeSec=8',
        'AICOMSTAT|v2|EVENT|WEST|4|HCDISPATCH_REAP|pending->9|reason=ack-timeout',
        'AICOMSTAT|v2|EVENT|WEST|5|HCDISPATCH|pending=10|founded=0|target=10|pendingAgeSec=270'
    )
    $passing = @(
        'AICOMSTAT|v2|EVENT|WEST|1|HCDISPATCH|pending=1|founded=0|target=10|pendingAgeSec=5',
        'AICOMSTAT|v2|EVENT|WEST|2|TEAM_FOUNDED|via=HC|template=2|class=infantry|cost=6000',
        'Server_HandleSpecial.sqf: [sideID 1] HC commander team 0x123 registered (6 units).',
        'AICOMSTAT|v2|EVENT|WEST|3|HCDISPATCH|pending=1|founded=1|target=10|pendingAgeSec=2'
    )
    $inconclusive = @(
        'AICOMSTAT|v2|EVENT|WEST|1|SNAP|myTowns=12|enHQ=0',
        'WASPSTAT|v1|1|ROUNDEND|winner=west'
    )
    $droppedProof = @(
        'AICOMSTAT|v2|EVENT|WEST|1|HCDISPATCH|pending=1|founded=0|target=10|pendingAgeSec=5',
        'SENDTOCLIENT|v1|DROPPED|func=HandleSpecial|owner=0-or-negative',
        'AICOMSTAT|v2|EVENT|WEST|5|HCDISPATCH|pending=1|founded=0|target=10|pendingAgeSec=270'
    )

    $cases = @(
        @{ Name = "FAIL case (pre-fix symptom: dispatched, never founded)"; Lines = $failing;      Expect = "FAIL" },
        @{ Name = "PASS case (ack lands: founded>0 / spawn confirmed)";     Lines = $passing;       Expect = "PASS" },
        @{ Name = "INCONCLUSIVE case (no HCDISPATCH at all)";               Lines = $inconclusive;   Expect = "INCONCLUSIVE" },
        @{ Name = "FAIL case + new DROPPED proof line surfaces";            Lines = $droppedProof;   Expect = "FAIL" }
    )

    $allOk = $true
    Write-Host "=== Verify-HcFoundingZombiePicker.ps1 self-test ===" -ForegroundColor Cyan
    foreach ($c in $cases) {
        $r = Grade-Session -serverLines $c.Lines -hcLines @()
        $ok = ($r.Verdict -eq $c.Expect)
        $allOk = $allOk -and $ok
        $status = if ($ok) { "PASS" } else { "FAIL" }
        $color  = if ($ok) { "Green" } else { "Red" }
        Write-Host ("  [{0}] {1} -> graded {2} (expected {3})" -f $status, $c.Name, $r.Verdict, $c.Expect) -ForegroundColor $color
        if ($c.Name -like "*DROPPED*" -and $r.DroppedCount -ne 1) {
            Write-Host "    DROPPED-line capture did not fire as expected." -ForegroundColor Red
            $allOk = $false
        }
    }
    Write-Host ""
    if ($allOk) {
        Write-Host "SELF-TEST PASSED (analyzer logic verified against synthetic fixtures)" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "SELF-TEST FAILED" -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if ($SelfTest) { Run-SelfTest }

if ($ServerRpt -eq "") {
    Write-Host "Usage: Verify-HcFoundingZombiePicker.ps1 -ServerRpt <path> [-HcRpt <path>] [-Json]" -ForegroundColor Yellow
    Write-Host "       Verify-HcFoundingZombiePicker.ps1 -SelfTest" -ForegroundColor Yellow
    exit 2
}

$serverLines = Read-RptLines $ServerRpt
$hcLines = if ($HcRpt -ne "") { Read-RptLines $HcRpt } else { @() }

$result = Grade-Session -serverLines $serverLines -hcLines $hcLines

if ($Json) {
    $result | ConvertTo-Json -Depth 4
} else {
    Print-Report $result
}

if ($result.Verdict -eq "FAIL") { exit 1 } else { exit 0 }
