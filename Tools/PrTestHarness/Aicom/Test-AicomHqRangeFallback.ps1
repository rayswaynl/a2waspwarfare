[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$sourcePath = Join-Path $repoRoot 'Missions\[55-2hc]warfarev2_073v48co.chernarus\Server\AI\Commander\AI_Commander_Base.sqf'
$source = [System.IO.File]::ReadAllText($sourcePath)

function Require-SourceFragment {
	param(
		[string]$Fragment,
		[string]$Reason
	)

	if ($source.IndexOf($Fragment, [System.StringComparison]::Ordinal) -lt 0) {
		throw "Missing HQ-range fallback contract: $Reason"
	}
}

function Require-After {
	param(
		[string]$Earlier,
		[string]$Later,
		[string]$Reason
	)

	$earlierIndex = $source.IndexOf($Earlier, [System.StringComparison]::Ordinal)
	$laterIndex = $source.IndexOf($Later, [System.StringComparison]::Ordinal)
	if ($earlierIndex -lt 0 -or $laterIndex -lt 0 -or $laterIndex -le $earlierIndex) {
		throw "HQ-range fallback contract ordering failed: $Reason"
	}
}

function Require-Between {
	param(
		[string]$Fragment,
		[string]$Start,
		[string]$End,
		[string]$Reason
	)

	$startIndex = $source.IndexOf($Start, [System.StringComparison]::Ordinal)
	$endIndex = if ($startIndex -lt 0) {-1} else {$source.IndexOf($End, $startIndex, [System.StringComparison]::Ordinal)}
	$fragmentIndex = if ($startIndex -lt 0) {-1} else {$source.IndexOf($Fragment, $startIndex, [System.StringComparison]::Ordinal)}
	if ($startIndex -lt 0 -or $endIndex -lt 0 -or $fragmentIndex -le $startIndex -or $fragmentIndex -ge $endIndex) {
		throw "HQ-range fallback contract boundary failed: $Reason"
	}
}

# This catches the regression where a 205-230m factory-ring candidate was retained as a
# fallback before the 200m HQ leash was applied, then spent/built despite the configured limit.
Require-SourceFragment '_isBuildPosUsable = {' 'a shared usable-position guard is required for no-candidate returns'
Require-SourceFragment 'if (!_blocked && {!_haveBC} && {_cand call _buildPosClear} && {_cand call _farFromStructs} && {_cand call _hqRangeOK}) then {_bestBC = _cand; _haveBC = true};' 'near-road fallback capture must retain only in-range candidates'
Require-SourceFragment 'if (!_haveBC && {_p call _buildPosClear} && {_p call _farFromStructs} && {_p call _hqRangeOK}) then {_bestBC = _p; _haveBC = true};' 'off-road fallback capture must retain only in-range candidates'
Require-SourceFragment 'if (!(_p call _hqRangeOK)) exitWith {[]};' 'terminal road/spacing nudges must fail closed when they leave the leash'
Require-After 'if (!_done) then {_via = _via + "+OVERLAP!"};' 'if (!(_p call _hqRangeOK)) exitWith {[]};' 'the final leash guard must run after every terminal nudge'
Require-After 'if (!(_p call _hqRangeOK)) exitWith {[]};' 'diag_log (format ["AICOMPLACE|' 'the final leash guard must run before the position is returned'

Require-Between 'if !(_pos call _isBuildPosUsable) exitWith {' '_pos = [0,0,0];' 'if (_dual) then {[_side, -_cost' 'base structures must skip their supply debit when no in-range position exists'
Require-Between 'if (_pos call _isBuildPosUsable) then {' '_pos = [28, 42] Call _findBuildPos;' '[_side, -_defPrice] Call ChangeAICommanderFunds;' 'base defenses must validate before commander-funds debit'
Require-Between 'if (_pos call _isBuildPosUsable) then {' '_pos = [25, 38] Call _findBuildPos;' '[_side, -_defPrice] Call ChangeAICommanderFunds;' 'base artillery must validate before commander-funds debit'
Require-Between 'if (_fwdFacP call _isBuildPosUsable) then {' '_fwdFacP = if (_ord in ["Light","Heavy","Aircraft"]) then {' 'if (_dual) then {[_side, -_fwdCost' 'forward structures must skip their supply debit when no in-range position exists'
Require-Between 'if (_fwdDefPos call _isBuildPosUsable) then {' '_fwdDefPos = [22, 40] Call _findBuildPos;' '[_side, -_fwdDefPrice] Call ChangeAICommanderFunds;' 'forward defenses must validate before commander-funds debit'

Write-Output 'PASS: AICOM HQ-range fallback cannot spend or construct beyond its configured anchor leash.'
