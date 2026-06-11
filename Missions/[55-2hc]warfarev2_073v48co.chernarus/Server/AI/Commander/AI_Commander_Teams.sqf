/*
	AI Commander - found new AI combat teams up to the side's target.
	feat/ai-commander V0.3. Server-side worker, full-command mode only.
	Parameter: _this = side.

	V0.3: whole teams are produced ON A HEADLESS CLIENT when one is registered
	(delegate-aicom-team -> Common_RunCommanderTeam.sqf): the brain picks a
	doctrine-weighted unlocked template, charges the full template price from
	AI commander funds, and ships the classnames + a spawn position at the
	doctrine factory to the HC. The HC creates and DRIVES the team locally
	(orders arrive via the public wfbe_aicom_order group variable) - server
	FPS cost ~ 0 and no factory-queue interference with human players.

	Fallback (no live HC): found an empty server-local group with the canonical
	Init_Server variable set; AssignTypes templates it and Produce builds its
	members at the factories per-unit (the V0.2 path).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_target","_aiTeams","_pending","_g","_hcs","_live","_templates","_tmplUpgrades","_upgrades","_eligible","_i","_u","_ok","_k","_doc","_track","_pref","_pick","_template","_price","_cn","_ud","_funds","_structures","_facClass","_facNames","_facIdx","_fac","_facObj","_real","_foundedTeams","_editorTeams","_totalGroups"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") then {_teams = []};

//--- V0.6 task 47: count FOUNDED teams (HC or server-local tag) and EDITOR-SLOT
//--- teams separately so editor-slot population never blocks genuine army founding.
//--- The founding gate uses only foundedTeams + pending vs the target.
_foundedTeams = 0;
_editorTeams  = 0;
{
	if (!isNull _x) then {
		_real = false;
		if (_x getVariable ["wfbe_aicom_hc", false]) then {_real = true};
		if (!_real && {_x getVariable ["wfbe_aicom_founded", false]}) then {_real = true};
		if (_real) then {
			_foundedTeams = _foundedTeams + 1;
		} else {
			//--- Editor-slot branch: alive AI leader with units present.
			if ((count units _x) > 0 && {!isPlayer (leader _x)} && {alive (leader _x)}) then {
				_editorTeams = _editorTeams + 1;
			};
		};
	};
} forEach _teams;
_aiTeams = _foundedTeams + _editorTeams; //--- legacy alias; used in server-local log below.
_pending = _logik getVariable ["wfbe_aicom_pending", 0];

_target = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_TARGET", 4];
if ((_foundedTeams + _pending) >= _target) exitWith {};

//--- V0.6 task 47: group-cap safety ceiling - skip founding if the side already has
//--- too many groups in the field (prevents ArmA engine group-limit crashes).
_totalGroups = {side _x == _side} count allGroups;
if (_totalGroups > 110) exitWith {
	["WARNING", Format ["AI_Commander_Teams.sqf: [%1] group-cap ceiling reached (%2 groups) - founding skipped (founded %3, editor %4, pending %5, target %6).", _sideText, _totalGroups, _foundedTeams, _editorTeams, _pending, _target]] Call WFBE_CO_FNC_AICOMLog;
};

//--- Live HC available?
_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
_live = [];
{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;

if (count _live > 0) then {
	//--- V0.3 HC path: pick a doctrine-weighted UNLOCKED template now (the HC just builds it).
	_templates    = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
	_tmplUpgrades = missionNamespace getVariable Format ["WFBE_%1AITEAMUPGRADES", _sideText];
	if (isNil "_templates" || isNil "_tmplUpgrades") exitWith {};
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

	_eligible = [];
	for "_i" from 0 to (count _templates - 1) do {
		_u = _tmplUpgrades select _i;
		_ok = true;
		for "_k" from 0 to 3 do {
			if ((_u select _k) > (_upgrades select _k)) exitWith {_ok = false};
		};
		if (_ok) then {_eligible set [count _eligible, _i]};
	};
	if (count _eligible == 0) exitWith {};

	_doc = _logik getVariable ["wfbe_aicom_doctrine", ""];
	_pref = [];
	if (_doc != "") then {
		_track = if (_doc == "HF") then {2} else {1};
		{
			_u = _tmplUpgrades select _x;
			if ((_u select _track) >= 1) then {_pref = _pref + [_x]};
		} forEach _eligible;
	};
	_pick = if (count _pref > 0 && {(random 1) < 0.7}) then {
		_pref select (floor (random (count _pref)))
	} else {
		_eligible select (floor (random (count _eligible)))
	};
	_template = _templates select _pick;

	//--- Full template price from AI commander funds (whole-team purchase economics).
	_price = 0;
	{
		_cn = _x;
		_ud = missionNamespace getVariable _cn;
		if (!isNil "_ud") then {_price = _price + (_ud select QUERYUNITPRICE)};
	} forEach _template;
	_funds = (_side) Call GetAICommanderFunds;
	if (_funds < _price) exitWith {};

	//--- Spawn at the doctrine factory (fallback: Barracks, then the HQ).
	_facNames = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
	_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
	_facObj = objNull;
	{
		_facIdx = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText]) find _x;
		if (_facIdx >= 0) then {
			_facClass = _facNames select _facIdx;
			{ if (typeOf _x == _facClass && {alive _x}) exitWith {_facObj = _x} } forEach _structures;
		};
		if (!isNull _facObj) exitWith {};
	} forEach (if (_doc == "HF") then {["Heavy","Light","Barracks"]} else {["Light","Heavy","Barracks"]});
	if (isNull _facObj) then {_facObj = (_side) Call WFBE_CO_FNC_GetSideHQ};
	if (isNull _facObj) exitWith {};

	[_side, -_price] Call ChangeAICommanderFunds;
	_logik setVariable ["wfbe_aicom_pending", _pending + 1];
	[leader (_live select (floor (random (count _live)))), "HandleSpecial", ['delegate-aicom-team', _sideID, _template, getPos _facObj]] Call WFBE_CO_FNC_SendToClient;
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] HC team founding dispatched (template %2, cost %3, doctrine %4, founded %5 editor %6 pending->%7 target %8).", _sideText, _pick, _price, _doc, _foundedTeams, _editorTeams, _pending + 1, _target]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_FOUNDED|HC-template" + str _pick);
} else {
	//--- Fallback (no HC): found a server-local empty team; AssignTypes + Produce feed it.
	_g = createGroup _side;
	if (isNull _g) exitWith {
		["WARNING", Format ["AI_Commander_Teams.sqf: [%1] createGroup returned grpNull (group limit?).", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	};
	_g setVariable ["wfbe_aicom_founded", true];
	_g setVariable ["wfbe_funds", 0, true];
	_g setVariable ["wfbe_side", _side];
	_g setVariable ["wfbe_persistent", true];
	_g setVariable ["wfbe_queue", []];
	_g setVariable ["wfbe_vote", -1, true];
	[_g, false] Call SetTeamAutonomous;
	[_g, ""] Call SetTeamRespawn;
	[_g, -1] Call SetTeamType;
	[_g, "towns"] Call SetTeamMoveMode;
	[_g, [0,0,0]] Call SetTeamMovePos;
	_logik setVariable ["wfbe_teams", _teams + [_g], true];
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] founded server-local AI team (founded %2->%3 editor %4 target %5) [%6].", _sideText, _foundedTeams, _foundedTeams + 1, _editorTeams, _target, _g]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_FOUNDED|server-local");
};
