/*
	Remove the LAST queued copy of an upgrade from the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	With stacking the same id may be queued several times; removing the last
	copy cancels only the highest pending level.
*/

Private ["_side","_id","_logik","_queue","_k","_idx"];

_side = _this select 0;
_id   = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own the queue (mirror RequestEnqueue; never trust the client).
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

_queue = + (_logik getVariable "wfbe_upgrade_queue");
_idx = -1;
for "_k" from 0 to (count _queue - 1) do {
	if ((_queue select _k) == _id) then {_idx = _k};
};
if (_idx < 0) exitWith {};

//--- Drop exactly that copy (plain array subtraction would strip ALL copies of a stacked id).
_queue set [_idx, objNull];
_queue = _queue - [objNull];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
