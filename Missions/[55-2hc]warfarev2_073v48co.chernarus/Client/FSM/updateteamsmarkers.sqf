// Marty: Performance Audit locals and marker update cache.
private["_sideText","_label","_count","_marker","_markerIndex","_team","_leader","_leaderVehicle","_leaderChanged","_botUnitsInVehicle","_crewUnitsInVehicle","_cargoUnitsInVehicle","_crewText","_cargoText","_member","_memberVehicle","_roleUnit","_unitText","_updateAILeaders","_updateThisLeader","_nextAIUpdate","_playerAFKstate","_afkMarkerDiagnosticNextLog","_markerColor","_markerAlpha","_markerNames","_lastLeaders","_lastTexts","_lastAlphas","_lastColors","_lastPositions","_lastDirs","_pos","_dir","_lastPos","_lastDir","_dirDiff","_vel","_spd","_wfMenuDisplays","_mapConsumerVisible","_perfStart","_perfMarkerOps","_perfPlayerLeaders","_perfAILeaders","_perfSkippedWrites"];

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

// Marty: Any open Warfare dialog can contain or lead to a minimap view; keep team markers live while these are visible.
_wfMenuDisplays = [11000,12000,13000,14000,17000,20000,21000,22000,23000,503000,504000,505000,508000,511000];

// Marty: Create the local squad markers once and cache their names by team index.
{
	_marker = Format["%1AdvancedSquad%2Marker",_sideText,_count];
	_leader = objNull;
	createMarkerLocal [_marker,[0,0,0]];
	_marker setMarkerTypeLocal "Arrow";
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
						//--- Marty/Claude: the orange arrow should point the way the player is MOVING, not
						//--- where the unit FACES. getDir (vehicle/man heading) and movement heading diverge
						//--- when strafing on foot, walking backwards, or sliding in a vehicle, so the arrow
						//--- pointed wrong. Derive the heading from velocity while moving; fall back to
						//--- getDir when ~stationary so the arrow doesn't jitter at rest. A2-OA-1.64-safe.
						_vel = velocity _leaderVehicle;
						_spd = sqrt (((_vel select 0) * (_vel select 0)) + ((_vel select 1) * (_vel select 1)));
						if (_spd > 1.2 && {_leaderVehicle != _leader}) then {
							//--- MARKER-DIR FIX (Ray 2026-06-19): only use the velocity-derived MOVEMENT heading when
							//--- actually in a VEHICLE. A2 infantry `velocity` is animation-driven (often ~0 or stale),
							//--- so for an on-foot player the velocity branch could freeze the arrow; foot now falls to
							//--- getDir = facing heading, which updates reliably as the player turns.
							_dir = (_vel select 0) atan2 (_vel select 1);
							if (_dir < 0) then {_dir = _dir + 360};
						} else {
							_dir = getDir _leaderVehicle;
						};
						_lastDir = _lastDirs select _markerIndex;
						_dirDiff = abs (_dir - _lastDir);
						if (_dirDiff > 180) then {_dirDiff = 360 - _dirDiff};
						if (_dirDiff > 5) then {
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
