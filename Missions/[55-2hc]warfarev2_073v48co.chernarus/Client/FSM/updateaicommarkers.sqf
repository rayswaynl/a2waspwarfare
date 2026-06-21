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

private ["_list","_tracked","_keep","_unit","_sid","_dir","_team","_mk","_known","_i","_k","_color","_x2","_present","_t","_mySid","_pos","_lastPos","_lastDir","_dirDiff","_t0","_diagTicks","_ownN"];

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

while {true} do {
	_list = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
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
		_dir  = _x select 2;
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
				_pos = getPos (leader _team); //--- B66: draw at the team CURRENT leader (slot0 may be a dead/old leader)
				createMarkerLocal [_mk, _pos];
				_mk setMarkerTypeLocal "mil_arrow2"; //--- matches the patrol / team arrows.
				_mk setMarkerColorLocal _color;
				_mk setMarkerSizeLocal [0.7,0.7];
				_mk setMarkerTextLocal "HQ Team";
				_mk setMarkerDirLocal _dir;
				//--- PERF4 - cache last pos/dir (slots 2/3) so the follow pass below skips no-op writes.
				_tracked = _tracked + [[_team, _mk, _pos, _dir]];
			};
		};
	} forEach _list;

	//--- Follow / drop. The entry's leader and dir are re-read from the public list each tick so the
	//--- arrow tracks the server-fed objective bearing; drop when the team is gone from the list, null
	//--- or its leader is dead.
	_keep = [];
	{
		_team = _x select 0;
		_mk   = _x select 1;
		//--- Find this team's current entry in the public list.
		_present = false;
		_unit = objNull;
		_dir  = 0;
		{
			if ((_x select 3) == _team) then {
				_present = true;
				_unit = _x select 0;
				_dir  = _x select 2;
			};
		} forEach _list;

		//--- B66: ARROW-VANISH FIX. Key liveness on the TEAM (slot0 _unit is the server-fed leader,
		//--- now refreshed on leader-swap from B66 on, but still test the team directly so a tick
		//--- between leader-death and the next heading patch never drops the arrow). Draw at the
		//--- team CURRENT leader.
		if (_present && {!isNull _team} && {({alive _x} count units _team) > 0}) then {
			//--- PERF4 - only re-write pos/dir when the team actually moved/turned. The header already
			//--- promised "patched only when it moves >7 deg"; this makes the write match that intent and
			//--- spares a stationary HQ team two setMarker* writes every ~8s for zero visible change.
			_pos = getPos (leader _team); //--- B66: current leader, not the (possibly stale slot0) _unit
			_lastPos = _x select 2;
			if (isNil "_lastPos" || {(_pos distance _lastPos) > 3}) then {
				_mk setMarkerPosLocal _pos;
				_x set [2, _pos];
			};
			_lastDir = _x select 3; //--- arrow tracks the server-fed objective heading.
			if (isNil "_lastDir") then {_lastDir = -999};
			_dirDiff = abs (_dir - _lastDir);
			if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
			if (_dirDiff > 7) then {
				_mk setMarkerDirLocal _dir;
				_x set [3, _dir];
			};
			_keep = _keep + [_x];
		} else {
			deleteMarkerLocal _mk;
		};
	} forEach _tracked;
	_tracked = _keep;

	if (visibleMap || shownGPS) then {sleep 0.5} else {sleep 8};  //--- A2-fix 2026-06-14: map-aware cadence (smooth arrows while map open, idle slow otherwise)
};
