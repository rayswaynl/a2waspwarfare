Private["_commanderTeam","_logik","_name","_side","_team","_rejected"];

_side = _this select 0;
_assigned_commander = _this select 1;

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The PVEH gives no trusted sender, so a forger could pass an ENEMY _side plus a team to seize
//--- the other side's commander seat. The honest vote (GUI_Commander_VoteMenu.sqf) sends
//--- [side group player, votedTeam], where votedTeam is either objNull ("AI Commander", a stand-
//--- down) or an own-side team. Without the acting player in the payload we cannot fully bind the
//--- request to its sender (the caller is a SHARED file outside this cluster - see clientSendChanges).
//--- Server-side we can still: require valid side logic, and - for a NON-null assigned team - reject
//--- assigning a team that does not actually belong to _side (mirrors RequestClaimCommander's
//--- `side (leader _team) != _side` membership test). The objNull stand-down vote is preserved.
//--- fix(hunt): both rejections were exitWith INSIDE nested then{} blocks - on A2-OA that exits only the
//--- block and FALLS THROUGH to the seat assignment below, so a "rejected" cross-side forge still seized
//--- the enemy commander seat. Latch + top-scope exit (same repair as RequestVehicleLock.sqf).
_rejected = false;
if ((missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0) then {
	if (isNull _logik) then {
		_rejected = true;
		["WARNING", "RequestNewCommander.sqf: rejected request - side logic is null."] Call WFBE_CO_FNC_LogContent;
	};
	if (!_rejected && {!isNull _assigned_commander}) then {
		if (side (leader _assigned_commander) != _side) then {
			_rejected = true;
			["WARNING", Format ["RequestNewCommander.sqf: rejected cross-side commander assignment (team side %1 != request side %2).", side (leader _assigned_commander), _side]] Call WFBE_CO_FNC_LogContent;
		};
	};
};
if (_rejected) exitWith {};

if ((_logik getVariable "wfbe_votetime") <= 0) then {
	_team = -1;

	//--- Set the commander
	_logik setVariable ["wfbe_commander", _assigned_commander, true];
	[_side, _assigned_commander] Spawn WFBE_SE_FNC_AssignForCommander; //--- wiki-wins: AssignForCommander (Server_AssignNewCommander.sqf:10) already notifies clients; removed the duplicate SendToClients

};