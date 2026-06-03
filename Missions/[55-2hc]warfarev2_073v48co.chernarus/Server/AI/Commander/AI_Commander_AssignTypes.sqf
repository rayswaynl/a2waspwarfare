/*
	AI Commander — assign an AI-team template to each unassigned AI team.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side (west/east/resistance).

	A team needs a template (wfbe_teamtype) before it can be produced for. We pick a
	random template the side has UNLOCKED (its [barracks,light,heavy,air] min-upgrade
	levels are all met). Factory availability is NOT checked here on purpose — the
	Produce worker no-ops gracefully when the needed factory does not exist yet.
*/

private ["_side","_logik","_sideText","_teams","_templates","_tmplUpgrades","_upgrades","_team","_eligible","_i","_u","_ok","_k","_pick"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_sideText = str _side;

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

_templates    = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
_tmplUpgrades = missionNamespace getVariable Format ["WFBE_%1AITEAMUPGRADES", _sideText];
if (isNil "_templates" || isNil "_tmplUpgrades") exitWith {};
if (count _templates == 0) exitWith {};

_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

{
	_team = _x;
	if (!isPlayer (leader _team) && {(_team getVariable ["wfbe_teamtype", -1]) < 0}) then {
		//--- Build the list of UNLOCKED template indices.
		_eligible = [];
		for "_i" from 0 to (count _templates - 1) do {
			_u = _tmplUpgrades select _i;
			_ok = true;
			for "_k" from 0 to 3 do {
				if ((_u select _k) > (_upgrades select _k)) exitWith {_ok = false};
			};
			if (_ok) then {_eligible set [count _eligible, _i]};
		};

		if (count _eligible > 0) then {
			_pick = _eligible select (floor (random (count _eligible)));
			_team setVariable ["wfbe_teamtype", _pick, true];
			["INFORMATION", Format ["AI_Commander_AssignTypes.sqf: [%1] assigned template %2 to AI team [%3].", _sideText, _pick, _team]] Call WFBE_CO_FNC_LogContent;
		};
	};
} forEach _teams;
