/*
	Add an upgrade to the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	Server re-validates everything (never trust the client): commander exists,
	upgrade enabled, not maxed, prerequisites met or already pending.
	Stacking: the same upgrade id may be queued several times - each copy stands
	for "one more level" (upgradeQueue.sqf always reads the live level at start,
	so [LF, LF, LF] runs LF1 -> LF2 -> LF3).
*/

Private ["_side","_id","_logik","_queue","_levels","_enabled","_upgrades","_current","_pending","_lnk","_li","_clink","_linkNeeded","_target","_need","_eff"];

_side = _this select 0;
_id   = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own/pay the queue.
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The PVEH gives no trusted sender, so a forger can pass an ENEMY _side to grow the other
//--- side's queue. Without the acting player in the payload we cannot fully bind the request to
//--- the requester (see clientSendChanges), but we can tighten the owning team to be genuinely
//--- player-led and on _side - mirroring the RequestClaimCommander membership pattern.
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	private "_cmdTeam";
	_cmdTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
	if (isNull _cmdTeam) exitWith {
		["WARNING", Format ["RequestEnqueue.sqf: rejected - no commander team for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (!isPlayer (leader _cmdTeam)) exitWith {
		["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (side (leader _cmdTeam) != _side) exitWith {
		["WARNING", Format ["RequestEnqueue.sqf: rejected - commander team side mismatch for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
	};
};

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
