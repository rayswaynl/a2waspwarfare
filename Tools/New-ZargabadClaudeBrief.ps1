param(
	[string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Invoke-Git {
	param([string[]]$GitArgs)
	Push-Location $repoRoot
	try {
		return @(& git @GitArgs 2>$null | ForEach-Object { $_.ToString() })
	} finally {
		Pop-Location
	}
}

function Invoke-Gh {
	param([string[]]$GhArgs)
	Push-Location $repoRoot
	try {
		return @(& gh @GhArgs 2>$null | ForEach-Object { $_.ToString() })
	} catch {
		return @()
	} finally {
		Pop-Location
	}
}

$headShort = (Invoke-Git @("rev-parse", "--short", "HEAD") | Select-Object -First 1)
$headFull = (Invoke-Git @("rev-parse", "HEAD") | Select-Object -First 1)
$branch = (Invoke-Git @("branch", "--show-current") | Select-Object -First 1)
$subject = (Invoke-Git @("log", "-1", "--pretty=%s") | Select-Object -First 1)
$changedFiles = @(Invoke-Git @("show", "--name-only", "--format=", "--no-renames", "HEAD") | Where-Object { $_.Trim().Length -gt 0 })
$dirtyFiles = @(Invoke-Git @("status", "--short") | Where-Object { $_.Trim().Length -gt 0 })
$prInfo = "PR: https://github.com/rayswaynl/a2waspwarfare/pull/9`nPR head: unknown"
$prJson = (Invoke-Gh @("pr", "view", "9", "--json", "url,headRefOid")) -join ""
if ($prJson.Trim().Length -gt 0) {
	try {
		$pr = $prJson | ConvertFrom-Json
		$prInfo = "PR: $($pr.url)`nPR head: $($pr.headRefOid)"
	} catch {
		$prInfo = "PR: https://github.com/rayswaynl/a2waspwarfare/pull/9`nPR head: unknown"
	}
}

$focus = New-Object System.Collections.Generic.List[string]
if ($changedFiles -match 'Zargabad_BlackMarket|New-ZargabadRuntimeReport|Validate-ZargabadRuntimeEvidence|Validate-ZargabadRuntimeReport|Zargabad-Claude-Runtime-Handoff|zargabad-low-pop-test-plan|New-ZargabadClaudeBrief') { $focus.Add("Mystery feature: confirm the armed RPT line after town init, then own Zargabad Airfield and confirm cache surfacing and cleanup-release RPT lines.") }
if ($changedFiles -match 'Zargabad_EdgeGuard|Init_Boundaries|edge|New-ZargabadMapAuditPacket|Validate-ZargabadMission|Validate-ZargabadRuntimeEvidence|New-ZargabadRuntimeReport|Validate-ZargabadRuntimeReport|Zargabad-Claude-Runtime-Handoff|zargabad-low-pop-test-plan|Zargabad-Low-Pop-Release-Audit') { $focus.Add("Side hills/rim: retest named rim test points with `-RequireNamedRimPoints`, outer-rim removal, safe-rim allow evidence, aircraft exemption, and objective-near safe bubbles.") }
if ($changedFiles -match 'Init_Zargabad|Zargabad_RuntimeAudit|mission\.sqm|New-ZargabadMapAuditPacket|Validate-ZargabadMission|Zargabad-Low-Pop-Release-Audit|zargabad-low-pop-test-plan|New-ZargabadClaudeBrief') { $focus.Add("Map/runtime init: retest fortifications, central wall gaps, uncrewed central-wall evidence, town-defense orientation, and runtime audit lines.") }
if ($changedFiles -match 'WDDM|Init_Zargabad|New-ZargabadMapAuditPacket|Zargabad-Claude-Runtime-Handoff|Zargabad-Low-Pop-Release-Audit|Validate-ZargabadMission') { $focus.Add("WDDM fortification review: use https://rayswaynl.github.io/WDDM/ and return exported SQF or coordinate deltas for any proposed base or central-wall changes.") }
if ($changedFiles -match 'Init_Zargabad|New-ZargabadRuntimeReport|Validate-ZargabadRuntimeEvidence|New-ZargabadClaudeBrief|Validate-ZargabadMission') { $focus.Add("Base statics: compare the Init_Zargabad base static runtime positions line and baseFootprint evidence against screenshots/coordinates for facing, manning, arcs, and commander construction space.") }
if ($changedFiles -match 'mission\.sqm|Validate-ZargabadMission|New-ZargabadMapAuditPacket|New-ZargabadRuntimeReport|Validate-ZargabadRuntimeReport|Zargabad-Claude-Runtime-Handoff|Zargabad-Low-Pop-Release-Audit|zargabad-low-pop-test-plan|New-ZargabadClaudeBrief') { $focus.Add("Population/SP-SV placement: compare map-audit Population Flow/value tiers against runtime screenshots or coordinates for city, district/market belt, airfield, farms, outskirts, camps, and any town center that feels misplaced.") }
if ($changedFiles -match 'mission\.sqm|Validate-ZargabadMission|New-ZargabadMapAuditPacket|Zargabad-Low-Pop-Release-Audit|zargabad-low-pop-test-plan') { $focus.Add("Town defenses: retest priority defense mix arcs at city, airfield, North/South District, Northwest Base and Rahim Villa using map-audit defense rows.") }
if ($changedFiles -match 'Init_Common|CommonConstants|Balance|Units_|Vehicles|LoadoutManager|Zargabad_RuntimeAudit|Validate-ZargabadMission') { $focus.Add("Balance/economy: retest factory lists, price multipliers, caps, ranges, and 5v5-style snowball feel.") }
if ($changedFiles -match 'Validate-ZargabadRuntimeEvidence|New-ZargabadRuntimeReport') { $focus.Add("RPT tooling: rerun runtime validator/report with the same required switches as the pass being tested.") }
if ($changedFiles -match 'Zargabad-Claude-Runtime-Handoff|zargabad-low-pop-test-plan|Zargabad-Low-Pop-Release-Audit|New-ZargabadClaudeBrief') { $focus.Add("Coordination: use the current handoff/test plan and paste PASS/FAIL/UNCERTAIN notes with evidence.") }
if ($focus.Count -eq 0) { $focus.Add("Run the normal hosted/dedicated/JIP/HC gates from the handoff; no narrower retest focus was inferred from the last commit.") }

$brief = New-Object System.Collections.Generic.List[string]
$brief.Add("# Zargabad Claude Brief")
$brief.Add("")
$brief.Add("- Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')")
$brief.Add(('- Branch: `{0}`' -f $branch))
$brief.Add(('- Latest commit: `{0}` `{1}`' -f $headShort, $subject))
$brief.Add(('- Full commit: `{0}`' -f $headFull))
foreach ($line in ($prInfo -split "`n")) { $brief.Add("- $line") }
$brief.Add("")
$brief.Add("## Coordination Cadence")
$brief.Add("- Codex should send this fresh brief to Claude after every commit or material mission/tooling change.")
$brief.Add("- Claude should report back after each runtime gate: hosted boot, dedicated boot, JIP, HC, population/SP-SV placement, base safety, central wall/pathing, side hills/rim, economy/factory feel, and mystery feature.")
$brief.Add("- Claude should use `Guides/Zargabad-Completion-Gates.md` as the objective coverage checklist; a runtime PASS is not enough unless the matching objective row has current static and runtime proof.")
$brief.Add("- Claude findings with RPT excerpts, screenshots, coordinates, or repeatable repro steps should be treated as actionable. Codex should patch or retest the mission instead of defending stale assumptions.")
$brief.Add("")
$brief.Add("## What Changed Last")
foreach ($file in $changedFiles) { $brief.Add(('- `{0}`' -f $file)) }
$brief.Add("")
$brief.Add("## Retest Focus")
foreach ($item in $focus) { $brief.Add("- $item") }
$brief.Add("")
$brief.Add("## Required Runtime Commands")
$brief.Add("")
$brief.Add('```powershell')
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadMission.ps1")
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadMapAuditPacket.ps1 -OutputPath `".\zargabad-map-audit.md`"")
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath `"C:\path\to\rpts`"")
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadRuntimeReport.ps1 -RptPath `"C:\path\to\rpts`" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireEdgeGuardSafeAllow -RequireNamedRimPoints -RequireBlackMarket -OutputPath `".\zargabad-runtime-report.md`"")
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeReport.ps1 -ReportPath `".\zargabad-runtime-report.md`" -EvidenceRoot `".\zargabad-evidence`" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireEdgeGuardSafeAllow -RequireNamedRimPoints -RequireBlackMarket")
$brief.Add('```')
$brief.Add("")
$brief.Add("## Stop/Go Rule")
$brief.Add("")
$brief.Add("Codex owns the stop/go call. Claude should keep testing until Codex says the runtime gates are satisfied. Codex should listen to Claude when a finding has RPT excerpts, screenshots, coordinates, or repeatable repro steps.")
$brief.Add("Before any final PASS recommendation, compare the runtime report against `Guides/Zargabad-Completion-Gates.md` and call out any objective row that is still untested, uncertain, or proven only by source inspection.")
$brief.Add("")
$brief.Add("## Evidence To Paste Back")
$brief.Add("")
$brief.Add("- Map audit markdown from `Tools/New-ZargabadMapAuditPacket.ps1` when placement, pathing, sightline, or defense-coordinate notes are involved.")
$brief.Add("- Runtime report markdown from `Tools/New-ZargabadRuntimeReport.ps1`.")
$brief.Add("- RPT paths and exact excerpts for any failing or uncertain validator gate.")
$brief.Add("- The `Init_Zargabad.sqf: Base static runtime positions WEST ... EAST ...` excerpt and ``baseFootprint [35,45,74,78]`` runtime audit evidence when base safety, spawn sightlines, or commander construction space are being judged.")
$brief.Add("- Population/SP-SV placement screenshot filenames plus useful coordinates for the city, airfield, district/market belt, low-density farm/outskirt routes, nearby camps, and any town center that feels off.")
$brief.Add("- Key visual row screenshot filenames plus useful coordinates for base sightlines/statics, wall origin/gaps, town-defense blocking, priority defense arcs, rim abuse, pathing, and economy/factory observations.")
$brief.Add("- If screenshot filenames are used, put real PNG/JPEG files in `.\zargabad-evidence`; Codex validates image signatures with `-EvidenceRoot`.")
$brief.Add("- Clear `PASS`, `FAIL`, or `UNCERTAIN` verdicts for each row in the report's Claude Notes table; `PASS` rows must include row-specific evidence, not blank notes: coordinates or screenshot filenames for spatial checks, RPT excerpts or runtime values for balance/init/feature checks.")
$brief.Add("- Every `PASS` row must also include an explicit Codex action recommendation using one of: keep, tune, revert, investigate, patch, or retest.")
$brief.Add("")
$brief.Add("## Dirty Local State Warning")
if ($dirtyFiles.Count -eq 0) {
	$brief.Add("- Working tree is clean.")
} else {
	$brief.Add("- Working tree has local changes. Do not treat unrelated dirty files as part of the latest commit unless Codex explicitly says so:")
	foreach ($file in $dirtyFiles) { $brief.Add(('  - `{0}`' -f $file)) }
}

$briefText = $brief -join "`r`n"
if ($OutputPath.Trim().Length -gt 0) {
	$parent = Split-Path -Parent $OutputPath
	if ($parent -and -not (Test-Path -LiteralPath $parent)) {
		New-Item -ItemType Directory -Path $parent | Out-Null
	}
	Set-Content -LiteralPath $OutputPath -Value $briefText -Encoding UTF8
	Write-Host "Wrote Zargabad Claude brief: $OutputPath"
} else {
	$briefText
}
