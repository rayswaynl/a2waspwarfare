<#
.SYNOPSIS
	One-command pre-test check for a WASP Warfare PR build.

.DESCRIPTION
	Runs the static smoke gate (Test-WaspStaticSmoke.ps1), the whole-root A2 OA
	compatibility linter for Chernarus and Takistan, and the static bug-hunt
	(Find-WaspBugHunt.ps1 -All -MinSeverity high) back to back and prints a
	combined verdict. This is the "am I ready to test in-engine?" check.

	It does NOT replace in-engine testing. Failing/`HIGH` items, plus the smoke checks
	that depend on the installed stress overlay, still need the real run.

.EXAMPLE
	pwsh Tools\PrTestHarness\Run-WaspFinalCheck.ps1
	pwsh Tools\PrTestHarness\Run-WaspFinalCheck.ps1 -BaseRef origin/master
#>
param(
	[string]$BaseRef = "origin/master",
	[string]$HeadRef = "HEAD"
)
$ErrorActionPreference = "Continue"
$here = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $here "..\..")

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " WASP final pre-test check  (base $BaseRef)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$pwsh = (Get-Process -Id $PID).Path   # same PowerShell host
if (-not $pwsh) { $pwsh = "pwsh" }

# Run each as a CHILD process: the smoke script ends with `exit`, which would otherwise
# terminate this wrapper before the bug-hunt runs.
Write-Host "`n[1/4] Static smoke gate" -ForegroundColor Cyan
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "Smoke\Test-WaspStaticSmoke.ps1") -BaseRef $BaseRef -HeadRef $HeadRef
$smoke = $LASTEXITCODE

Write-Host "`n[2/4] A2 OA compatibility lint (Chernarus source)" -ForegroundColor Cyan
$chernarusRoot = Join-Path $repoRoot "Missions\[55-2hc]warfarev2_073v48co.chernarus"
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "Smoke\Lint-A2Compat.ps1") -MissionLiteralPath $chernarusRoot
$lintChernarus = $LASTEXITCODE

Write-Host "`n[3/4] A2 OA compatibility lint (Takistan generated)" -ForegroundColor Cyan
$takistanRoot = Join-Path $repoRoot "Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan"
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "Smoke\Lint-A2Compat.ps1") -MissionLiteralPath $takistanRoot
$lintTakistan = $LASTEXITCODE

Write-Host "`n[4/4] Static bug-hunt (whole mission, HIGH only)" -ForegroundColor Cyan
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "BugHunt\Find-WaspBugHunt.ps1") -All -MinSeverity high
$bughunt = $LASTEXITCODE

Write-Host "`n==================================================================" -ForegroundColor Cyan
if ($smoke -eq 0) {
	Write-Host " Smoke gate: PASS." -ForegroundColor Green
} else {
	Write-Host " Smoke gate: $smoke check(s) failed. NOTE: the 'Local active stress' /" -ForegroundColor Yellow
	Write-Host " RHUD-stressProof checks fail unless the stress overlay is installed into the" -ForegroundColor Yellow
	Write-Host " active test mission (Install-WaspPrTestHarness.ps1) - those are environment, not code." -ForegroundColor Yellow
}
if ($lintChernarus -eq 0 -and $lintTakistan -eq 0) {
	Write-Host " A2 OA compatibility lint: PASS for Chernarus and Takistan." -ForegroundColor Green
} else {
	Write-Host " A2 OA compatibility lint: Chernarus=$lintChernarus Takistan=$lintTakistan." -ForegroundColor Red
}
Write-Host " Bug-hunt findings above are HEURISTIC leads - eyeball before acting." -ForegroundColor DarkGray
Write-Host " Still required before ship: LoadoutManager regen + Arma 2 OA in-engine smoke." -ForegroundColor DarkGray
Write-Host "==================================================================" -ForegroundColor Cyan

if ($smoke -ne 0 -or $lintChernarus -ne 0 -or $lintTakistan -ne 0 -or $bughunt -ne 0) {
	exit 1
}
exit 0
