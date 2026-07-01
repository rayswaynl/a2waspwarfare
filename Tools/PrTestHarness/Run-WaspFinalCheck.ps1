<#
.SYNOPSIS
	One-command pre-test check for a WASP Warfare PR build.

.DESCRIPTION
	Runs the static smoke gate (Test-WaspStaticSmoke.ps1) and the static bug-hunt
	(Find-WaspBugHunt.ps1 -All -MinSeverity high) back to back and prints a combined
	verdict. This is the "am I ready to test in-engine?" check.

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

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " WASP final pre-test check  (base $BaseRef)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$pwsh = (Get-Process -Id $PID).Path   # same PowerShell host
if (-not $pwsh) { $pwsh = "pwsh" }

# Run each as a CHILD process: the smoke script ends with `exit`, which would otherwise
# terminate this wrapper before the bug-hunt runs.
Write-Host "`n[1/2] Static smoke gate" -ForegroundColor Cyan
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "Smoke\Test-WaspStaticSmoke.ps1") -BaseRef $BaseRef -HeadRef $HeadRef
$smoke = $LASTEXITCODE

Write-Host "`n[2/2] Static bug-hunt (whole mission, HIGH only)" -ForegroundColor Cyan
& $pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "BugHunt\Find-WaspBugHunt.ps1") -All -MinSeverity high

Write-Host "`n==================================================================" -ForegroundColor Cyan
if ($smoke -eq 0) {
	Write-Host " Smoke gate: PASS." -ForegroundColor Green
} else {
	Write-Host " Smoke gate: $smoke check(s) failed. NOTE: the 'Local active stress' /" -ForegroundColor Yellow
	Write-Host " RHUD-stressProof checks fail unless the stress overlay is installed into the" -ForegroundColor Yellow
	Write-Host " active test mission (Install-WaspPrTestHarness.ps1) - those are environment, not code." -ForegroundColor Yellow
}
Write-Host " Bug-hunt findings above are HEURISTIC leads - eyeball before acting." -ForegroundColor DarkGray
Write-Host " Still required before ship: LoadoutManager regen + Arma 2 OA in-engine smoke." -ForegroundColor DarkGray
Write-Host "==================================================================" -ForegroundColor Cyan
