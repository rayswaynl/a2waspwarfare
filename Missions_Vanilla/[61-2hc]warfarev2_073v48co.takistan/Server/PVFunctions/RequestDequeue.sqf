/*
	Remove an upgrade from the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
*/

Private ["_side","_id","_logik","_queue"];

_side = _this select 0;
_id   = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own the queue (mirror RequestEnqueue; never trust the client).
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

_queue = + (_logik getVariable "wfbe_upgrade_queue");
if !(_id in _queue) exitWith {};

//--- Duplicates are forbidden at enqueue, so set-subtraction removes exactly one.
_queue = _queue - [_id];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
