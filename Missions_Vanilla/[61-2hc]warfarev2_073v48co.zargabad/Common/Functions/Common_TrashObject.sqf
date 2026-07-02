/*
	Trash an entity. Groups can only be removed once that all it's units are DELETED!
	 Parameters:
		- Object.
*/

Private ["_delay","_group","_isMan","_object","_town"];

_object = _this;
_town = [_object] Call GetClosestLocation;
if !(isNull _object) then {
	_isMan = if (_object isKindOf "Man") then {true} else {false};

	_group = if (_isMan) then {group _object} else {grpNull};
	if !(_isMan) then {_object removeAllEventHandlers "hit"};
	_object removeAllEventHandlers "killed";

	//--- B35 (claude-gaming 2026-06-15): man bodies -> fixed BODIES_TIMEOUT (60s); vehicle wrecks -> lobby-tunable CLEAN_TIMEOUT.
	//--- Prior bug: this read BODIES_TIMEOUT for BOTH then x2'd vehicles, so the lobby "Bodies Timeout" slider was silently ignored (wrecks pinned at 120s).
	//--- Split restored; x2 dropped so the slider value IS the wreck timeout (Parameters default lowered to 120s to keep prior effective behavior). Rollback: single BODIES read + x2.
	_delay = if (_isMan) then { missionNamespace getVariable "WFBE_C_UNITS_BODIES_TIMEOUT" } else { missionNamespace getVariable "WFBE_C_UNITS_CLEAN_TIMEOUT" };

	sleep _delay;

	//--- qol-polish-pack: optional player-proximity guard for bodies — never pop a corpse in a player's face. Holds deletion while a player
	//--- is within WFBE_C_UNITS_BODIES_PROX m, capped at one extra _delay so a camper can't pin a body forever. 0 = off (vanilla behaviour).
	if (_isMan && {(missionNamespace getVariable ["WFBE_C_UNITS_BODIES_PROX", 0]) > 0}) then {
		private ["_prox","_held"];
		_prox = missionNamespace getVariable ["WFBE_C_UNITS_BODIES_PROX", 0];
		_held = 0;
		while {_held < _delay && {({isPlayer _x && {alive _x} && {_x distance _object < _prox}} count playableUnits) > 0}} do {
			sleep 3; _held = _held + 3;
		};
	};

	["INFORMATION", Format["Server_TrashObject.sqf: Deleting [%1], it has been [%2] seconds.", _object, _delay]] Call WFBE_CO_FNC_LogContent;

	deleteVehicle _object;

	if (_isMan) then {
		if !(isNull _group) then {
			if (isNil {_group getVariable "wfbe_persistent"}) then {if (count (units _group) <= 0) then {deleteGroup _group}};
		};
	};
};