Private["_assigned_commander","_cmdTeam","_logik","_name","_requester","_side","_team","_teams","_rejected"];

//--- Payload: [side, assignedTeam-or-objNull] (legacy) or [side, assignedTeam-or-objNull, requesterPlayer].
//--- Mid-round transfer path only (GUI_Commander_VoteMenu when votetime <= 0). The round vote
//--- result is published by Server_VoteForCommander, not this PVF.
if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestNewCommander.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 2) exitWith {
	["WARNING", Format ["RequestNewCommander.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_assigned_commander = _this select 1;
_requester = if ((count _this) > 2) then {_this select 2} else {objNull};

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestNewCommander.sqf: rejected non-side payload [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	["WARNING", "RequestNewCommander.sqf: rejected request - side logic is null."] Call WFBE_CO_FNC_LogContent;
};

//--- DR-55 forged-PVF hardening + r71 sitting-commander authority bind.
//--- The PVEH gives no trusted sender, so a forger could pass an ENEMY _side plus a team to seize
//--- the other side's commander seat. The honest vote (GUI_Commander_VoteMenu.sqf) sends
//--- [side group player, votedTeam, player], where votedTeam is either objNull ("AI Commander", a stand-
//--- down) or an own-side team. Server-side we: require valid side logic; require the requester is the
//--- seated human commander leader (only they may transfer/abdicate mid-round); and - for a NON-null
//--- assigned team - require it is a real player-led roster team on _side.
_rejected = false;

if (!isNull _requester) then {
	if (typeName _requester != "OBJECT" || {!isPlayer _requester} || {!alive _requester}) then {
		_rejected = true;
		["WARNING", "RequestNewCommander.sqf: rejected invalid requester."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {side (group _requester) != _side}) then {
		_rejected = true;
		["WARNING", Format ["RequestNewCommander.sqf: rejected requester side mismatch (player %1 vs payload %2).", side (group _requester), _side]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected) then {
		_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		if (isNull _cmdTeam || {group _requester != _cmdTeam} || {leader _cmdTeam != _requester} || {!isPlayer (leader _cmdTeam)}) then {
			_rejected = true;
			["WARNING", Format ["RequestNewCommander.sqf: rejected non-commander transfer by [%1].", if (isNull _requester) then {"null"} else {name _requester}]] Call WFBE_CO_FNC_LogContent;
		};
	};
} else {
	//--- Legacy 2-arg payload: still enforce cross-side team membership when SEC_HARDENING is on
	//--- (byte-compatible with prior DR-55 path for old clients). Without a requester we cannot
	//--- bind sitting-commander authority.
	if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
		if (!isNull _assigned_commander) then {
			if (typeName _assigned_commander != "GROUP" || {isNull (leader _assigned_commander)} || {side (leader _assigned_commander) != _side}) then {
				_rejected = true;
				["WARNING", Format ["RequestNewCommander.sqf: rejected cross-side commander assignment (legacy 2-arg)."]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};
};

if (!_rejected && {!isNull _assigned_commander}) then {
	if (typeName _assigned_commander != "GROUP") then {
		_rejected = true;
		["WARNING", Format ["RequestNewCommander.sqf: rejected non-group assigned commander [%1].", typeName _assigned_commander]] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected) then {
		_teams = _logik getVariable "wfbe_teams"; if (isNil "_teams") then {_teams = []};
		if (typeName _teams != "ARRAY" || {!(_assigned_commander in _teams)}) then {
			_rejected = true;
			["WARNING", "RequestNewCommander.sqf: rejected assigned team not on side roster."] Call WFBE_CO_FNC_LogContent;
		};
	};
	if (!_rejected && {!isPlayer (leader _assigned_commander)}) then {
		_rejected = true;
		["WARNING", "RequestNewCommander.sqf: rejected assigned team is not player-led."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {side (leader _assigned_commander) != _side}) then {
		_rejected = true;
		["WARNING", Format ["RequestNewCommander.sqf: rejected cross-side commander assignment (team side %1 != request side %2).", side (leader _assigned_commander), _side]] Call WFBE_CO_FNC_LogContent;
	};
};
if (_rejected) exitWith {};

if ((_logik getVariable "wfbe_votetime") <= 0) then {
	_team = -1;

	//--- Set the commander
	//--- Round-3 review (P1-1/P1-3): with the lease enabled the writer ONLY ENQUEUES a grant
	//--- request - it never publishes wfbe_commander or touches lease state itself. The single
	//--- per-side executor is the sole eligibility-decider AND the sole caller of
	//--- AssignForCommander (which stops the AI FSM + notifies clients), closing the
	//--- SEC_HARDENING-off cross-side hole (denial now happens fail-closed at the one authoritative
	//--- writer) and the "writer publish and lease grant remain separate statements" race. Flag-off:
	//--- the legacy unconditional publish below is byte-identical to HEAD.
	if ((missionNamespace getVariable ["WFBE_C_CMD_LEASE", 0]) > 0) then {
		[_side, _assigned_commander, "assign"] Call WFBE_CO_FNC_CommanderLeaseRequestGrant;
	} else {
		_logik setVariable ["wfbe_commander", _assigned_commander, true];
		[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander; //--- wiki-wins: AssignForCommander (Server_AssignNewCommander.sqf:10) already notifies clients; removed the duplicate SendToClients
	};

};
