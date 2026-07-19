[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tacticalPaths = @(
	(Join-Path $repoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Client\GUI\GUI_Menu_Tactical.sqf'),
	(Join-Path $repoRoot 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.takistan\Client\GUI\GUI_Menu_Tactical.sqf'),
	(Join-Path $repoRoot 'Missions_Vanilla\[61-2hc]warfarev2_073v48co.zargabad\Client\GUI\GUI_Menu_Tactical.sqf')
)
$failures = @()

function Assert-Contract {
	param(
		[bool]$Condition,
		[string]$Message
	)

	if (!$Condition) {
		$script:failures = $script:failures + $Message
	}
}

# A deleted camp logic must not count as a hostile/unowned camp in any Fast Travel gate.
$rawCamps = @('live-friendly-camp', $null)
$liveCamps = @($rawCamps | Where-Object { $null -ne $_ })
$friendlyCamps = @($rawCamps | Where-Object { 'live-friendly-camp' -eq $_ })
Assert-Contract ($rawCamps.Count -eq 2) 'Model: the stale raw town list contains the deleted camp logic.'
Assert-Contract ($liveCamps.Count -eq 1) 'Model: one live camp remains after a deleted logic is filtered.'
Assert-Contract ($friendlyCamps.Count -ne $rawCamps.Count) 'Model: the old raw comparison rejects a fully friendly live camp set.'
Assert-Contract ($friendlyCamps.Count -eq $liveCamps.Count) 'Model: live-friendly and live-total counts remain equal after a camp deletion.'

$liveAssignment = '(?:_allCamps|_rAllCamps) = \(_.* getVariable "camps"\) - \[objNull\];'
$initialGate = '(?s)_camps = \[_closest,sideJoined\] Call GetFriendlyCamps;\s*_allCamps = \(_closest getVariable "camps"\) - \[objNull\];(?:\s*//[^\r\n]*)?\s*if \(_sideID == sideID && player distance _closest < _ftr && \(count _camps == count _allCamps\)\)'
$destinationGate = '(?s)_camps = \[_x,sideJoined\] Call GetFriendlyCamps;\s*_allCamps = \(_x getVariable "camps"\) - \[objNull\];(?:\s*//[^\r\n]*)?\s*if \(_sideID != sideID \|\| \(count _camps != count _allCamps\)\)'
$fireTimeGate = '(?s)_rCamps = \[_destination,sideJoined\] Call GetFriendlyCamps;\s*_rAllCamps = \(_destination getVariable "camps"\) - \[objNull\];(?:\s*//[^\r\n]*)?\s*if \(count _rCamps != count _rAllCamps\)'

foreach ($tacticalPath in $tacticalPaths) {
	$source = Get-Content -LiteralPath $tacticalPath -Raw
	$sourceLabel = $tacticalPath.Substring($repoRoot.Length + 1)
	$liveMatches = [regex]::Matches($source, $liveAssignment)
	Assert-Contract ($liveMatches.Count -eq 3) "$sourceLabel - every Tactical Fast Travel camp-total gate filters deleted camp logics."
	Assert-Contract ([regex]::IsMatch($source, $initialGate)) "$sourceLabel - initial Fast Travel origin gate uses live camp totals."
	Assert-Contract ([regex]::IsMatch($source, $destinationGate)) "$sourceLabel - destination-list Fast Travel gate uses live camp totals."
	Assert-Contract ([regex]::IsMatch($source, $fireTimeGate)) "$sourceLabel - fire-time Fast Travel gate uses live camp totals."
}

if ($failures.Count -gt 0) {
	$failures | ForEach-Object { Write-Output "FAIL: $_" }
	throw "Test-GuerFastTravelLiveCamps: $($failures.Count) failure(s)"
}

Write-Output 'Test-GuerFastTravelLiveCamps: PASS'
