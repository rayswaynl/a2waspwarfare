/*
	LS_WaveManager.sqf
	Last Stand horde mode - server-side wave manager.
	Runs only when IS_laststand_event=true; launched by initJIPCompatible.sqf on isServer.

	Flow:
	  PREP phase  -> broadcast buy-discount via ATTACK_WAVE_DETAILS, grant funds/supply, sleep.
	  ATTACK phase -> spawn (3 + wave#) east groups, order SAD to hold point, wait until clear.
	  Repeat up to LS_MaxWaves times.
	  All waves survived  -> failMission "END1" (mission-end; use the same END1 all other victories use).
	  Hold lost / tickets -> failMission "END1" (same end class; briefing/debrief screens handle flavour).

	Function/variable anchors confirmed from source:
	  - WFBE_CO_FNC_CreateTeam  (Common\Functions\Common_CreateTeam.sqf): [_list,_pos,_side,_lockVehicles,_team,_global,_probability]
	  - AIMoveTo                 (Server\AI\Orders\AI_MoveTo.sqf, registered in Init_Server.sqf line 19): [_team,_dest,_mission,_radius]
	  - ChangeSideSupply         (Common\Init\Init_Common.sqf line 19): [_side,_amount,_reason]
	  - ChangeTeamFunds          (Common\Init\Init_Common.sqf line 20): [_team,_amount]
	  - WFBE_HEADLESSCLIENTS_ID  (Init_Server.sqf line 147): array of HC logic groups
	  - WFBE_<SIDE>AITEAMTEMPLATES: read via Format["WFBE_%1AITEAMTEMPLATES", str east] (== "EAST")
	  - ATTACK_WAVE_DETAILS publicVariable: triggers AttackWave.sqf EH on all machines ([side,modifier,durationSecs])

	A2-dialect: private ["_x",...], forEach, _arr set [count _arr, _x], no pushBack/params[/findIf/select{}.
*/

private ["_waveGroups","_templates","_hcs","_liveHc","_hcId","_group","_tmpl","_spawnPos","_markerName",
	"_w","_i","_n","_result","_units","_vehs","_grp","_crw","_allClear","_living","_u",
	"_prepDuration","_attackDuration","_discountModifier","_westLogik","_westTeam","_waveGroupsTemp"];

//--- Wait for server and town init to complete.
waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};
waitUntil {!isNil "townInitServer" && {townInitServer}};
waitUntil {!isNil "WFBE_CO_FNC_CreateTeam"};
waitUntil {!isNil "AIMoveTo"};
waitUntil {!isNil "ChangeSideSupply"};
waitUntil {!isNil "ChangeTeamFunds"};

diag_log "[WFBE-LS] LS_WaveManager.sqf: Last Stand wave manager started.";

//--- Global state variables (publicised so clients can display them if needed).
LS_WaveNumber = 0;
LS_MaxWaves   = 10;
LS_Tickets    = 30;

//--- Hold position: prefer a named marker set by the map-specific mission (e.g. Namalsk).
//--- Fall back to a position near the centre of the map if the marker is absent.
LS_HoldPos = getMarkerPos "ls_holdpoint";
if ((LS_HoldPos select 0) == 0 && {(LS_HoldPos select 1) == 0}) then {
	//--- Marker absent or at world origin: use a hardcoded central fallback.
	LS_HoldPos = [5000, 5000, 0];
	diag_log "[WFBE-LS] ls_holdpoint marker not found - using fallback position [5000,5000,0].";
};

publicVariable "LS_WaveNumber";
publicVariable "LS_MaxWaves";
publicVariable "LS_Tickets";
publicVariable "LS_HoldPos";

_prepDuration    = 120; //--- 2-minute buy window between waves.
_attackDuration  = 300; //--- Discount broadcast duration (5 min; cleared after wave).
_discountModifier = 0.5; //--- 50% price reduction during prep.

//--- Helper: gather east AI templates. Returns [] if templates not yet registered.
//--- Must be inline (no Call to an unregistered function) — A2-safe.

//--- Main wave loop.
while {!WFBE_GameOver && {LS_WaveNumber < LS_MaxWaves} && {LS_Tickets > 0}} do {

	// -------------------------------------------------------------------
	// PREP PHASE: grant west economy, broadcast discount, sleep prep window.
	// -------------------------------------------------------------------
	diag_log Format ["[WFBE-LS] Wave %1/%2 - PREP phase. Tickets: %3.", LS_WaveNumber + 1, LS_MaxWaves, LS_Tickets];

	//--- Grant west a per-wave supply + funds bonus.
	_westLogik = west Call WFBE_CO_FNC_GetSideLogic;
	_westTeam  = grpNull;
	if (!isNil "_westLogik") then {
		private ["_wt"];
		_wt = _westLogik getVariable ["wfbe_teams", []];
		if (!isNil "_wt" && {count _wt > 0}) then {_westTeam = _wt select 0};
	};

	//--- Supply grant (server->server, publicVariableServer path).
	[west, 5000, "Last Stand wave prep bonus"] Call ChangeSideSupply;

	//--- Funds grant to the first west team if available.
	if (!isNull _westTeam) then {
		[_westTeam, 20000] Call ChangeTeamFunds;
	};

	//--- Broadcast buy discount to all clients via ATTACK_WAVE_DETAILS EH (AttackWave.sqf).
	//--- Format: [side, priceModifier, durationSecs]. A modifier < 1 reduces purchase prices.
	ATTACK_WAVE_DETAILS = [west, _discountModifier, _attackDuration];
	publicVariable "ATTACK_WAVE_DETAILS";

	diag_log Format ["[WFBE-LS] PREP: granted 5000 supply + 20000 funds to west. Discount %1 active for %2s.", _discountModifier, _attackDuration];

	sleep _prepDuration;

	if (WFBE_GameOver) exitWith {};

	//--- Cancel the buy discount.
	ATTACK_WAVE_DETAILS = [west, 1, 0];
	publicVariable "ATTACK_WAVE_DETAILS";

	// -------------------------------------------------------------------
	// ATTACK PHASE: increment wave, spawn east groups, order SAD.
	// -------------------------------------------------------------------
	LS_WaveNumber = LS_WaveNumber + 1;
	publicVariable "LS_WaveNumber";

	diag_log Format ["[WFBE-LS] Wave %1/%2 - ATTACK phase.", LS_WaveNumber, LS_MaxWaves];

	//--- Gather east AI team templates.
	private ["_eastTemplates"];
	_eastTemplates = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", str east], []]; //--- matches the framework's Format["WFBE_%1AITEAMTEMPLATES",_side] storage
	if (isNil "_eastTemplates") then {_eastTemplates = []};

	//--- Number of groups to spawn this wave.
	private ["_groupCount"];
	_groupCount = 3 + LS_WaveNumber;

	//--- Collect live HC ids for offload.
	_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
	_liveHc = [];
	{
		if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {
			_liveHc = _liveHc + [owner (leader _x)];
		};
	} forEach _hcs;

	_waveGroups = [];

	_i = 0;
	while {_i < _groupCount && {!WFBE_GameOver}} do {

		//--- Pick a spawn position: prefer named markers ls_spawn_1..ls_spawn_8, else ring around hold.
		_markerName = Format ["ls_spawn_%1", (_i mod 8) + 1];
		_spawnPos   = getMarkerPos _markerName;
		if ((_spawnPos select 0) == 0 && {(_spawnPos select 1) == 0}) then {
			//--- No marker: ring 800-1200m around hold position.
			private ["_angle","_dist"];
			_angle = (_i / _groupCount) * 360;
			_dist  = 800 + (random 400);
			_spawnPos = [
				(LS_HoldPos select 0) + (_dist * sin _angle),
				(LS_HoldPos select 1) + (_dist * cos _angle),
				0
			];
		};

		//--- Pick a template or fall back to a basic east infantry list.
		private ["_tmplList"];
		if (count _eastTemplates > 0) then {
			_tmplList = _eastTemplates select (_i mod (count _eastTemplates));
		} else {
			//--- Absolute fallback: generic east soldier class (map-agnostic).
			_tmplList = ["RUS_Soldier","RUS_Soldier","RUS_Soldier_GL","RUS_Soldier_MG","RUS_Soldier_Medic"];
		};

		//--- Spawn the group via WFBE_CO_FNC_CreateTeam.
		//--- Signature: [_list, _position, _side, _lockVehicles, _team, _global, _probability]
		//--- _global=false: no client-side marker/action setup (server-local wave AI).
		_result = [_tmplList, _spawnPos, east, false, grpNull, false] Call WFBE_CO_FNC_CreateTeam;

		_grp = _result select 2;

		if (!isNull _grp && {count (units _grp) > 0}) then {

			//--- HC offload if a live HC is available.
			if (count _liveHc > 0) then {
				_hcId = _liveHc select (_i mod (count _liveHc));
				{ _x setOwner _hcId } forEach (units _grp);
			};

			//--- Order the group to SAD (Search And Destroy) the hold position.
			//--- AIMoveTo: [_team, _destination, _mission, _radius]
			[_grp, LS_HoldPos, "SAD", 50] Call AIMoveTo;

			_waveGroups = _waveGroups + [_grp];
			diag_log Format ["[WFBE-LS] Wave %1: spawned group %2 (%3 units) at %4.", LS_WaveNumber, _i + 1, count (units _grp), _spawnPos];
		} else {
			diag_log Format ["[WFBE-LS] Wave %1: group %2 spawn failed (CreateTeam returned null/empty). Template: %3.", LS_WaveNumber, _i + 1, _tmplList];
		};

		_i = _i + 1;
	};

	// -------------------------------------------------------------------
	// WAIT PHASE: poll until no living east near hold OR game over.
	// -------------------------------------------------------------------
	diag_log Format ["[WFBE-LS] Wave %1: waiting for hold point to clear (%2 groups spawned).", LS_WaveNumber, count _waveGroups];

	_allClear = false;
	while {!_allClear && {!WFBE_GameOver}} do {

		//--- Count living east AI within 500m of the hold position.
		private ["_hostileNear","_uu"];
		_hostileNear = 0;
		_uu = allUnits; //--- A2: 'units east' is invalid (units takes a group/object); iterate allUnits + filter by side
		{
			_u = _x;
			if (alive _u && {side _u == east} && {!isPlayer _u} && {(_u distance LS_HoldPos) < 500}) then {
				_hostileNear = _hostileNear + 1;
			};
		} forEach _uu;

		if (_hostileNear == 0) then {
			_allClear = true;
		} else {
			sleep 10;
		};
	};

	if (WFBE_GameOver) exitWith {};

	//--- Short breather between waves.
	diag_log Format ["[WFBE-LS] Wave %1 cleared! Brief pause before next wave.", LS_WaveNumber];
	sleep 15;
};

if (WFBE_GameOver) exitWith {
	diag_log "[WFBE-LS] LS_WaveManager.sqf: WFBE_GameOver set externally - exiting wave manager.";
};

// -------------------------------------------------------------------
// END STATE
// -------------------------------------------------------------------
if (LS_Tickets <= 0) then {
	//--- Tickets exhausted: mission failure.
	diag_log "[WFBE-LS] LS_WaveManager.sqf: Tickets exhausted - mission failed.";
	WFBE_GameOver = true;
	gameOver = true;
	sleep 5;
	failMission "END1";
} else {
	//--- All waves survived: mission success.
	diag_log "[WFBE-LS] LS_WaveManager.sqf: All waves survived - Last Stand victory!";
	WFBE_GameOver = true;
	gameOver = true;
	sleep 5;
	endMission "END1"; //--- WIN: endMission (victory debrief), not failMission
};
