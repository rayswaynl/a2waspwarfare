/*
	Add an upgrade to the side's auto-start queue.
	 Parameters: [ side, upgradeId ]
	Server re-validates everything (never trust the client): commander exists,
	upgrade enabled, not maxed, prerequisites met or already pending.
	Stacking: the same upgrade id may be queued several times - each copy stands
	for "one more level" (upgradeQueue.sqf always reads the live level at start,
	so [LF, LF, LF] runs LF1 -> LF2 -> LF3).
*/

Private ["_side","_id","_logik","_queue","_levels","_enabled","_upgrades","_current","_pending","_lnk","_li","_clink","_linkNeeded","_target","_need","_eff","_rejected","_reqPlayer","_cmdTeamAuth"];

if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 3) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected short payload %1.", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_id   = _this select 1;

//--- Caller authority bind (mirror RequestUpgrade.sqf, the immediate-purchase sibling): the auto-upgrade queue
//--- is a COMMANDER-owned resource paid from commander funds, and the client Upgrade Center enables the queue
//--- buttons only for the seated commander (GUI_UpgradeMenu.sqf:270-272). The client now appends the acting
//--- player; without it any same-side member - or a forged PVF naming an ENEMY side - could grow another team
//--- queue whenever that side has a human commander.
if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _id != "SCALAR" || {_id != floor _id}) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected non-integer upgrade id [%1].", _id]] Call WFBE_CO_FNC_LogContent;
};
_reqPlayer = _this select 2;
if (typeName _reqPlayer != "OBJECT" || {isNull _reqPlayer} || {!isPlayer _reqPlayer}) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected invalid requester [%1].", _reqPlayer]] Call WFBE_CO_FNC_LogContent;
};
_cmdTeamAuth = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeamAuth) exitWith {};
if (leader _cmdTeamAuth != _reqPlayer) exitWith {
	["WARNING", Format ["RequestEnqueue.sqf: rejected requester [%1] is not the %2 commander leader.", _reqPlayer, _side]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {};

//--- Must have a (human) commander team to own/pay the queue.
if (isNull (_side Call WFBE_CO_FNC_GetCommanderTeam)) exitWith {};

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The PVEH gives no trusted sender, so a forger can pass an ENEMY _side to grow the other
//--- side's queue. Without the acting player in the payload we cannot fully bind the request to
//--- the requester (see clientSendChanges), but we can tighten the owning team to be genuinely
//--- player-led and on _side - mirroring the RequestClaimCommander membership pattern.
//--- fix(hunt): the three rejections below were exitWith INSIDE the hardening then{} - on A2-OA that exits
//--- only the block and FALLS THROUGH to the queue-append, making the hardening a logged no-op.
//--- Latch _rejected instead; the top-scope exitWith after the block aborts the handler for real.
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	private "_cmdTeam";
	_cmdTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
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
if (typeName _enabled != "ARRAY") exitWith {};
if (_id < 0 || {_id >= count _enabled}) exitWith {};
if !(_enabled select _id) exitWith {};

_levels   = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _side];
if (typeName _levels != "ARRAY" || {_id >= count _levels}) exitWith {};
if (typeName (_levels select _id) != "SCALAR") exitWith {};
_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades;
if (typeName _upgrades != "ARRAY" || {_id >= count _upgrades}) exitWith {};
_current  = _upgrades select _id;
if (typeName _current != "SCALAR") exitWith {};

//--- Bare getVariable returns nil when the side logic never initialized the queue/running latch
//--- (early boot, resistance placeholder, or JIP race). + nil / count nil throws and kills the PVF.
_queue = _logik getVariable ["wfbe_upgrade_queue", []];
if (typeName _queue != "ARRAY") then {_queue = []};
_queue = + _queue;

//--- Levels already pending for this id: queued copies + the one currently running.
_pending = {_x == _id} count _queue;
if ((_logik getVariable ["wfbe_upgrading", false]) && {(_logik getVariable ["wfbe_upgrading_id", -1]) == _id}) then {_pending = _pending + 1};

//--- Every remaining level is already done or pending.
if (_current + _pending >= (_levels select _id)) exitWith {};

//--- Prerequisites for the level this entry will start at (_current + _pending).
//--- Queue-aware: a link counts as met when the needed level is live OR pending
//--- (queued/running); upgradeQueue.sqf skips entries whose links are not live yet,
//--- so out-of-order queueing cannot wedge the queue.
_lnk = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _side];
if (typeName _lnk != "ARRAY" || {_id >= count _lnk}) exitWith {};
_lnk = _lnk select _id;
if (typeName _lnk != "ARRAY") exitWith {};
if ((_current + _pending) >= count _lnk) exitWith {};
_lnk = _lnk select (_current + _pending);
if (typeName _lnk != "ARRAY") exitWith {};
_linkNeeded = false;
if (count _lnk > 0) then {
	if (typeName (_lnk select 0) == "ARRAY") then {
		for "_li" from 0 to (count _lnk - 1) do {
			_clink = _lnk select _li;
			if (typeName _clink != "ARRAY" || {count _clink < 2}) exitWith {_linkNeeded = true};
			_target = _clink select 0;
			_need   = _clink select 1;
			if (typeName _target != "SCALAR" || {typeName _need != "SCALAR"} || {_target < 0} || {_target >= count _upgrades}) exitWith {_linkNeeded = true};
			_eff = (_upgrades select _target) + ({_x == _target} count _queue);
			if ((_logik getVariable ["wfbe_upgrading", false]) && {(_logik getVariable ["wfbe_upgrading_id", -1]) == _target}) then {_eff = _eff + 1};
			if (_eff < _need) exitWith {_linkNeeded = true};
		};
	} else {
		if (count _lnk < 2) exitWith {_linkNeeded = true};
		_target = _lnk select 0;
		_need   = _lnk select 1;
		if (typeName _target != "SCALAR" || {typeName _need != "SCALAR"} || {_target < 0} || {_target >= count _upgrades}) exitWith {_linkNeeded = true};
		_eff = (_upgrades select _target) + ({_x == _target} count _queue);
		if ((_logik getVariable ["wfbe_upgrading", false]) && {(_logik getVariable ["wfbe_upgrading_id", -1]) == _target}) then {_eff = _eff + 1};
		if (_eff < _need) then {_linkNeeded = true};
	};
};
if (_linkNeeded) exitWith {};

//--- Append and replicate.
_queue = _queue + [_id];
_logik setVariable ["wfbe_upgrade_queue", _queue, true];
