/*
	AI-commander team direction markers (task #3).
	Tracks WFBE_ACTIVE_AICOM_TEAMS (public [[leaderUnit, sideID, dir, team], ...] maintained
	by Server_HandleSpecial.sqf via the aicom-team-created / -ended / -heading cases) and keeps
	a local side-coloured mil_arrow2 on each commander team's leader. FRIENDLY-ONLY: like the
	patrol markers, a player only ever sees their OWN side's commander/HQ teams (the server feed
	carries ALL sides, the client filters to the joined side - enemy HQ positions are an intel
	leak and must never be drawn). The arrow direction is the server-fed
	objective bearing (slot 2), patched only when it moves >7 deg. Self-contained loop (does not
	reuse MarkerUpdate): create, follow every ~8s, delete when the leader dies or the entry drops.
*/

scriptName "Client\FSM\updateaicommarkers.sqf";

private ["_list","_tracked","_keep","_unit","_sid","_dir","_team","_mk","_known","_i","_k","_color","_x2","_present","_t","_mySid","_pos","_lastPos","_lastDir","_dirDiff","_t0","_diagTicks","_ownN","_reqSent","_reqTicks","_typeTag","_label","_ldr"];

//--- B63 (Ray 2026-06-21): BOUNDED gate. The loop must wait for client init, but if a blocking
//--- init waitUntil ever stalls, the old unbounded `waitUntil {clientInitComplete}` would suppress
//--- the own-side commander-team arrows forever. Proceed anyway after 90s of in-game time so the
//--- arrows are never permanently gated. (time is paused on the loading screen, so this can't fire
//--- prematurely during a genuine load.)
_t0 = time;
waitUntil {(!isNil "clientInitComplete" && {clientInitComplete}) || ((time - _t0) > 90)};
diag_log format ["[WFBE][B63 AICOM-MARK] loop live after %1s (clientInitComplete=%2)", round (time - _t0), (!isNil "clientInitComplete" && {clientInitComplete})];

_tracked = []; //--- [team, markerName] pairs (team is the stable key; leader can change)
_i = 0;
_diagTicks = 0;

//--- B74.2 (Ray 2026-06-23): FEED-GAP REQUEST. The B63 JIP catch-up (Server_OnPlayerConnected targeted
//--- publicVariableClient) + the server_side_patrols ~20s re-broadcast usually deliver WFBE_ACTIVE_AICOM_TEAMS,
//--- but a publicVariable is NOT JIP-durable in A2-OA and the catch-up can be MISSED on some joins (it races the
//--- connect/init path) -> feed=0 for the first ~60s and the own-side arrows never draw (the recurring
//--- "my player marker gone"). Belt-and-braces: if the loop is live and the feed is still empty, ask the server to
//--- targeted-rebroadcast ONCE (publicVariableServer a request var carrying this client's network id), then re-check
//--- on the next early ticks. Bounded so a genuinely-empty feed (no AICOM teams yet) doesn't request forever.
_reqSent = false;
_reqTicks = 0;

while {true} do {
	//--- Lane 252: after match end, remove local AICOM markers and stop this idle loop.
	if (gameOver) exitWith {
		if (markerType "wfbe_aicom_objective_mk" != "") then {deleteMarkerLocal "wfbe_aicom_objective_mk"};
		{
			_mk = _x select 1;
			if (markerType _mk != "") then {deleteMarkerLocal _mk};
		} forEach _tracked;
	};

	_list = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];

	//--- B74.2: bounded feed-gap recovery. Only while the feed is empty AND we are still early (first ~12 ticks).
	//--- Send the PLAYER OBJECT (not a network id) so the server can resolve `owner _player` for the targeted
	//--- publicVariableClient - the SAME proven pattern as REQUEST_SUPPLY_VALUE (Server_PV_RequestSupplyValue.sqf),
	//--- which avoids the A3-only `clientOwner` command (unreliable in A2-OA 1.64). The server handler
	//--- (Init_Server WFBE_ReqAicomFeed) pushes BOTH WFBE_ACTIVE_AICOM_TEAMS and WFBE_ACTIVE_PATROLS back to exactly
	//--- this client. Re-arm the request a couple of times in case the first request var is itself dropped
	//--- (publicVariableServer is also not guaranteed), then stop (a quiet round legitimately has 0 teams).
	if (count _list == 0 && {!isNull player} && {_reqTicks < 12}) then {
		_reqTicks = _reqTicks + 1;
		if (!_reqSent || {(_reqTicks % 4) == 0}) then {
			_reqSent = true;
			WFBE_ReqAicomFeed = player;
			publicVariableServer "WFBE_ReqAicomFeed";
			diag_log format ["[WFBE][B74.2 AICOM-MARK] feed empty after %1 ticks - requested targeted rebroadcast (player=%2).", _reqTicks, player];
		};
	};
	//--- FRIENDLY-ONLY (intel-leak fix, hardened): a player only ever sees their OWN side's
	//--- commander/HQ teams. Use the SAME stable joined-side id the working patrol-marker loop
	//--- uses (WFBE_Client_SideID = sideID, captured at client init) instead of a per-tick
	//--- (side player) lookup. (side player) can resolve to a different/transient side for a
	//--- brief window (respawn, JIP, team-switch), and any tick where it did would let ENEMY
	//--- entries past the _sid==_mySid guard and paint enemy HQ-team arrows on the map. The
	//--- joined-side id never drifts, so enemy teams can never be drawn. Hold the loop until the
	//--- joined side is known (early init) - never default to a matching/leaky value, and never
	//--- compare against nil.
	waitUntil {!isNil "WFBE_Client_SideID"};
	_mySid = WFBE_Client_SideID;

	//--- B63 (Ray 2026-06-21) diag: first 6 ticks, report feed health so a JIP RPT is conclusive about
	//--- whether the own-team arrows fail at the FEED (count 0 = PV not arriving), the FILTER (ownSide 0
	//--- while feed>0) or DRAWING (ownSide>0 but tracked 0). count CODE ARRAY is A2-OA-safe.
	if (_diagTicks < 6) then {
		_diagTicks = _diagTicks + 1;
		_ownN = {(_x select 1) == _mySid} count _list;
		diag_log format ["[WFBE][B63 AICOM-MARK] tick %1: WFBE_Client_SideID=%2 feed=%3 ownSide=%4 tracked=%5", _diagTicks, _mySid, count _list, _ownN, count _tracked];
	};

	//--- New commander teams - FRIENDLY side only (matches the friendly-only patrol markers).
	{
		_unit = _x select 0;
		_sid  = _x select 1;
		//--- slot 2 (server-fed objective bearing) is no longer used for the arrow; heading is read LIVE from the leader (DIR FIX below).
		_team = _x select 3;
		//--- B66: ARROW-VANISH FIX. Key liveness on the TEAM, not on slot0 (the leader captured once
		//--- at team-created and only refreshed server-side from B66 on). Test the team has a living
		//--- member and draw at its CURRENT leader, so an original-leader death (team alive) keeps the arrow.
		if (!isNull _team && {({alive _x} count units _team) > 0} && {_sid == _mySid}) then {
			_known = false;
			for "_k" from 0 to (count _tracked - 1) do {
				if (((_tracked select _k) select 0) == _team) then {_known = true};
			};
			if (!_known) then {
				//--- Side colour by entry sideID (covers enemy teams the local player has no logic for).
				_color = switch (_sid) do {
					case WFBE_C_WEST_ID: {missionNamespace getVariable "WFBE_C_WEST_COLOR"};
					case WFBE_C_EAST_ID: {missionNamespace getVariable "WFBE_C_EAST_COLOR"};
					case WFBE_C_GUER_ID: {missionNamespace getVariable "WFBE_C_GUER_COLOR"};
					default {"ColorBlack"};
				};
				_i = _i + 1;
				_mk = Format["wfbe_aicommarker_%1", _i];
				_ldr = leader _team;
				_pos = getPos _ldr; //--- B66: draw at the team CURRENT leader (slot0 may be a dead/old leader)
				//--- DIR FIX (Game 2026-06-29): use the leader's LIVE heading (getDir), read client-side every tick
				//--- like the working patrol-marker arrows (updatepatrolmarkers.sqf:38/66), NOT the server-fed slot-2
				//--- OBJECTIVE BEARING (_x select 2). The objective bearing points straight at the target town, so on
				//--- a road march (leader following a road bend) the arrow pointed at the town instead of where the team
				//--- is actually moving/facing - "direction of movement not shown properly". getDir on the replicated
				//--- leader is the true heading and is A2-OA-1.64-safe (no binary getDir).
				_dir = getDir _ldr;
				//--- TYPE TAG (Game 2026-06-29): classify the team by its heaviest hull and append a compact
				//--- INF / LGHT / HVY / AIR tag so a player can read each commander team's role straight off the map.
				//--- Derived from the LIVE composition (replicated isKindOf works on remote vehicles), so it is correct
				//--- for HC-founded teams too (which skip the server-side wfbe_teamtype index path). Priority: any Air
				//--- hull -> AIR; else any Tank (tracked armour/IFV) -> HVY; else any wheeled APC/Car -> LGHT; else INF.
				_typeTag = "INF";
				{
					if (!isNull _x && {alive _x}) then {
						private "_veh"; _veh = vehicle _x;
						if (_veh != _x) then {
							if (_veh isKindOf "Air") exitWith {_typeTag = "AIR"};
							//--- fix/aicom-arty-lifecycle (2026-07-21, owner-live report: HQ-team artillery batteries
							//--- never show [ARTY] on the map). ROOT CAUSE: this classifier had no artillery branch at
							//--- all - a GRAD/MLRS hull is Tank- or Car-classed, so it silently fell into the generic
							//--- HVY/LGHT bucket below instead of a dedicated tag. Reuses the mission's own
							//--- IsMobileArtillery self-propelled-hull classifier (same one AI_Commander_Base.sqf/
							//--- Strategy.sqf use) so an artillery hull is tagged ARTY before the generic Tank/Car
							//--- checks ever run on it.
							if ([_veh, side _team] Call IsMobileArtillery) then {
								if (_typeTag != "AIR") then {_typeTag = "ARTY"};
							} else {
								if (_veh isKindOf "Tank") then {if (_typeTag != "AIR" && {_typeTag != "ARTY"}) then {_typeTag = "HVY"}};
								if ((_veh isKindOf "Wheeled_APC") || {_veh isKindOf "Car"}) then {if (_typeTag == "INF") then {_typeTag = "LGHT"}};
							};
						};
					};
				} forEach (units _team);
				_label = Format ["HQ Team [%1]", _typeTag];
				createMarkerLocal [_mk, _pos];
				_mk setMarkerTypeLocal "mil_arrow2"; //--- matches the patrol / team arrows.
				_mk setMarkerColorLocal _color;
				_mk setMarkerSizeLocal [0.7,0.7];
				_mk setMarkerTextLocal _label;
				_mk setMarkerDirLocal _dir;
				//--- PERF4 - cache last pos/dir (slots 2/3) + the cached label (slot 4) so the follow pass skips no-op writes.
				_tracked = _tracked + [[_team, _mk, _pos, _dir, _label]];
			};
		};
	} forEach _list;

	//--- Follow / drop. The team is re-checked against the public list each tick (presence only);
	//--- the arrow's POSITION and HEADING are read LIVE from the team's current leader (not the
	//--- server-fed slot-2 objective bearing - see the DIR FIX note in the create pass). Drop when
	//--- the team is gone from the list, null or its leader is dead.
	_keep = [];
	{
		_team = _x select 0;
		_mk   = _x select 1;
		//--- Find this team's current entry in the public list (presence test only).
		_present = false;
		{
			if ((_x select 3) == _team) then {_present = true};
		} forEach _list;

		//--- B66: ARROW-VANISH FIX. Key liveness on the TEAM (still test the team directly so a tick
		//--- between leader-death and the next heading patch never drops the arrow). Draw at the
		//--- team CURRENT leader.
		if (_present && {!isNull _team} && {({alive _x} count units _team) > 0}) then {
			_entry = _x; _ldr = leader _team; //--- B66 + Game 2026-06-29: _entry captured because the units-forEach classifier below clobbers _x (A2-OA nested forEach does NOT restore it)
			//--- PERF4 - only re-write pos/dir when the team actually moved/turned, sparing a stationary
			//--- HQ team two setMarker* writes every ~8s for zero visible change.
			_pos = getPos _ldr;
			_lastPos = _x select 2;
			if (isNil "_lastPos" || {(_pos distance _lastPos) > 3}) then {
				_mk setMarkerPosLocal _pos;
				_x set [2, _pos];
			};
			//--- DIR FIX (Game 2026-06-29): live leader heading, like the patrol arrows (see create pass note).
			_dir = getDir _ldr;
			_lastDir = _x select 3;
			if (isNil "_lastDir") then {_lastDir = -999};
			_dirDiff = abs (_dir - _lastDir);
			if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
			if (_lastDir < 0 || _dirDiff > 7) then { //--- _lastDir<0 forces the first write past the seed (mirrors team/patrol loops)
				_mk setMarkerDirLocal _dir;
				_x set [3, _dir];
			};
			//--- TYPE TAG refresh: re-derive the INF/LGHT/HVY/AIR tag from the live composition and re-label
			//--- only when it changed (cached in slot 4), so a team that loses its armour/air updates its tag
			//--- without a per-tick setMarkerText. Same classifier + priority as the create pass.
			_typeTag = "INF";
			{
				if (!isNull _x && {alive _x}) then {
					private "_veh"; _veh = vehicle _x;
					if (_veh != _x) then {
						if (_veh isKindOf "Air") exitWith {_typeTag = "AIR"};
						//--- fix/aicom-arty-lifecycle (2026-07-21): same ARTY classifier fix as the create pass
						//--- above - see that block's comment for the root cause. Kept identical here so the
						//--- refresh pass agrees with the create pass on which teams read as ARTY.
						if ([_veh, side _team] Call IsMobileArtillery) then {
							if (_typeTag != "AIR") then {_typeTag = "ARTY"};
						} else {
							if (_veh isKindOf "Tank") then {if (_typeTag != "AIR" && {_typeTag != "ARTY"}) then {_typeTag = "HVY"}};
							if ((_veh isKindOf "Wheeled_APC") || {_veh isKindOf "Car"}) then {if (_typeTag == "INF") then {_typeTag = "LGHT"}};
						};
					};
				};
			} forEach (units _team);
			_label = Format ["HQ Team [%1]", _typeTag];
			if (_label != (_entry select 4)) then {
				_mk setMarkerTextLocal _label;
				_entry set [4, _label];
			};
			_keep = _keep + [_entry];
		} else {
			deleteMarkerLocal _mk;
		};
	} forEach _tracked;
	_tracked = _keep;

	//--- AICOM v2 PREVIEW: draw the AI commander's CURRENT OBJECTIVE town for the joined side as a
	//--- single mil_objective marker (side-keyed PV published by AI_Commander.sqf). FRIENDLY-ONLY:
	//--- reads only WFBE_AICOM_OBJ*_<_mySid> (the joined side), like the own-side arrow filter above -
	//--- the enemy's objective var is never read, so no intel leak. One marker, moved/relabelled on change.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_INTENT_HUD", 1]) > 0) then {
		private ["_objPos","_objNm","_objMk","_objCol"];
		_objPos = missionNamespace getVariable [format ["WFBE_AICOM_OBJPOS_%1", _mySid], [0,0,0]];
		_objNm  = missionNamespace getVariable [format ["WFBE_AICOM_OBJNAME_%1", _mySid], ""];
		_objMk = "wfbe_aicom_objective_mk";
		if (!gameOver && {_objNm != ""} && {(_objPos select 0) != 0}) then {
			_objCol = switch (_mySid) do {
				case WFBE_C_WEST_ID: {missionNamespace getVariable "WFBE_C_WEST_COLOR"};
				case WFBE_C_EAST_ID: {missionNamespace getVariable "WFBE_C_EAST_COLOR"};
				case WFBE_C_GUER_ID: {missionNamespace getVariable "WFBE_C_GUER_COLOR"};
				default {"ColorBlack"};
			};
			if (markerType _objMk == "") then {
				createMarkerLocal [_objMk, _objPos];
				_objMk setMarkerTypeLocal "mil_objective";
				_objMk setMarkerColorLocal _objCol;
				_objMk setMarkerSizeLocal [1,1];
			};
			_objMk setMarkerPosLocal _objPos;
			_objMk setMarkerTextLocal (Format ["AI OBJ: %1", _objNm]);
		} else {
			if (markerType _objMk != "") then {deleteMarkerLocal _objMk};
		};
	};

	if (visibleMap || shownGPS) then {sleep 0.5} else {sleep 8};  //--- A2-fix 2026-06-14: map-aware cadence (smooth arrows while map open, idle slow otherwise)
};
