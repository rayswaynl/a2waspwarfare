// Marty: Performance Audit locals and marker update cache.
private["_sideText","_label","_count","_marker","_markerIndex","_team","_leader","_leaderVehicle","_leaderChanged","_botUnitsInVehicle","_crewUnitsInVehicle","_cargoUnitsInVehicle","_crewText","_cargoText","_member","_memberVehicle","_roleUnit","_unitText","_updateAILeaders","_updateThisLeader","_nextAIUpdate","_playerAFKstate","_afkMarkerDiagnosticNextLog","_markerColor","_markerAlpha","_markerNames","_lastLeaders","_lastTexts","_lastAlphas","_lastColors","_lastPositions","_lastDirs","_pos","_dir","_lastPos","_lastDir","_dirDiff","_vel","_spd","_wfMenuDisplays","_mapConsumerVisible","_perfStart","_perfMarkerOps","_perfPlayerLeaders","_perfAILeaders","_perfSkippedWrites","_nextRebindCheck","_needRebind","_liveLeader","_cachedLeader","_liveHas","_cachedHas","_i"];

_sideText = sideJoinedText;
_label = "";
_count = 1;
_markerNames = [];
_lastLeaders = [];
_lastTexts = [];
_lastAlphas = [];
_lastColors = [];
_lastPositions = [];
_lastDirs = [];
_nextAIUpdate = 0;
_afkMarkerDiagnosticNextLog = 0;
_nextRebindCheck = 0;

// Marty: Any open Warfare dialog can contain or lead to a minimap view; keep team markers live while these are visible.
_wfMenuDisplays = [11000,12000,13000,14000,17000,20000,21000,22000,23000,503000,504000,505000,508000,511000];

// Marty: Create the local squad markers once and cache their names by team index.
{
	_marker = Format["%1AdvancedSquad%2Marker",_sideText,_count];
	_leader = objNull;
	createMarkerLocal [_marker,[0,0,0]];
	//--- MARKER-DIR ROOT-CAUSE FIX (Ray 2026-06-20, 3rd attempt): the previous two fixes only
	//--- changed the _dir VALUE (velocity->getDir->getDir-vehicle) but the arrow stayed wrong
	//--- because the marker ICON TYPE "Arrow" does not visibly rotate to setMarkerDir in A2-OA.
	//--- Every arrow in this mission that DOES track heading (patrol/AICOM/AAR loops) uses the
	//--- military marker "mil_arrow2" with setMarkerDirLocal; "Arrow" was the lone legacy type
	//--- that never got converted, so setMarkerDirLocal was a no-op on it. Switch to mil_arrow2
	//--- so the existing (correct) getDir heading below actually renders. A2-OA-1.64-safe.
	_marker setMarkerTypeLocal "mil_arrow2";
	_marker setMarkerDirLocal 0;
	_marker setMarkerSizeLocal [0.7,0.7];
	_marker setMarkerAlphaLocal 0;

	_markerColor = "ColorBlack";
	if !(isNil "_x") then {
		_leader = leader _x;
		if (player == _leader) then {_markerColor = "ColorOrange"};
		_marker setMarkerColorLocal _markerColor;
		_leader setVariable ["unitMarkerBlink", _marker, false];
		_leader setVariable ["OriginalMarkerColor", _markerColor, false];
	};

	_markerNames set [_count - 1, _marker];
	_lastLeaders set [_count - 1, _leader];
	_lastTexts set [_count - 1, ""];
	_lastAlphas set [_count - 1, -1];
	_lastColors set [_count - 1, _markerColor];
	//--- PERF4 - per-team pos/dir cache so the follow loop below skips no-op marker writes.
	_lastPositions set [_count - 1, [-99999,-99999,0]];
	_lastDirs set [_count - 1, -999];

	_count = _count + 1;
} forEach clientTeams;

while {!gameOver} do {
	// Marty: Only refresh marker state while the player can see map data through the map, GPS, or a Warfare dialog.
	_mapConsumerVisible = visibleMap || shownGPS;
	if (!_mapConsumerVisible) then {
		{
			if (!isNull (findDisplay _x)) exitWith {_mapConsumerVisible = true};
		} forEach _wfMenuDisplays;
	};

	if (!_mapConsumerVisible) then {
		sleep 0.5;
	} else {
		// Marty: Performance Audit timing for the visible local team marker update loop.
		_perfStart = diag_tickTime;
		_perfMarkerOps = 0;
		_perfPlayerLeaders = 0;
		_perfAILeaders = 0;
		_perfSkippedWrites = 0;
		_updateAILeaders = time >= _nextAIUpdate;
		if (_updateAILeaders) then {_nextAIUpdate = time + 1};

		_count = 1;
		//--- B64 (Ray 2026-06-21) PLAYER-ARROW REGRESSION FIX. The B62 own-side reconciliation
		//--- REBINDS the global clientTeams (Init_Client.sqf: clientTeams = _teams) once a slow-sync
		//--- OPFOR/JIP joiner's wfbe_teams finally lands. This loop built _markerNames (and the
		//--- _last* caches) ONCE at start sized to the THEN-empty clientTeams, so after the rebind
		//--- the per-tick forEach clientTeams walks N>0 teams while _markerNames is still []/short:
		//--- _markerNames select _markerIndex returns nil -> setMarkerDir/Pos no-op AND the
		//--- _lastDirs/_lastPositions reads return nil -> abs()/distance throw -> the player own
		//--- orange arrow never (re)creates or tracks heading ("direction not working again").
		//--- Rebuild missing markers + grow ALL caches to match clientTeams when the lengths diverge.
		//--- cmdcon26 (Game 2026-06-29) SAME-COUNT REBIND FIX. The B64 guard below ONLY rebuilds when the COUNT
		//--- diverges. But the B62/EARLYHEAL reconciliation in Init_Client REBINDS the global clientTeams from the
		//--- boot SLOT-GROUPS to the live side-logic wfbe_teams, and those two lists are the SAME LENGTH (15 slot
		//--- groups -> 15 real teams). So `count clientTeams != count _markerNames` stays FALSE, NO rebuild fires,
		//--- and _lastLeaders keeps pointing at the now-stale/objNull original slot leaders. For a JIP slow-sync
		//--- joiner (RPT "Zwanon": markerOps:0;skippedWrites:5) every cached leader was dead/objNull while
		//--- clientTeams carried live leaders -> alpha stayed 0 -> own-side arrows INVISIBLE. Detect that here:
		//--- periodically (every ~2s, cheap) compare each cached _lastLeaders entry against the LIVE
		//--- `leader (clientTeams select _i)`. If they diverge (a same-length rebind), reseed the _last* caches to
		//--- their force-write seeds so the very next follow-loop pass re-evaluates and re-paints every marker
		//--- against the live leaders. A2-OA-1.64 safe: select / count / leader / objNull / isNull / alive compare.
		_needRebind = false;
		if (count clientTeams == count _markerNames && {time >= _nextRebindCheck}) then {
			_nextRebindCheck = time + 2;
			for "_i" from 0 to ((count clientTeams) - 1) do {
				if (!_needRebind) then {
					_liveLeader   = leader (clientTeams select _i);
					_cachedLeader = _lastLeaders select _i;
					_liveHas   = (!isNull _liveLeader) && {alive _liveLeader};
					_cachedHas = (!isNull _cachedLeader) && {alive _cachedLeader};
					//--- Diverged if the live leader differs from the cached one while the live one is real, OR the
					//--- cache holds a dead/null leader where clientTeams now carries a live one.
					if ((_liveHas && {_liveLeader != _cachedLeader}) || (_liveHas && {!_cachedHas})) then {
						_needRebind = true;
					};
				};
			};
			if (_needRebind) then {
				diag_log format ["[WFBE][cmdcon26 TEAM-MARK] same-count clientTeams rebind detected (teams=%1 cache=%2) - reseeding leader caches to re-paint own-side arrows", count clientTeams, count _markerNames];
				for "_i" from 0 to ((count _markerNames) - 1) do {
					_lastLeaders   set [_i, objNull];
					_lastTexts     set [_i, ""];
					_lastAlphas    set [_i, -1];
					_lastColors    set [_i, "ColorBlack"];
					_lastPositions set [_i, [-99999,-99999,0]];
					_lastDirs      set [_i, -999];
				};
			};
		};
		if (count clientTeams != count _markerNames) then {
			diag_log format ["[WFBE][B64 TEAM-MARK] clientTeams rebind detected: teams=%1 cache=%2 - rebuilding", count clientTeams, count _markerNames];
			{
				if ((_count - 1) >= count _markerNames) then {
					_marker = Format["%1AdvancedSquad%2Marker", _sideText, _count];
					createMarkerLocal [_marker,[0,0,0]];
					_marker setMarkerTypeLocal "mil_arrow2";
					_marker setMarkerDirLocal 0;
					_marker setMarkerSizeLocal [0.7,0.7];
					_marker setMarkerAlphaLocal 0;
					_markerNames   set [_count - 1, _marker];
					_lastLeaders   set [_count - 1, objNull];
					_lastTexts     set [_count - 1, ""];
					_lastAlphas    set [_count - 1, -1];
					_lastColors    set [_count - 1, "ColorBlack"];
					_lastPositions set [_count - 1, [-99999,-99999,0]];
					_lastDirs      set [_count - 1, -999];
				};
				_count = _count + 1;
			} forEach clientTeams;
			_count = 1;
		};
		{
			_markerIndex = _count - 1;
			_marker = _markerNames select _markerIndex;

			if !(isNil "_x") then {
				_team = _x;
				_leader = leader _team;

				if (alive _leader) then {
					_leaderChanged = ((_lastLeaders select _markerIndex) != _leader);
					_markerColor = "ColorBlack";
					if (player == _leader) then {_markerColor = "ColorOrange"};

					_markerAlpha = 0;
					_label = "AI";
					_updateThisLeader = false;

					if (isPlayer _leader) then {
						_perfPlayerLeaders = _perfPlayerLeaders + 1;
						_updateThisLeader = true;
						_markerAlpha = 1;
						_playerAFKstate = _leader getVariable "WASP_AFK";
						_label = Format[" %1", name _leader];
						if !(isNil "_playerAFKstate") then {
							if (_playerAFKstate) then {_label = Format[" %1 (AFK)", name _leader]};
						};
						// Marty: WF_Debug map-side probe confirms the marker loop sees the networked AFK state.
						if (WF_Debug && !(isNil "_playerAFKstate")) then {
							call {
								if !(_playerAFKstate) exitWith {};
								if (time < _afkMarkerDiagnosticNextLog) exitWith {};
								_afkMarkerDiagnosticNextLog = time + 15;
								["INFORMATION", Format ["AFK Diagnostic: marker loop sees [%1] as AFK. label [%2] marker [%3] teamIndex [%4].", name _leader, _label, _marker, _markerIndex]] Call WFBE_CO_FNC_LogContent;
							};
						};
						// Marty: Keep the player leader arrow and append embarked bot numbers with crew first, then cargo.
						call {
							_leaderVehicle = vehicle _leader;
							if (_leaderVehicle == _leader) exitWith {};

							_botUnitsInVehicle = [];
							{
								_member = _x;
								_memberVehicle = vehicle _member;
								if ((alive _member) && !(_member == _leader) && !(isPlayer _member) && (_memberVehicle == _leaderVehicle)) then {
									_botUnitsInVehicle = _botUnitsInVehicle + [_member];
								};
							} forEach (units group _leader);

							if ((count _botUnitsInVehicle) == 0) exitWith {};

							_crewUnitsInVehicle = [];
							{
								_roleUnit = _x;
								call {
									if (isNull _roleUnit) exitWith {};
									if !(_roleUnit in _botUnitsInVehicle) exitWith {};
									if (_roleUnit in _crewUnitsInVehicle) exitWith {};
									_crewUnitsInVehicle = _crewUnitsInVehicle + [_roleUnit];
								};
							} forEach [driver _leaderVehicle, gunner _leaderVehicle, commander _leaderVehicle];

							_cargoUnitsInVehicle = [];
							{
								_member = _x;
								if !(_member in _crewUnitsInVehicle) then {
									_cargoUnitsInVehicle = _cargoUnitsInVehicle + [_member];
								};
							} forEach _botUnitsInVehicle;

							_crewText = "";
							{
								_unitText = _x Call GetAIDigit;
								if (_crewText == "") then {
									_crewText = _unitText;
								} else {
									_crewText = Format["%1/%2", _crewText, _unitText];
								};
							} forEach _crewUnitsInVehicle;

							_cargoText = "";
							{
								_unitText = _x Call GetAIDigit;
								if (_cargoText == "") then {
									_cargoText = _unitText;
								} else {
									_cargoText = Format["%1/%2", _cargoText, _unitText];
								};
							} forEach _cargoUnitsInVehicle;

							if (_crewText != "") then {_label = Format["%1 %2", _label, _crewText]};
							if (_cargoText == "") exitWith {};
							if (_crewText == "") exitWith {_label = Format["%1 %2", _label, _cargoText]};
							_label = Format["%1 | %2", _label, _cargoText];
						};

						//--- QoL S4: append class tag from broadcast wfbe_player_class (set in Skill_Init.sqf).
						//--- getVariable is cheap; runs inside the existing 0.2s loop only when map/GPS visible.
						private ["_leaderClass","_classTag"];
						_leaderClass = _leader getVariable ["wfbe_player_class", ""];
						_classTag = switch (_leaderClass) do {
							case "Engineer": {"ENG"};
							case "Soldier":  {"SOL"};
							case "SpecOps":  {"SUP"};
							case "Spotter":  {"SNI"};
							case "Medic":    {"MED"};
							case "Officer":  {"OFF"};
							default          {""};
						};
						if (_classTag != "") then {_label = Format["%1 [%2]", _label, _classTag]};
					} else {
						_perfAILeaders = _perfAILeaders + 1;
						if (_updateAILeaders) then {_updateThisLeader = true};
					};

					if (_updateThisLeader) then {
						_leaderVehicle = vehicle _leader;
						//--- PERF4 - only re-write pos/dir when the leader actually moved/turned. A held
						//--- (stationary) player or AI team-lead arrow otherwise paid two setMarker* writes
						//--- every refresh for zero visible change. Same gate the AAR/unit paths use.
						_pos = getPos _leader;
						_lastPos = _lastPositions select _markerIndex;
						if ((_pos distance _lastPos) > 3) then {
							_marker setMarkerPosLocal _pos;
							_lastPositions set [_markerIndex, _pos];
							_perfMarkerOps = _perfMarkerOps + 1;
						} else {
							_perfSkippedWrites = _perfSkippedWrites + 1;
						};
						//--- MARKER-DIR FIX (Ray 2026-06-20): the arrow must point where the player is actually
						//--- HEADING/FACING, not the way they are MOVING. The earlier velocity-derived heading
						//--- diverged from the real bearing whenever the vehicle reversed, sideslipped or a heli
						//--- slid, so the arrow pointed wrong. _leaderVehicle is `vehicle _leader`, so getDir on
						//--- it is the player's facing heading and is correct ON FOOT and MOUNTED alike. This
						//--- matches the patrol/AICOM arrow loops, which use plain getDir. A2-OA-1.64-safe.
						_dir = getDir _leaderVehicle;
						_lastDir = _lastDirs select _markerIndex;
						_dirDiff = abs (_dir - _lastDir);
						if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
						//--- _lastDir<0 forces the FIRST write past the -999 cache seed (L53): without it the >180 wrap above NEGATES _dirDiff so the arrow freezes forever (root-cause fix Game 2026-06-28).
						if (_lastDir < 0 || _dirDiff > 5) then {
							_marker setMarkerDirLocal _dir;
							_lastDirs set [_markerIndex, _dir];
							_perfMarkerOps = _perfMarkerOps + 1;
						} else {
							_perfSkippedWrites = _perfSkippedWrites + 1;
						};

						if ((_lastTexts select _markerIndex) != _label) then {
							_marker setMarkerTextLocal _label;
							_lastTexts set [_markerIndex, _label];
							_perfMarkerOps = _perfMarkerOps + 1;
						} else {
							_perfSkippedWrites = _perfSkippedWrites + 1;
						};

						if ((_lastAlphas select _markerIndex) != _markerAlpha) then {
							_marker setMarkerAlphaLocal _markerAlpha;
							_lastAlphas set [_markerIndex, _markerAlpha];
							_perfMarkerOps = _perfMarkerOps + 1;
						} else {
							_perfSkippedWrites = _perfSkippedWrites + 1;
						};

						if ((_lastColors select _markerIndex) != _markerColor) then {
							_marker setMarkerColorLocal _markerColor;
							_lastColors set [_markerIndex, _markerColor];
							_leader setVariable ["OriginalMarkerColor", _markerColor, false];
							_perfMarkerOps = _perfMarkerOps + 1;
						} else {
							_perfSkippedWrites = _perfSkippedWrites + 1;
						};

						if (_leaderChanged) then {
							_leader setVariable ["unitMarkerBlink", _marker, false];
							_lastLeaders set [_markerIndex, _leader];
							_leader setVariable ["OriginalMarkerColor", _markerColor, false];
						};
					};
				} else {
					if ((_lastTexts select _markerIndex) != "") then {
						_marker setMarkerTextLocal "";
						_lastTexts set [_markerIndex, ""];
						_perfMarkerOps = _perfMarkerOps + 1;
					};

					if ((_lastAlphas select _markerIndex) != 0) then {
						_marker setMarkerAlphaLocal 0;
						_lastAlphas set [_markerIndex, 0];
						_perfMarkerOps = _perfMarkerOps + 1;
					};

					if ((_lastLeaders select _markerIndex) != objNull) then {
						_lastLeaders set [_markerIndex, objNull];
					};
				};
			};

			_count = _count + 1;
		} forEach clientTeams;

		// Marty: Performance Audit record for the visible local team marker update loop.
		if !(isNil "PerformanceAudit_Record") then {
			if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
				["updateteamsmarkers", diag_tickTime - _perfStart, Format["teams:%1;players:%2;ai:%3;markerOps:%4;skippedWrites:%5", count clientTeams, _perfPlayerLeaders, _perfAILeaders, _perfMarkerOps, _perfSkippedWrites], "CLIENT"] Call PerformanceAudit_Record;
			};
		};

		sleep 0.2;
	};
};
