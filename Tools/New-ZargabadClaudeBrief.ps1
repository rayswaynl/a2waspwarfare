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
if ($changedFiles -match 'Zargabad_BlackMarket') { $focus.Add("Mystery feature: own Zargabad Airfield, confirm cache surfacing and cleanup-release RPT lines.") }
if ($changedFiles -match 'Zargabad_EdgeGuard|Init_Boundaries|edge') { $focus.Add("Side hills/rim: retest outer-rim removal, aircraft exemption, and objective-near safe bubbles.") }
if ($changedFiles -match 'Init_Zargabad|Zargabad_RuntimeAudit|mission\.sqm') { $focus.Add("Map/runtime init: retest fortifications, central wall gaps, town-defense orientation, and runtime audit lines.") }
if ($changedFiles -match 'Init_Common|CommonConstants|Balance|Units_|Vehicles|LoadoutManager') { $focus.Add("Balance/economy: retest factory lists, price multipliers, caps, ranges, and 5v5-style snowball feel.") }
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
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\Validate-ZargabadRuntimeEvidence.ps1 -RptPath `"C:\path\to\rpts`"")
$brief.Add("powershell -NoProfile -ExecutionPolicy Bypass -File Tools\New-ZargabadRuntimeReport.ps1 -RptPath `"C:\path\to\rpts`" -RequireJip -RequireHeadlessClient -RequireEdgeGuardRemoval -RequireBlackMarket -OutputPath `".\zargabad-runtime-report.md`"")
$brief.Add('```')
$brief.Add("")
$brief.Add("## Stop/Go Rule")
$brief.Add("")
$brief.Add("Codex owns the stop/go call. Claude should keep testing until Codex says the runtime gates are satisfied. Codex should listen to Claude when a finding has RPT excerpts, screenshots, coordinates, or repeatable repro steps.")
$brief.Add("")
$brief.Add("## Evidence To Paste Back")
$brief.Add("")
$brief.Add("- Runtime report markdown from `Tools/New-ZargabadRuntimeReport.ps1`.")
$brief.Add("- RPT paths and exact excerpts for any failing or uncertain validator gate.")
$brief.Add("- Screenshot filenames or map coordinates for base sightlines, central-wall gaps, rim abuse, defense arcs, pathing, and economy/factory observations.")
$brief.Add("- Clear `PASS`, `FAIL`, or `UNCERTAIN` verdicts for each row in the report's Claude Notes table.")
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
