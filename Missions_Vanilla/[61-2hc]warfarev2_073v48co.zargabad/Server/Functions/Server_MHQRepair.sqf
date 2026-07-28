Private ["_commanderTeam","_direction","_hq","_HQName","_logik","_MHQ","_position","_replacementPosition","_reqPlayer","_side","_sideID","_sideText"];

_side = _this select 0;
_reqPlayer = if (count _this > 1) then {_this select 1} else {objNull};
_sideText = str _side;
_sideID = (_side) Call GetSideID;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

//--- Reentrancy guard (idempotency): check+set the repair flag BEFORE _hq/_position are
//--- read, so two near-simultaneous requests cannot both capture the old HQ and orphan a
//--- freshly built MHQ (the old client-only flag was set mid-script, after capture).
if (_logik getVariable ['wfbe_hq_repairing', false]) exitWith {
	["WARNING", Format ["Server_MHQRepair.sqf: [%1] rejected - repair already in progress.", _sideText]] Call WFBE_CO_FNC_LogContent;
};
_logik setVariable ['wfbe_hq_repairing', true, true];

_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;

//--- Aliveness guard: only a DESTROYED HQ is repairable. The client (Action_RepairMHQ.sqf:6)
//--- already refuses when the HQ is alive, but the server must not trust the client - without
//--- this, any client could force-delete a living, fully deployed HQ. Release the flag we took.
if (alive _hq) exitWith {
	_logik setVariable ['wfbe_hq_repairing', false, true];
	["WARNING", Format ["Server_MHQRepair.sqf: [%1] rejected - HQ is alive; repair only rebuilds a destroyed HQ.", _sideText]] Call WFBE_CO_FNC_LogContent;
};
_position = getPos _hq;
if (count _this > 2) then {
	_replacementPosition = _this select 2;
	if (typeName _replacementPosition == "ARRAY" && {count _replacementPosition >= 2}) then {_position = _replacementPosition};
};
_direction = getDir _hq;

_commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if !(isNull _commanderTeam) then {
	if (isPlayer (leader _commanderTeam)) then {
		if (WF_A2_Vanilla) then {
			[getPlayerUID(leader _commanderTeam), "HandleSpecial", ["hq-setstatus", false]] Call WFBE_CO_FNC_SendToClients;
		} else {
			[leader _commanderTeam, "HandleSpecial", ["hq-setstatus", false]] Call WFBE_CO_FNC_SendToClient;
		};
	};
};



_MHQ = [missionNamespace getVariable Format["WFBE_%1MHQNAME", _sideText], _position, _sideID, _direction, true, false] Call WFBE_CO_FNC_CreateVehicle;
if (isNull _MHQ) exitWith {
	_logik setVariable ['wfbe_hq_repairing', false, true];
	["WARNING", Format ["Server_MHQRepair.sqf: [%1] replacement MHQ creation failed.", _sideText]] Call WFBE_CO_FNC_LogContent;
};
if (_side == west && !(IS_chernarus_map_dependent)) then {
	_MHQ setVehicleInit "this setObjectTexture [0,""Textures\lavbody_coD.paa""]";
	_MHQ setVehicleInit "this setObjectTexture [1,""Textures\lavbody2_coD.paa""]";
	_MHQ setVehicleInit "this setObjectTexture [2,""Textures\lav_hq_coD.paa""]";
	processinitcommands;
	};
_MHQ setVariable ["WFBE_Taxi_Prohib", true];
_MHQ setVariable ["wfbe_trashed", false];
_MHQ setVariable ["wfbe_side", _side];
_MHQ setVariable ["wfbe_structure_type", "Headquarters"];
_MHQ addEventHandler ['killed', {_this Spawn WFBE_SE_FNC_OnHQKilled}];
_MHQ setVelocity [0,0,-1];
_MHQ setVariable ["wfbe_trashable", false];
_MHQ addEventHandler ["hit",{_this Spawn BuildingDamaged}];
_logik setVariable ['wfbe_hq', _MHQ, true];
// if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE") > 0) then {_MHQ addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3] Call BuildingHandleDamages}]};
if (isMultiplayer) then {[_side, "HandleSpecial", ["set-hq-killed-eh", _MHQ]] Call WFBE_CO_FNC_SendToClients}; //--- WAVE-3 (60-audit): _mhq -> _MHQ (case-sensitive local was nil -> repaired HQ's killed round-ender wired to nothing). Since the Killed EH fires localy, we send the information to the existing clients, JIP clients need to have the event in init_client.sqf (if !deployed).


_logik setVariable ['wfbe_hq_deployed', false, true];
_logik setVariable ['wfbe_hq_repairing',false, true];
_logik setVariable ['cashrepaired', false, true]; //--- wiki-wins: reset so cash-repair works again after the HQ is rebuilt (Action_RepairMHQDepot set it true permanently)
_logik setVariable ['wfbe_hq_repair_count', (_logik getVariable ["wfbe_hq_repair_count", 0]) + 1, true]; //--- fable/fob-structures-seed: 2-arg default - nil-arith guard for any unseeded side
//--- [>1.62] Set the HQ to be local to the commander.
 _commanderTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
//--- fable/cleanup-locality-2 (PVF-class hunt, LOW): align with the isPlayer-guarded sibling send
//--- at the top of this file - an AI/absent commander makes this a dead-destination PVF.
if (isPlayer (leader _commanderTeam)) then {
	[leader _commanderTeam, "SetMHQLock", _MHQ] Call WFBE_CO_FNC_SendToClient;
};
[_side,"Mobilized", ["Base", _MHQ]] Spawn SideMessage;
deleteVehicle _hq;	

// Marty : Remove mark HQ wreck on map and broadcast boolean when HQ west is repaired
_marker_name = "HQ_WRECK_" + str(_side) ;
[_marker_name, 0]call WFBE_CL_FNC_Delete_Marker;	

// Marty : HQ has been repaired, allied clients will remove their local wreck marker.
if (_side == west) then 
{
	missionNamespace setVariable ["IS_WEST_HQ_ALIVE", true];
	publicVariable "IS_WEST_HQ_ALIVE";

	missionNamespace setVariable ["HQ_WEST_MARKER_INFOS", []];
	publicVariable "HQ_WEST_MARKER_INFOS";
};

if (_side == east) then 
{
	missionNamespace setVariable ["IS_EAST_HQ_ALIVE", true];
	publicVariable "IS_EAST_HQ_ALIVE";

	missionNamespace setVariable ["HQ_EAST_MARKER_INFOS", []];
	publicVariable "HQ_EAST_MARKER_INFOS";
};
// Marty : end.

["INFORMATION", Format ["Server_MHQRepair.sqf: [%1] MHQ has been repaired (requested by %2).", _sideText, name _reqPlayer]] Call WFBE_CO_FNC_LogContent;