/*
	Remove the LAST queued copy of an upgrade from the side's auto-start queue.
	 Parameters: [ side, upgradeId, requester ]
	With stacking the same id may be queued several times; removing the last
	copy cancels only the highest pending level.
*/

Private ["_side","_id","_logik","_queue","_k","_idx","_requester","_cmdTeam","_requestTeam"];

//--- Envelope: short / wrong-type / nil-slot PV payloads must not reach queue mutation.
if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 3) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_id   = _this select 1;
_requester = _this select 2;

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _id != "SCALAR" || {_id != floor _id}) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected non-integer upgrade id [%1].", _id]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _requester != "OBJECT" || {isNull _requester}) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected invalid requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer _requester) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected non-player requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};

_requestTeam = group _requester;
if (isNull _requestTeam) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected requester with null group [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (side _requestTeam != _side) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected requester side mismatch payload [%1] requester [%2].", _side, side _requestTeam]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own the queue (mirror RequestEnqueue / RequestUpgrade).
_cmdTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeam) exitWith {};
if (_requestTeam != _cmdTeam) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected requester team [%1] is not commander team [%2] for side %3.", _requestTeam, _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (leader _cmdTeam != _requester) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected requester [%1] is not commander leader [%2] for side %3.", _requester, leader _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer (leader _cmdTeam)) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
};

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
