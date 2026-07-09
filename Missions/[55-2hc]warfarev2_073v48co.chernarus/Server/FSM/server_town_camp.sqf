private["_camp","_town","_flag","_newSID","_force","_camp_cap_rate","_camp_range","_camp_range_players","_town_starting_sv","_camp_throttle","_camp_step_sleep","_camp_loop_sleep","_gateSkip"];

_town = _this select 1;

_camps = _this select 0;
_flags = _this select 2;

_newSID = -1;
_force = 0;

_camp_cap_rate = missionNamespace getVariable "WFBE_C_CAMPS_CAPTURE_RATE";
_camp_range = missionNamespace getVariable "WFBE_C_CAMPS_RANGE";
_camp_range_players = missionNamespace getVariable "WFBE_C_CAMPS_RANGE_PLAYERS";
_town_starting_sv = _town getVariable "startingSupplyValue";
_camp_throttle = missionNamespace getVariable ["WFBE_C_TOWN_CAMP_SCAN_THROTTLE", 0];
_camp_step_sleep = 0.01;
_camp_loop_sleep = 0.1;
if (_camp_throttle > 0) then {
	_camp_step_sleep = missionNamespace getVariable ["WFBE_C_TOWN_CAMP_STEP_SLEEP", 0.03];
	_camp_loop_sleep = missionNamespace getVariable ["WFBE_C_TOWN_CAMP_LOOP_SLEEP", 0.25];
};

while {!WFBE_GameOver} do {
	//--- Perf active-gate (2026-07-06, Ray): camp capture only matters while someone is at the town.
	//--- While the parent town is dormant (not active, no air tier, and no enemy seen by the activation
	//--- scan within IDLE_GRACE - wfbe_inactivity is stamped even for activation-budget-DEFERRED towns,
	//--- so a fight the budget would not activate still wakes the camps), idle instead of running the
	//--- per-camp nearEntities pass ~10x/s. Flag default 0 = exact V1 behaviour.
	_gateSkip = false;
	if ((missionNamespace getVariable ["WFBE_C_TOWN_CAMP_ACTIVE_GATE", 0]) > 0) then {
		if (!(isNil {_town getVariable "wfbe_active"}) && {!(_town getVariable ["wfbe_active", false])} && {!(_town getVariable ["wfbe_active_air", false])} && {(time - (_town getVariable ["wfbe_inactivity", 0])) > (missionNamespace getVariable ["WFBE_C_TOWN_CAMP_IDLE_GRACE", 60])}) then {_gateSkip = true}; //--- isNil guard: never gate before server_town_ai.sqf has initialised this town's vars (review WARN: startup race)
		if (isNil "WFBE_TownCampGateAnnounced") then {
			WFBE_TownCampGateAnnounced = true;
			["INFORMATION", "server_town_camp.sqf: active-gate enabled (WFBE_C_TOWN_CAMP_ACTIVE_GATE=1) - camp scans idle while their town is dormant."] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	if (_gateSkip) then {
		sleep (missionNamespace getVariable ["WFBE_C_TOWN_CAMP_IDLE_SLEEP", 3]);
	} else {
	for "_i" from 0 to ((count _camps) - 1) step 1 do
	{
		_camp = _camps select _i;
		_flag = _flags select _i;

		_base = _camp getVariable "wfbe_camp_bunker";
		//--- cmdcon44q live-spam fix (2026-07-04, 6592 err lines in 15 min): a camp DELETED mid-match leaves
		//--- a null ref in _camps; getVariable on a null object returns nil (2-arg defaults ignored too), so
		//--- alive <undefined> errored 4x/sec. Top-level heal to objNull -> alive=false -> camp skipped safely.
		_base = if (isNil "_base") then {objNull} else {_base};

		if(alive _base) then {
			//--- Filter players and ai.
			_objects = _camp nearEntities["Man", _camp_range];
			_in_range = _objects;
			{
				if (isPlayer _x) then {if (_x distance _camp > _camp_range_players) then {_objects = _objects - [_x]}};
			} forEach _in_range;

			_west = west countSide _objects;
			_east = east countSide _objects;
			_resistance = resistance countSide _objects;

			if(_west > 0 || _east > 0 || _resistance > 0) then{
				_skip = false;
				_protected = false;
				_captured = false;
				//--- N9 (fable/fix-camp-placement, 2026-07-08): nil-safe SV/side reads - same bug class + same
				//--- fix pattern as cmdcon44-d (server_town.sqf). A camp mid-init (or on a transplanted map) can
				//--- have sideID/supplyValue still unset; a plain 1-arg getVariable then poisons this scan with
				//--- Undefined, silently stalling camp capture drain forever. 2-arg defaults mirror Init_Town.sqf's
				//--- own camp seed default (sideID -> WFBE_DEFENDER_ID) and this file's own "full" SV fallback
				//--- (_town_starting_sv, already used a few lines below at the capture-completion check).
				_sideID = _camp getVariable ["sideID", WFBE_DEFENDER_ID];
				_supplyValue = _camp getVariable ["supplyValue", _town_starting_sv];

				_resistanceDominion = if (_resistance > _east && _resistance > _west) then {true} else {false};
				_westDominion = if (_west > _east && _west > _resistance) then {true} else {false};
				_eastDominion = if (_east > _west && _east > _resistance) then {true} else {false};

				if (_sideID == WFBE_C_GUER_ID && _resistanceDominion) then {_force = _resistance;_protected = true;_skip = true};
				if (_sideID == WFBE_C_EAST_ID && _eastDominion) then {_force = _east;_protected = true;_skip = true};
				if (_sideID == WFBE_C_WEST_ID && _westDominion) then {_force = _west;_protected = true;_skip = true};

				switch (true) do {
					case _resistanceDominion: {_resistance = if (_east > _west) then {_resistance - _east} else {_resistance - _west};	_force = _resistance; _east = 0; _west = 0};
					case _westDominion: {_west = if (_east > _resistance) then {_west - _east} else {_west - _resistance}; _force = _west; _east = 0; _resistance = 0};
					case _eastDominion: {_east = if (_west > _resistance) then {_east - _west} else {_east - _resistance}; _force = _east; _west = 0; _resistance = 0};
				};

				if (!_resistanceDominion && !_westDominion && !_eastDominion) then {_west = 0; _east = 0; _resistance = 0};

				if !(_skip) then {
					//--- ROOT FIX (cmdcon44e): same tie-case boolean leak as server_town (see XWT45); tie -> keep owner.
					_newSID = switch (true) do {case (_west > 0): {WFBE_C_WEST_ID}; case (_east > 0): {WFBE_C_EAST_ID}; case (_resistance > 0): {WFBE_C_GUER_ID}; default {_sideID}};
					_supplyValue = round(_supplyValue - ((_resistance + _east + _west)*_camp_cap_rate));
					if (_supplyValue < 1) then {_supplyValue = _town_starting_sv; _captured = true};
					_camp setVariable ["supplyValue",_supplyValue,true];
				};

				if (_protected) then {
					if (_supplyValue < _town_starting_sv) then {
						_supplyValue = _supplyValue + round(_force * _camp_cap_rate);
						if (_supplyValue > _town_starting_sv) then {_supplyValue = _town_starting_sv};
						_camp setVariable ["supplyValue",_supplyValue,true];
					};
				};
				if(_captured)then{
					_newSide = (_newSID) Call WFBE_CO_FNC_GetSideFromID;
					_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

					if (_sideID != WFBE_C_UNKNOWN_ID) then {
						if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_side]) then {[_side,"LostAt",["Strongpoint",_town]] Spawn SideMessage};
					};

					if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_newSide]) then {[_newSide,"CapturedNear",["Strongpoint",_town]] Spawn SideMessage};

					_camp setVariable ["sideID",_newSID,true];

					//--- B74.2: leaderboard CAMP-capture credit to each capturing player present on the new owner's side
					//--- at flip. _objects here is already the "Man"-filtered range list; capture the outer side into a
					//--- private so the nested forEach's magic _x stays safe.
					private ["_capSideC","_capUidC"];
					_capSideC = _newSide;
					{ if (isPlayer _x && {alive _x} && {side _x == _capSideC}) then {_capUidC = getPlayerUID _x; if (_capUidC != "") then {[_capUidC, WFBE_STAT_CAPTURES_CAMP, 1] call WFBE_SE_FNC_RecordStat}} } forEach _objects;
					_flag setFlagTexture (missionNamespace getVariable Format["WFBE_%1FLAG",str _newSide]); _flag setVehicleInit (Format ["this setFlagTexture '%1'", missionNamespace getVariable Format["WFBE_%1FLAG",str _newSide]]); processInitCommands; //--- qol-polish-pack: JIP-safe flag (bare setFlagTexture is local-only; bake into object init so late joiners replay it)

					[nil, "CampCaptured", [_camp,_newSID,_sideID]] Call WFBE_CO_FNC_SendToClients;
				};
			};
		}else{};

		sleep _camp_step_sleep;
	};
	sleep _camp_loop_sleep;
	};
};
