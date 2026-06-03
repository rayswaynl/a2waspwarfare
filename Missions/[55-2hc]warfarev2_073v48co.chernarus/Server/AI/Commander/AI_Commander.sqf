/*
	AI Commander — per-side supervisor.
	feat/ai-commander. Server-side; one instance spawned per present side from Init_Server.
	Parameter: _this = side.

	Always running. Each tick it asks "should the AI be commanding this side right now?"
	(enabled AND no player commander AND HQ alive). While active it sets wfbe_aicom_running
	and drives the workers on their cadences. This single loop covers every takeover path
	(initial vote, re-vote, commander disconnect) — no edits to the vote/assign files needed.
*/

private ["_side","_logik","_active","_ltTypes","_ltUp","_ltTown","_ltProd"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- Wait for full server init before commanding.
waitUntil {sleep 1; !(isNil "serverInitFull")};

_ltTypes = 0; _ltUp = 0; _ltTown = 0; _ltProd = 0;

["INITIALIZATION", Format ["AI_Commander.sqf: supervisor started for %1.", str _side]] Call WFBE_CO_FNC_LogContent;

while {!gameOver} do {
	_active = ((missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0)
		&& {isNull ((_side) Call WFBE_CO_FNC_GetCommanderTeam)}
		&& {alive ((_side) Call WFBE_CO_FNC_GetSideHQ)};

	if (_active) then {
		if !(_logik getVariable ["wfbe_aicom_running", false]) then {
			_logik setVariable ["wfbe_aicom_running", true];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander ACTIVE (no player commander).", str _side]] Call WFBE_CO_FNC_LogContent;
		};

		if (time - _ltTypes > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TYPES_INTERVAL")) then {
			(_side) Call WFBE_SE_FNC_AI_Com_AssignTypes;
			_ltTypes = time;
		};
		if (time - _ltUp > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL")) then {
			if !(_logik getVariable ["wfbe_upgrading", false]) then {(_side) Call WFBE_SE_FNC_AI_Com_Upgrade};
			_ltUp = time;
		};
		if (time - _ltTown > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOWN_INTERVAL")) then {
			(_side) Call WFBE_SE_FNC_AI_Com_AssignTowns;
			_ltTown = time;
		};
		if (time - _ltProd > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL")) then {
			(_side) Call WFBE_SE_FNC_AI_Com_Produce;
			_ltProd = time;
		};
	} else {
		if (_logik getVariable ["wfbe_aicom_running", false]) then {
			_logik setVariable ["wfbe_aicom_running", false];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander STOPPED (player commander / HQ down / disabled).", str _side]] Call WFBE_CO_FNC_LogContent;
		};
	};

	sleep 30;
};
