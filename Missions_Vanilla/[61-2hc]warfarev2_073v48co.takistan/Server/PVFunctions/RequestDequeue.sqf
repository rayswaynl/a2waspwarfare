/*
	Remove the LAST queued copy of an upgrade from the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	With stacking the same id may be queued several times; removing the last
	copy cancels only the highest pending level.
*/

Private ["_side","_id","_logik","_queue","_k","_idx","_reqPlayer","_cmdTeamAuth"];

if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 3) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected short payload %1.", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_id   = _this select 1;

//--- Caller authority bind (mirror RequestUpgrade.sqf / RequestEnqueue.sqf): the auto-upgrade queue is a
//--- COMMANDER-owned resource; the client Upgrade Center enables the queue buttons only for the seated
//--- commander (GUI_UpgradeMenu.sqf:270-272). The client now appends the acting player; without it any
//--- same-side member - or a forged PVF naming an ENEMY side - could strip another team queued upgrades
//--- whenever that side has a human commander.
if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _id != "SCALAR" || {_id != floor _id}) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected non-integer upgrade id [%1].", _id]] Call WFBE_CO_FNC_LogContent;
};
_reqPlayer = _this select 2;
if (typeName _reqPlayer != "OBJECT" || {isNull _reqPlayer} || {!isPlayer _reqPlayer}) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected invalid requester [%1].", _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
_cmdTeamAuth = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeamAuth) exitWith {};
if (leader _cmdTeamAuth != _reqPlayer) exitWith {
	["WARNING", Format ["RequestDequeue.sqf: rejected requester [%1] is not the %2 commander leader.", _reqPlayer, _side]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own the queue (mirror RequestEnqueue; never trust the client).
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

//--- Bare getVariable "wfbe_upgrade_queue" is nil until the first enqueue; + nil / count nil aborts the PVF.
_queue = _logik getVariable ["wfbe_upgrade_queue", []];
if (typeName _queue != "ARRAY") then {_queue = []};
_queue = + _queue;
_idx = -1;
for "_k" from 0 to (count _queue - 1) do {
	if ((_queue select _k) == _id) then {_idx = _k};
};
if (_idx < 0) exitWith {};

//--- Drop exactly that copy (plain array subtraction would strip ALL copies of a stacked id).
_queue set [_idx, objNull];
_queue = _queue - [objNull];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
