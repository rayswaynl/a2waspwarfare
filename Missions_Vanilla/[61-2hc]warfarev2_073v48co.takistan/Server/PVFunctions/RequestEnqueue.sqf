/*
	Add an upgrade to the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	Server re-validates everything (never trust the client): commander exists,
	upgrade enabled, not maxed, not the running upgrade, not already queued,
	prerequisites currently met.
*/

Private ["_side","_id","_logik","_queue","_levels","_enabled","_upgrades","_current","_lnk","_li","_clink","_linkNeeded"];

_side = _this select 0;
_id   = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own/pay the queue.
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

_enabled = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_ENABLED", str _side];
if (_id < 0 || _id >= count _enabled) exitWith {};
if !(_enabled select _id) exitWith {};

_levels   = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _side];
_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades;
_current  = _upgrades select _id;

//--- Already at max.
if (_current >= (_levels select _id)) exitWith {};

//--- Currently running this one.
if ((_logik getVariable "wfbe_upgrading") && {(_logik getVariable "wfbe_upgrading_id") == _id}) exitWith {};

_queue = + (_logik getVariable "wfbe_upgrade_queue");
//--- Already queued.
if (_id in _queue) exitWith {};

//--- Prerequisites for the *next* level (same LINKS shape as GUI_UpgradeMenu).
_lnk = (missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _side]) select _id;
_lnk = _lnk select _current;
_linkNeeded = false;
if (count _lnk > 0) then {
	if (typeName (_lnk select 0) == "ARRAY") then {
		for "_li" from 0 to (count _lnk - 1) do {
			_clink = _lnk select _li;
			if ((_upgrades select (_clink select 0)) < (_clink select 1)) exitWith {_linkNeeded = true};
		};
	} else {
		if ((_upgrades select (_lnk select 0)) < (_lnk select 1)) then {_linkNeeded = true};
	};
};
if (_linkNeeded) exitWith {};

//--- Append and replicate.
_queue = _queue + [_id];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
