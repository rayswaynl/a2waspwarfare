/*
	AI Commander - per-side supervisor.
	feat/ai-commander. Server-side; one instance spawned per present side from Init_Server.
	Parameter: _this = side.

	Always running. Each tick it asks "is the AI commanding this side right now, and how?"
	  - No human commander -> FULL: executor + town auto-assign + economy (types/upgrade/produce).
	  - Human commander     -> ASSIST (hybrid): executor + town auto-assign for DELEGATED teams only,
	                           no economy (rule A: the AI never spends while a human commands).
	The executor (every tick) turns explicit Move/Patrol/Defend orders into waypoints - for the AI's own
	orders AND the human commander's (which are otherwise inert). Covers every takeover path (vote, re-vote,
	disconnect) with no edits to the vote/assign files.
*/

private ["_side","_logik","_active","_ltTypes","_ltUp","_ltTown","_ltProd","_ltBase","_ltTeams","_humanCmd","_cmdTeam","_prevHuman","_state","_prevState","_doctrine","_order","_inject","_new","_entry","_anchor"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- Wait for full server init before commanding.
waitUntil {sleep 1; !(isNil "serverInitFull")};

//--- V0.2: pick a doctrine once - the primary factory path this AI builds around.
if (isNil {_logik getVariable "wfbe_aicom_doctrine"}) then {
	_doctrine = if (random 1 > 0.5) then {"HF"} else {"LF"};
	_logik setVariable ["wfbe_aicom_doctrine", _doctrine];
	["INFORMATION", Format ["AI_Commander.sqf: [%1] doctrine picked: %2 (primary factory path).", str _side, _doctrine]] Call WFBE_CO_FNC_LogContent;

	//--- Prioritize Patrols research (and the heavy line under HF doctrine) by injecting
	//--- entries after their prerequisite anchors in this side's AI upgrade order.
	//--- Check_Upgrades already appended them at the END; an early duplicate is harmless
	//--- (the upgrade worker skips entries whose target level is already reached).
	_order = missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side];
	if (!isNil "_order" && {!isNil "WFBE_UP_PATROLS"}) then {
		_inject = [
			[[WFBE_UP_LIGHT,1],  [WFBE_UP_PATROLS,1]],
			[[WFBE_UP_HEAVY,2],  [WFBE_UP_PATROLS,2]],
			[[WFBE_UP_HEAVY,3],  [WFBE_UP_PATROLS,3]]
		];
		if (_doctrine == "HF") then {
			_inject = [[[WFBE_UP_GEAR,1], [WFBE_UP_HEAVY,1]]] + _inject;
		};
		_new = [];
		{
			_entry = _x;
			_new = _new + [_entry];
			{
				_anchor = _x select 0;
				if ((_entry select 0) == (_anchor select 0) && {(_entry select 1) == (_anchor select 1)}) then {
					_new = _new + [_x select 1];
				};
			} forEach _inject;
		} forEach _order;
		missionNamespace setVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], _new];
		["INFORMATION", Format ["AI_Commander.sqf: [%1] upgrade order tuned (%2 -> %3 entries, Patrols prioritized).", str _side, count _order, count _new]] Call WFBE_CO_FNC_LogContent;
	};
};

_ltTypes = 0; _ltUp = 0; _ltTown = 0; _ltProd = 0; _ltBase = 0; _ltTeams = 0;
_prevHuman = false; _prevState = "";

["INITIALIZATION", Format ["AI_Commander.sqf: supervisor started for %1.", str _side]] Call WFBE_CO_FNC_LogContent;

while {!gameOver} do {
	_active = false;
	if ((missionNamespace getVariable "WFBE_C_AI_COMMANDER_ENABLED") > 0) then {
		if (alive ((_side) Call WFBE_CO_FNC_GetSideHQ)) then {_active = true};
	};

	if (_active) then {
		_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		_humanCmd = false;
		if (!isNull _cmdTeam) then {
			if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
		};

		//--- Human just left -> clear leftover explicit orders so full-auto retakes cleanly.
		if (_prevHuman) then {
			if (!_humanCmd) then {
				{ [_x, "towns"] Call SetTeamMoveMode; _x setVariable ["wfbe_exec_sig", []] } forEach (_logik getVariable ["wfbe_teams", []]);
			};
		};
		_prevHuman = _humanCmd;

		//--- Lifecycle log + running flag (full command only; income routes to aicom_funds only with no human).
		_state = if (_humanCmd) then {"assist"} else {"full"};
		if (_state != _prevState) then {
			_logik setVariable ["wfbe_aicom_running", !_humanCmd];
			if (_state == "full")   then {["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander ACTIVE (full command).", str _side]] Call WFBE_CO_FNC_LogContent};
			if (_state == "assist") then {["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander ASSIST (hybrid - human commander, executor only).", str _side]] Call WFBE_CO_FNC_LogContent};
			_prevState = _state;
		};

		//--- Executor: every tick (responsive explicit orders, human or AI).
		(_side) Call WFBE_SE_FNC_AI_Com_Execute;

		//--- Town auto-assign: worker self-gates per team by delegation.
		if (time - _ltTown > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOWN_INTERVAL")) then {
			(_side) Call WFBE_SE_FNC_AI_Com_AssignTowns; _ltTown = time;
		};

		//--- Economy: full command only (rule A - AI never spends under a human commander).
		if (!_humanCmd) then {
			//--- V0.2: build the base (HQ deploy -> doctrine build order -> defenses).
			if (time - _ltBase > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_BASE_INTERVAL", 60])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Base; _ltBase = time;
			};
			//--- V0.2: found AI combat teams up to the target (editor slots are not enough on AI-only sides).
			if (time - _ltTeams > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_INTERVAL", 90])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Teams; _ltTeams = time;
			};
			if (time - _ltTypes > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TYPES_INTERVAL")) then {
				(_side) Call WFBE_SE_FNC_AI_Com_AssignTypes; _ltTypes = time;
			};
			if (time - _ltUp > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL")) then {
				if !(_logik getVariable ["wfbe_upgrading", false]) then {(_side) Call WFBE_SE_FNC_AI_Com_Upgrade};
				_ltUp = time;
			};
			if (time - _ltProd > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL")) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Produce; _ltProd = time;
			};
		};
	} else {
		if (_prevState != "stopped") then {
			_logik setVariable ["wfbe_aicom_running", false];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander STOPPED (disabled / HQ down).", str _side]] Call WFBE_CO_FNC_LogContent;
			_prevState = "stopped"; _prevHuman = false;
		};
	};

	sleep (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TICK");
};
