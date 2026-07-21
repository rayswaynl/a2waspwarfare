private["_camp","_town","_flag","_newSID","_force","_camp_cap_rate","_camp_range","_camp_range_players","_town_starting_sv","_camp_throttle","_camp_step_sleep","_camp_loop_sleep","_gateSkip"];

_town = _this select 1;

_camps = _this select 0;
_flags = _this select 2;

_newSID = -1;
_force = 0;

_camp_cap_rate = missionNamespace getVariable "WFBE_C_CAMPS_CAPTURE_RATE";
_camp_range = missionNamespace getVariable "WFBE_C_CAMPS_RANGE";
_camp_range_players = missionNamespace getVariable "WFBE_C_CAMPS_RANGE_PLAYERS";
_town_starting_sv = _town getVariable ["startingSupplyValue", 30]; //--- H6 code-health: 2-arg nil-guard (same class as N9/cmdcon44-d in server_town.sqf); default matches Init_Town/server_town fallback.
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
			//--- Codex adversarial review fix (PR #1217, finding 2 - STALE TIMESTAMP): a leftover
			//--- wfbe_camp_repair_since from a PRIOR dead-camp accumulation must never survive into
			//--- the bunker coming back alive (via this presence repair, the paid player repair, or
			//--- any future path) - otherwise the NEXT destruction could insta-repair off stale
			//--- elapsed time. Cheap unconditional reset every pass; same flag gate as the dead-
			//--- branch consumer below, so this is a byte-identical no-op while the flag is off.
			if ((missionNamespace getVariable ["WFBE_C_CAMP_REPAIR_PRESENCE", 0]) > 0) then {
				_camp setVariable ["wfbe_camp_repair_since", -1];
			};
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
		}else{
			//--- feat/deadcamp-presence-repair (owner redesign 2026-07-21, "AI soldiers repair a destroyed
			//--- camp by standing in its bubble for a couple of minutes"): presence-based dead-camp
			//--- self-repair. Flag-gated (WFBE_C_CAMP_REPAIR_PRESENCE, default 0) per the repo flag policy -
			//--- flag off, this whole branch is a no-op and the mission stays byte-identical to HEAD.
			//--- NULL GUARD (Codex adversarial review, PR #1217 finding 3): a camp logic DELETED mid-match
			//--- (same class of bug the _base heal above this branch exists for) now falls into this
			//--- else instead of the skipped-alive path - objNull getVariable [..,default] can still yield
			//--- nil on A2 OA, which would poison the time comparison below with a nil-to-number error
			//--- every pass. Guard the WHOLE branch on !isNull _camp before touching it at all.
			if (!isNull _camp) then {
				if ((missionNamespace getVariable ["WFBE_C_CAMP_REPAIR_PRESENCE", 0]) > 0) then {
					private ["_presentMen","_presentSnap","_dcWest","_dcEast","_dcResistance","_presenceSince","_repairSideID"];
					//--- Same nearEntities["Man", _camp_range] scan + the SAME player/AI eligibility split the
					//--- alive-bunker branch above uses (players narrowed to _camp_range_players; AI unrestricted
					//--- within _camp_range) - this is that scan's mutually-exclusive dead-bunker counterpart, not
					//--- a second/parallel scan mechanism. Codex review fix (finding 1): also drop corpses (a dead
					//--- body isn't "a living soldier standing in the bubble" per the design ask), and never count
					//--- CIVILIAN presence toward the clock - the gate below is countSide west/east/resistance,
					//--- exactly like the alive branch's own gate, so a lone civilian bystander can neither start
					//--- nor complete the repair (nor silently restore the previous owner).
					_presentMen = _camp nearEntities ["Man", _camp_range];
					_presentSnap = _presentMen;
					{
						if (!alive _x) then {_presentMen = _presentMen - [_x]};
						if (isPlayer _x && {_x distance _camp > _camp_range_players}) then {_presentMen = _presentMen - [_x]};
					} forEach _presentSnap;

					_dcWest = west countSide _presentMen;
					_dcEast = east countSide _presentMen;
					_dcResistance = resistance countSide _presentMen;

					if (_dcWest > 0 || _dcEast > 0 || _dcResistance > 0) then {
						//--- Continuous presence by ANY of the three combat sides (AI or player) starts/keeps the
						//--- clock - side-agnostic by design (see PR body): attackers need a way to reclaim a dead
						//--- camp to satisfy an All-Camps capture, defenders benefit equally by being able to
						//--- repair their own. CIVILIAN is never one of the three sides counted above.
						_presenceSince = _camp getVariable ["wfbe_camp_repair_since", -1];
						if (_presenceSince < 0) then {
							_presenceSince = time;
							//--- KA-01 (camp-repair-readout): broadcast+JIP so a client can compute its own
							//--- progress readout locally (time - since) / WFBE_C_CAMP_REPAIR_PRESENCE_TIME -
							//--- fires once per repair-cycle start, not every scan pass.
							_camp setVariable ["wfbe_camp_repair_since", _presenceSince, true];
						};
						if ((time - _presenceSince) >= (missionNamespace getVariable ["WFBE_C_CAMP_REPAIR_PRESENCE_TIME", 150])) then {
							//--- Threshold reached: whichever side is dominant in the presence set right now claims the
							//--- repaired camp (mirrors the paid player repair contract in Server_HandleSpecial.sqf,
							//--- where the repairing player's own side always becomes the new owner). Tie/mixed
							//--- presence (no strict majority) keeps the camp's last-known sideID - same tie-keeps-
							//--- owner rule the alive-bunker capture switch above already uses.
							_repairSideID = _camp getVariable ["sideID", WFBE_DEFENDER_ID];
							if (_dcWest > _dcEast && _dcWest > _dcResistance) then {_repairSideID = WFBE_C_WEST_ID};
							if (_dcEast > _dcWest && _dcEast > _dcResistance) then {_repairSideID = WFBE_C_EAST_ID};
							if (_dcResistance > _dcWest && _dcResistance > _dcEast) then {_repairSideID = WFBE_C_GUER_ID};

							//--- Reuse the EXISTING repair-completion path (Server_HandleSpecial.sqf "repair-camp")
							//--- instead of duplicating bunker-rebuild/flag/notify logic here - the same path the paid
							//--- player repair (Action_RepairCamp.sqf) already drives. It rebuilds the bunker alive,
							//--- which also re-enters this camp in server_town.sqf's C2 live-bunker dead-camp count
							//--- on its very next pass - no separate CAPGATE wiring needed here.
							["repair-camp", _camp, _repairSideID] call HandleSpecial;
							_camp setVariable ["wfbe_camp_repair_since", -1, true]; //--- KA-01: broadcast the readout's own completion edge too.

							diag_log Format ["CAPGATE|v1|%1|deadcamp-repair|camp=%2|side=%3|presence=%4s", (_town getVariable ["name","?"]), _camp, _repairSideID, round (time - _presenceSince)];
						};
					} else {
						//--- Presence gap: full reset, no partial decay (simplest rule; documented per design).
						if ((_camp getVariable ["wfbe_camp_repair_since", -1]) >= 0) then {
							_camp setVariable ["wfbe_camp_repair_since", -1, true]; //--- KA-01: broadcast the presence-gap reset so a watching client's readout clears too.
						};
					};
				};
			};
		};

		sleep _camp_step_sleep;
	};
	sleep _camp_loop_sleep;
	};
};
