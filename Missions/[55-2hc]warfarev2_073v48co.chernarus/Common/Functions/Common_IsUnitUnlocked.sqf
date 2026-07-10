/*
	Common_IsUnitUnlocked.sqf - WFBE_CO_FNC_IsUnitUnlocked
	feat/common-isunitunlocked (stacks on fix/aicom-dependency-gates, PR #1005).

	Shared AI-commander per-unit tier-unlock check. Every AI purchase path (team founding in
	AI_Commander_Teams.sqf, team refill/production in AI_Commander_Produce.sqf, and base-artillery
	construction in AI_Commander_Base.sqf) independently re-implemented the SAME idiom: look a unit
	classname up in the side's four canonical factory unit-lists (WFBE_<side>BARRACKSUNITS /
	LIGHTUNITS / HEAVYUNITS / AIRCRAFTUNITS) to find which upgrade TRACK gates it, then compare the
	unit's own required tier (its WFBE unit-data array's QUERYUNITUPGRADE slot) against the side's
	researched tier for that track (WFBE_CO_FNC_GetSideUpgrades). This file is the single source of
	truth for that comparison; see AI-Assistant-Developer-Guide for the wider AICOM tier-gate design.

	Parameters (_this select N):
		0 - _unitClassname (STRING): the unit/vehicle classname to test.
		1 - _sideText (STRING): str side; builds the WFBE_<sideText><SUFFIX> unit-list variable
		    names (matches every existing call site's Format ["WFBE_%1%2", ...] idiom).
		2 - _upgrades (ARRAY of 4 NUMBERs, or NIL): the side's [barracks,light,heavy,air]
		    researched-tier array (WFBE_CO_FNC_GetSideUpgrades / logic getVariable "wfbe_upgrades").
		    May be nil - see the FAIL-CLOSED case below (AI_Commander_Base.sqf's own
		    "wfbe_upgrades" read can be nil early in a round).

	Returns [_unlocked (BOOL), _found (BOOL)]:
		_found    - true only when BOTH the classname's WFBE unit-data array
		            (missionNamespace getVariable _unitClassname) exists AND the classname is
		            registered in one of the four per-side factory unit-lists. Lets a caller
		            distinguish "genuinely locked" from "data gap" (unregistered classname / no
		            unit-data record) - the two read very differently in an RPT WARNING.
		_unlocked - the gate result:
		              * _found == false               -> true  (FAIL-OPEN: matches every
		                pre-refactor call site, none of which ever gated on an unmapped classname).
		              * _found == true, _upgrades nil  -> false (FAIL-CLOSED: a track was
		                identified but there is no side-tier data to compare against).
		              * otherwise                      -> (unit's QUERYUNITUPGRADE tier) <=
		                (_upgrades select track).

	Per-site AIR-track waivers (e.g. AI_Commander_Teams.sqf's captured-airfield / held-Aircraft-
	Factory free-buy) are call-site POLICY, not built into this shared comparison. A caller that
	needs to waive one track passes a COPY of _upgrades with that track's slot raised to an
	unreachable value before calling (e.g. `_cp = _upgrades + []; _cp set [WFBE_UP_AIR, 1e6];`),
	so the plain comparison below degrades to "always unlocked" for that ONE track only - the
	exact effect of the removed inline `!(_airTierWaive && {track==WFBE_UP_AIR})` guard. Array
	concatenation (`+ []`) is used (not a bare `=`) so the caller's own _upgrades is never mutated.

	A2-OA-safe: the facMap scan below uses a WHILE loop + found-flag, NOT forEach+exitWith -
	exitWith inside a forEach's per-element code only ends that ONE iteration on this engine (it
	does not break the whole loop; see sqf-edit-guard), so a forEach "stop at first match" scan
	would keep evaluating later facMap entries after a match already fired.
*/

private ["_unitClassname","_sideText","_upgrades","_ud","_found","_track","_facMap","_fi","_facEntry","_unitList","_unlocked"];

_unitClassname = _this select 0;
_sideText      = _this select 1;
_upgrades      = _this select 2;

_ud    = missionNamespace getVariable _unitClassname;
_found = false;
_track = -1;

if (!isNil "_ud") then {
	_facMap = [["BARRACKSUNITS", WFBE_UP_BARRACKS], ["LIGHTUNITS", WFBE_UP_LIGHT], ["HEAVYUNITS", WFBE_UP_HEAVY], ["AIRCRAFTUNITS", WFBE_UP_AIR]];
	_fi = 0;
	while {_fi < (count _facMap) && {!_found}} do {
		_facEntry = _facMap select _fi;
		_unitList = missionNamespace getVariable [Format ["WFBE_%1%2", _sideText, (_facEntry select 0)], []];
		if (_unitClassname in _unitList) then {
			_found = true;
			_track = _facEntry select 1;
		};
		_fi = _fi + 1;
	};
};

_unlocked = true;
if (_found) then {
	if (isNil "_upgrades") then {
		_unlocked = false;
	} else {
		_unlocked = ((_ud select QUERYUNITUPGRADE) <= (_upgrades select _track));
	};
};

[_unlocked, _found]
