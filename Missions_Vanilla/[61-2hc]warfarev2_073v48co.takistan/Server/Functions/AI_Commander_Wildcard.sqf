/*
	AI Commander Wildcard Events - one free random event per AI-commanded side per interval.
	feat/ai-commander v0.6.  Server-side; one instance spawned per side from Init_Server.
	Parameter: _this = side.

	Runs UNATTENDED in AI-vs-AI eval rounds.  Design constraints:
	  - First event fires after one full interval (not at minute 0).
	  - One failed event must never kill this loop.  Isolation = the apply body
	    runs inside [_side] spawn {...} so a runtime error kills only that spawn.
	  - Re-checks liveness (wfbe_aicom_running) each cycle; a human taking command
	    suppresses wildcards until the AI is back in full command.
	  - All external reads use getVariable with defaults so nil never throws.

	Event pool (three events; W4/W5 omitted - see below):
	  W1  WAR CHEST    — AI funds += 25% of FUNDS_START (always eligible; fallback).
	  W2  SUPPLY DROP  — side supply += 1500, capped at WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT.
	  W3  BONUS PATROL — one extra patrol at the side's current tier, cap bypass for
	                     this one spawn (counts naturally afterward).
	                     Ineligible when: Patrols upgrade = 0, no owned towns, pool empty.

	W4 RESEARCH SURGE omitted: ProcessUpgrade sleeps the full research timer and sets
	wfbe_upgrading exclusively - there is no safe instant-complete path without
	hand-rolling upgrade state mutation.  Flagged as v2.

	W5 GUNSHIP GIFT omitted: no existing produce/team path that avoids new machinery.
	Flagged as v2.
*/

private ["_side","_logik","_sideID","_interval","_enabled","_humanCmd","_cmdTeam",
         "_fundsStart","_bonus","_curFunds","_pool","_draw","_redraw","_eligible",
         "_upgrades","_lvl","_owned","_hq","_hcs","_live","_tier","_template","_home",
         "_active","_supply","_maxSupply","_supplyGrant","_detail","_result"];

_side    = _this;
_logik   = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_sideID  = (_side) Call WFBE_CO_FNC_GetSideID;

_interval = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL", 1800];
_enabled  = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD", 1];

["INITIALIZATION", Format ["AI_Commander_Wildcard.sqf: worker started for %1 (interval=%2s, enabled=%3).", str _side, _interval, _enabled]] Call WFBE_CO_FNC_AICOMLog;

//--- First event fires after one full interval.
sleep _interval;

while {!gameOver} do {

	//--- Liveness gate: only fire during full AI command (same gate as economy workers in AI_Commander.sqf).
	_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
	_humanCmd = false;
	if (!isNull _cmdTeam) then {
		if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
	};

	if (!_humanCmd && {(_logik getVariable ["wfbe_aicom_running", false])}) then {

		//--- Isolate the draw+apply body: a throw kills only this spawn, not the loop.
		[_side] spawn {
			private ["_side","_logik","_sideID","_fundsStart","_bonus","_curFunds",
			         "_upgrades","_lvl","_owned","_hq","_tier","_pool","_template",
			         "_home","_active","_hcs","_live","_supply","_maxSupply",
			         "_supplyGrant","_draw","_redraw","_eligible","_w3Eligible","_detail","_result"];

			_side   = _this select 0;
			_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
			_sideID = (_side) Call WFBE_CO_FNC_GetSideID;

			if (isNil "_logik") exitWith {};

			//--- Build eligibility flags.
			//--- W2: supply drop — always eligible (ChangeSideSupply already caps).
			//--- W3: bonus patrol — need Patrols upgrade >= 1, at least one owned town, non-empty pool.
			_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
			_lvl      = if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_PATROLS}) then {_upgrades select WFBE_UP_PATROLS} else {0};

			_owned = [];
			{if ((_x getVariable "sideID") == _sideID) then {_owned = _owned + [_x]}} forEach towns;
			_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;

			_tier    = switch (_lvl) do {case 1: {"LIGHT"}; case 2: {"MEDIUM"}; default {"HEAVY"}};
			_pool    = missionNamespace getVariable [Format ["WFBE_%1_PATROL_%2", _side, _tier], []];

			//--- W3 is eligible only when: lvl>=1, towns owned, pool non-empty, HQ alive.
			_w3Eligible = (_lvl >= 1 && {count _owned > 0} && {count _pool > 0} && {!isNull _hq} && {alive _hq});

			//--- Draw: 1=WAR CHEST, 2=SUPPLY DROP, 3=BONUS PATROL.
			//--- Up to 3 re-draws on ineligible; fallback = W1 (always eligible).
			_draw   = 1 + floor(random 3);
			_redraw = 0;
			while {_draw == 3 && {!_w3Eligible} && {_redraw < 3}} do {
				_draw   = 1 + floor(random 3);
				_redraw = _redraw + 1;
			};
			if (_draw == 3 && {!_w3Eligible}) then {_draw = 1};   //--- Fallback W1.

			_eligible = true;
			_result   = "applied";
			_detail   = "";

			//--- Apply.
			switch (_draw) do {

				//--- W1: WAR CHEST — funds += 25% of this side's configured FUNDS_START.
				case 1: {
					_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
					_bonus      = round(_fundsStart * 0.25);
					_curFunds   = (_side) Call GetAICommanderFunds;
					[_side, _bonus] Call ChangeAICommanderFunds;
					_detail = Format ["funds_before=%1 bonus=%2 funds_after=%3", _curFunds, _bonus, (_side) Call GetAICommanderFunds];
				};

				//--- W2: SUPPLY DROP — side supply += 1500 (ChangeSideSupply caps at WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT).
				case 2: {
					_supply    = (_side) Call WFBE_CO_FNC_GetSideSupply;
					_maxSupply = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 99999];
					_supplyGrant = 1500 min (_maxSupply - (if (isNil "_supply") then {0} else {_supply}));
					if (_supplyGrant > 0) then {
						[_side, _supplyGrant, "AI Commander Wildcard: supply drop.", false] Call ChangeSideSupply;
						_detail = Format ["supply_before=%1 grant=%2 max=%3", _supply, _supplyGrant, _maxSupply];
					} else {
						_result = "ineligible";
						_detail = Format ["supply already at cap %1", _maxSupply];
					};
				};

				//--- W3: BONUS PATROL — one extra patrol ignoring the cap for this spawn.
				case 3: {
					_template = _pool select floor(random count _pool);
					_home     = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity;
					_active   = _logik getVariable ["wfbe_side_patrols", 0];
					//--- Book the slot (same pattern as server_side_patrols.sqf).
					_logik setVariable ["wfbe_side_patrols", _active + 1];
					_logik setVariable ["wfbe_side_patrol_last", time];
					//--- Dispatch to a live HC if available, else server.
					_hcs  = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
					_live = [];
					{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;
					if (count _live > 0) then {
						[leader(_live select floor(random count _live)), "HandleSpecial", ["delegate-sidepatrol", _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
					} else {
						[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
					};
					_detail = Format ["tier=%1 template=%2 from_town=%3 active_after=%4 hc=%5", _tier, _template, _home getVariable ["name","?"], _active + 1, count _live > 0];
				};
			};

			["INFORMATION", Format ["AI_Commander_Wildcard.sqf: [WILDCARD] side=%1 draw=W%2 result=%3 detail=(%4)", str _side, _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|WILDCARD_W" + str _draw + "|" + _result + "|" + _detail);
		};
	};

	sleep _interval;
};
