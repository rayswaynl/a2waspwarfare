/*
	Add an upgrade to the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	Server re-validates everything (never trust the client): commander exists,
	upgrade enabled, not maxed, prerequisites met or already pending.
	Stacking: the same upgrade id may be queued several times - each copy stands
	for "one more level" (upgradeQueue.sqf always reads the live level at start,
	so [LF, LF, LF] runs LF1 -> LF2 -> LF3).
*/

Private ["_side","_id","_logik","_queue","_levels","_enabled","_upgrades","_current","_pending","_lnk","_li","_clink","_linkNeeded","_target","_need","_eff","_rejected","_requester","_cmdTeam","_requestTeam"];

//--- Envelope + commander bind (always-on). Short/wrong-type/nil-slot payloads and cross-side
//--- forges must not grow the upgrade queue. Client (GUI_UpgradeMenu) sends [side, id, player].
if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if (count _this < 3) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_id   = _this select 1;
_requester = _this select 2;

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _id != "SCALAR" || {_id != floor _id}) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected non-integer upgrade id [%1].", _id]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _requester != "OBJECT" || {isNull _requester}) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected invalid requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer _requester) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected non-player requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};

_requestTeam = group _requester;
if (isNull _requestTeam) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected requester with null group [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (side _requestTeam != _side) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected requester side mismatch payload [%1] requester [%2].", _side, side _requestTeam]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own/pay the queue; bind requester to that seat.
_cmdTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeam) exitWith {};
if (_requestTeam != _cmdTeam) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected requester team [%1] is not commander team [%2] for side %3.", _requestTeam, _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (leader _cmdTeam != _requester) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected requester [%1] is not commander leader [%2] for side %3.", _requester, leader _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer (leader _cmdTeam)) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
};
if (side (leader _cmdTeam) != _side) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team side mismatch for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
};

//--- Legacy DR-55 block retained as no-op belt (always-on bind above already covers these).
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	if (isNull _cmdTeam) then {
		_rejected = true;
		["WARNING", Format ["RequestEnqueue.sqf: rejected - no commander team for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {!isPlayer (leader _cmdTeam)}) then {
		_rejected = true;
		["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {side (leader _cmdTeam) != _side}) then {
		_rejected = true;
		["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team side mismatch for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
	};
};
if (_rejected) exitWith {};

_enabled = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_ENABLED", str _side];
if (_id < 0 || _id >= count _enabled) exitWith {};
if !(_enabled select _id) exitWith {};

_levels   = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _side];
_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades;
_current  = _upgrades select _id;

_queue = + (_logik getVariable "wfbe_upgrade_queue");

//--- Levels already pending for this id: queued copies + the one currently running.
_pending = {_x == _id} count _queue;
if ((_logik getVariable "wfbe_upgrading") && {(_logik getVariable "wfbe_upgrading_id") == _id}) then {_pending = _pending + 1};

//--- Every remaining level is already done or pending.
if (_current + _pending >= (_levels select _id)) exitWith {};

//--- Prerequisites for the level this entry will start at (_current + _pending).
//--- Queue-aware: a link counts as met when the needed level is live OR pending
//--- (queued/running); upgradeQueue.sqf skips entries whose links are not live yet,
//--- so out-of-order queueing cannot wedge the queue.
_lnk = (missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _side]) select _id;
_lnk = _lnk select (_current + _pending);
_linkNeeded = false;
if (count _lnk > 0) then {
	if (typeName (_lnk select 0) == "ARRAY") then {
		for "_li" from 0 to (count _lnk - 1) do {
			_clink = _lnk select _li;
			_target = _clink select 0;
			_need   = _clink select 1;
			_eff = (_upgrades select _target) + ({_x == _target} count _queue);
			if ((_logik getVariable "wfbe_upgrading") && {(_logik getVariable "wfbe_upgrading_id") == _target}) then {_eff = _eff + 1};
			if (_eff < _need) exitWith {_linkNeeded = true};
		};
	} else {
		_target = _lnk select 0;
		_need   = _lnk select 1;
		_eff = (_upgrades select _target) + ({_x == _target} count _queue);
		if ((_logik getVariable "wfbe_upgrading") && {(_logik getVariable "wfbe_upgrading_id") == _target}) then {_eff = _eff + 1};
		if (_eff < _need) then {_linkNeeded = true};
	};
};
if (_linkNeeded) exitWith {};

//--- Append and replicate.
_queue = _queue + [_id];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
