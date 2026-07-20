/*
	Create units in towns.
	 Parameters:
		- Town
		- Side
		- Groups
		- Spawn positions
		- Teams
*/

Private ["_built", "_builtveh", "_cacheTier", "_crews", "_forceFirst", "_groups", "_i", "_isPackedSegments", "_lock", "_logGroupCount", "_packedFailed", "_position", "_positions", "_retVal", "_segment", "_segmentRetVal", "_segments", "_side", "_sideID", "_skillAcc", "_skillCourage", "_skillScalar", "_skillSpeed", "_skillSpot", "_strelaAssigned", "_team", "_teams", "_template", "_town", "_town_teams", "_town_vehicles", "_units", "_vehClass", "_vehicles", "_vehPos", "_vehTier"];

_town = _this select 0;
_side = _this select 1;
_groups = _this select 2;
_positions = _this select 3;
_teams = _this select 4;
_sideID = (_side) call WFBE_CO_FNC_GetSideID;

_built = 0;
_builtveh = 0;
_town_teams = [];
_town_vehicles = [];

//--- fable/gdir-cache-materializer (GR-2026-07-08a): read this town's purchased cache tier
//--- once, up front, for the whole activation episode. Gate-checked here (not just at
//--- purchase time) so an admin can kill materialisation mid-round without touching the panel.
//--- _side==WFBE_DEFENDER guard: AICOMV2_GDIR_* is a GUER-only economy feature, never applies
//--- to WEST/EAST town holders.
_cacheTier = 0;
if (_side == WFBE_DEFENDER && {(missionNamespace getVariable ["AICOMV2_GDIR_CACHE", 0]) > 0}) then {
	_cacheTier = _town getVariable ["AICOMV2_GDIR_CACHE_TIER", 0];
};
_strelaAssigned = false; //--- tier-3 Strela: ONE dedicated AA/AT defender per activation episode, not per-unit chance.
//--- fable/gdir-vehicle-verb (GR-2026-07-08a): read this town's purchased vehicle-order tier
//--- once, up front. Gate-checked here (not just at purchase time), same pattern as the
//--- weapons-cache tier. _side==WFBE_DEFENDER guard: GUER-only economy feature.
_vehTier = 0;
if (_side == WFBE_DEFENDER && {(missionNamespace getVariable ["AICOMV2_GDIR_VEHICLE", 0]) > 0}) then {
	_vehTier = _town getVariable ["AICOMV2_GDIR_VEHICLE_TIER", 0];
	//--- [FIX-931/night-sweep] Consume the order HERE, immediately after the read and with
	//--- NO yielding call in between - not after materialising below like the original code
	//--- did. This function is invoked MULTIPLE TIMES per town per activation episode; the
	//--- original only cleared the tier at the end of the materialize branch, AFTER calling
	//--- WFBE_CO_FNC_GetRandomPosition / WFBE_CO_FNC_GetEmptyPosition (position-finders that
	//--- can internally sleep/waitUntil and yield the SQF scheduler) - a second concurrent
	//--- invocation could read the same still-unconsumed tier at that yield point and
	//--- materialise a second vehicle from the SAME one-shot purchase (double-materialize).
	//--- No yield point exists between this read and the write below, so this closes the
	//--- race regardless of what runs afterward.
	if (_vehTier > 0) then {
		_town setVariable ["AICOMV2_GDIR_VEHICLE_TIER", 0, true];
	};
};
if (_vehTier > 0) then {
	//--- ONE-SHOT delivery: ride the SAME CreateTeam pipeline as the rest of this activation
	//--- episode (skill spread, patrol FSM, defender tagging, HandleEmptyVehicle taxi-lock
	//--- below) instead of a bespoke spawn path - least-new-machinery route. Classnames
	//--- verified in Common\Config\Groups\Groups_GUE.sqf (Motorized/Armored_Light/
	//--- Armored_Heavy kinds - the SAME rosters already used for regular GUER garrison spawns).
	_vehClass = "";
	if (_vehTier == 1) then {_vehClass = "Offroad_DSHKM_Gue"};  //--- Groups_GUE.sqf Motorized kind.
	if (_vehTier == 2) then {_vehClass = "BMP2_GUE"};           //--- Groups_GUE.sqf Armored_Light kind.
	if (_vehTier >= 3) then {_vehClass = "T72_GUE"};            //--- Groups_GUE.sqf Armored_Heavy kind.
	if (_vehClass != "") then {
		_vehPos = ([getPos _town, 50, 300] call WFBE_CO_FNC_GetRandomPosition);
		_vehPos = [_vehPos, 50] call WFBE_CO_FNC_GetEmptyPosition;
		_groups    = _groups    + [[_vehClass]];
		_positions = _positions + [_vehPos];
		_teams     = _teams     + [grpNull];
		//--- Order already consumed above (read+clear atomic, before any yielding call) -
		//--- FIX-931/night-sweep. (Was: setVariable here, post-yield - double-materialize risk.)
		["INFORMATION", Format ["Common_CreateTownUnits.sqf: Town [%1] materialised a purchased tier-%2 defensive vehicle [%3].", _town, _vehTier, _vehClass]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Task 34: resistance vehicles are always unlocked when the resistance side is inactive (WFBE_C_TOWNS_DEFENDER == 0).
//--- When resistance IS active the existing WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER parameter governs the lock state
//--- (default=0 in Parameters.hpp, meaning unlocked; set to 1 in the lobby to require lockpick).
_lock = if (_side == WFBE_DEFENDER && (missionNamespace getVariable ["WFBE_C_TOWNS_DEFENDER", 1]) == 0) then {
	false  //--- Resistance AI disabled: nothing to fight — unlock vehicles for everyone.
} else {
	if ((missionNamespace getVariable "WFBE_C_TOWNS_VEHICLES_LOCK_DEFENDER") == 0 && _side == WFBE_DEFENDER) then {false} else {true}
};

// Marty: Record local group counts around town defense creation to diagnose Arma 2 OA per-side group pressure on server/HC.
_logGroupCount = {
	Private ["_event", "_groupCountCiv", "_groupCountEast", "_groupCountGuer", "_groupCountLogic", "_groupCountSide", "_groupCountWest", "_groupCountUnknown", "_groupMachine", "_groupSide", "_level"];

	_event = _this select 0;
	_level = _this select 1;
	_groupCountWest = 0;
	_groupCountEast = 0;
	_groupCountGuer = 0;
	_groupCountCiv = 0;
	_groupCountLogic = 0;
	_groupCountUnknown = 0;

	{
		_groupSide = side _x;
		switch (_groupSide) do {
			case west: {_groupCountWest = _groupCountWest + 1};
			case east: {_groupCountEast = _groupCountEast + 1};
			case resistance: {_groupCountGuer = _groupCountGuer + 1};
			case civilian: {_groupCountCiv = _groupCountCiv + 1};
			case sideLogic: {_groupCountLogic = _groupCountLogic + 1};
			default {_groupCountUnknown = _groupCountUnknown + 1};
		};
	} forEach allGroups;

	_groupCountSide = switch (_side) do {
		case west: {_groupCountWest};
		case east: {_groupCountEast};
		case resistance: {_groupCountGuer};
		case civilian: {_groupCountCiv};
		case sideLogic: {_groupCountLogic};
		default {_groupCountUnknown};
	};
	_groupMachine = if (isServer) then {"SERVER"} else {if (hasInterface) then {"CLIENT"} else {"HC"}};
	[_level, Format ["TOWN_GROUP_COUNT %1 machine:%2 town:%3 side:%4 sideGroups:%5 total:%6 west:%7 east:%8 guer:%9 civ:%10 logic:%11 unknown:%12", _event, _groupMachine, _town getVariable "name", _side, _groupCountSide, count allGroups, _groupCountWest, _groupCountEast, _groupCountGuer, _groupCountCiv, _groupCountLogic, _groupCountUnknown]] Call WFBE_CO_FNC_LogContent;
};

["activation_before", "INFORMATION"] call _logGroupCount;

for '_i' from 0 to count(_groups)-1 do {
	_position = _positions select _i;
	_team = _teams select _i;
	_template = _groups select _i;
	_isPackedSegments = false;
	if (typeName _template == "ARRAY" && {count _template == 2}) then {
		if (typeName (_template select 0) == "ARRAY" && {(_template select 1) == "WFBE_TOWN_PACKED_SEGMENTS"}) then {_isPackedSegments = true};
	};
	
	["INFORMATION", Format["Common_CreateTownUnits.sqf: Town [%1] [%2] will create a team template %3 at %4", _town, _side, _template,_position]] Call WFBE_CO_FNC_LogContent;
	
	if (_isPackedSegments) then {
		//--- TOWN-PACKED-SEGMENTS: several original rosters share one engine group. CreateTeam is
		//--- invoked once per source segment so every original roster head keeps its forced spawn;
		//--- continuation fragments keep the original 90% probability. Tags and patrol setup below
		//--- intentionally run once after all segments, never once per segment.
		_segments = _template select 0;
		_units = [];
		_vehicles = [];
		_crews = [];
		_packedFailed = false;
		{
			if (!_packedFailed) then {
				_segment = _x select 0;
				_forceFirst = _x select 1;
				_segmentRetVal = [_segment, _position, _side, _lock, _team, true, 90, -1, _forceFirst] call WFBE_CO_FNC_CreateTeam;
				_team = _segmentRetVal select 2;
				_units = _units + (_segmentRetVal select 0);
				_vehicles = _vehicles + (_segmentRetVal select 1);
				_crews = _crews + (if (count _segmentRetVal > 3) then {_segmentRetVal select 3} else {[]});
				if (isNull _team) then {_packedFailed = true};
			};
		} forEach _segments;
	} else {
		_retVal = [_template, _position, _side, _lock, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
		_units = _retVal select 0;
		_vehicles = _retVal select 1;
		// Marty: Track the actual group returned by CreateTeam, because delegated HC creation may replace grpNull locally.
		_team = _retVal select 2;
		_crews = if (count _retVal > 3) then {_retVal select 3} else {[]};
	};

	//--- Defender classification: tag everything this town spawned. PUBLIC tag (3rd arg true) -
	//--- town AI may be created on an HC while the activation scan that must ignore these runs
	//--- on the server, so a local-only tag would be invisible where it matters.
	{if (!isNull _x) then {_x setVariable ["WFBE_IsTownDefenderAI", true, true]}} forEach (_units + _crews + _vehicles);

	//--- Item 1: Airfield garrison tracking. Tag units spawned for PMCAirfield-type towns so they
	//--- can be bulk-deleted on capture (server_town.sqf cleanup-airfield-garrison path).
	//--- The per-location array is maintained server-local; non-server machines tag individually.
	if ((_town getVariable ["wfbe_town_type", ""]) == "PMCAirfield") then {
		Private "_garUnit";
		{
			_garUnit = _x;
			if (!isNull _garUnit) then {
				_garUnit setVariable ["wfbe_airfield_garrison", true, true];
			};
		} forEach (_units + _crews + _vehicles);
		if (isServer) then {
			Private "_garArr";
			_garArr = _town getVariable "wfbe_airfield_garrison_units";
			if (isNil "_garArr") then {_garArr = []};
			_town setVariable ["wfbe_airfield_garrison_units", _garArr + _units + _crews + _vehicles, true];
		};
	};

	_built = _built + count _units;
	_builtveh = _builtveh + (count _vehicles);

	// Marty: Skip tracking/patrol work when no valid group could be created on this machine.
	if (isNull _team || {((count _units) + (count _vehicles)) == 0}) then {
		["WARNING", Format["Common_CreateTownUnits.sqf: Town [%1] [%2] skipped patrol setup for template %3 because no valid team assets were created.", _town, _side, _groups select _i]] Call WFBE_CO_FNC_LogContent;
	} else {
		_team setVariable ["WFBE_TownAI_Town", _town, false];
		_team setVariable ["WFBE_TownAI_Side", _side, false];
		_team setVariable ["WFBE_TownAI_Group", true, false];
		[_town, _team, _sideID] execVM "Server\FSM\server_town_patrol.sqf";
		//--- B5: per-group 400m reveal coalesced to ONE town-wide reveal per activation
		//--- episode (after this loop). Each group used to fire its own RevealArea spawn,
		//--- meaning one expensive nearEntities scan per group; for a town with many garrison
		//--- groups that was N scans per activation. We instead reveal once below to every
		//--- team created this episode (_town_teams). Enemies are still revealed (just once).
		[_town_teams, _team] call WFBE_CO_FNC_ArrayPush;
		_team allowFleeing 0; //--- Make the units brave.

		//--- Town-defender skill spread: tight, near-baseline variation (garrison only).
		{
			if (_x isKindOf "Man") then {
				_skillAcc     = 0.65 + random 0.30;
				_skillScalar  = 0.80 + random 0.20;
				_skillSpot    = 0.70 + random 0.25;
				_skillSpeed   = 0.70 + random 0.25;
				_skillCourage = 0.80 + random 0.20;
				_x setSkill ["aimingAccuracy", _skillAcc];
				_x setSkill ["aimingSpeed",    _skillSpeed];
				_x setSkill ["spotDistance",   _skillSpot];
				_x setSkill ["courage",        _skillCourage];
				_x setSkill _skillScalar;

				//--- fable/gdir-cache-materializer (GR-2026-07-08a): AICOMV2_GDIR_CACHE loadout-apply
				//--- hook. Cumulative by tier (a town holds ONE tier; higher tiers include lower-tier
				//--- effects). Additive via addWeapon/addMagazine, never removes existing gear except
				//--- the deliberate primary-weapon swap for the RPK conversion (mirrors the
				//--- addWeapon/removeWeapon swap idiom already used in Common_CreateUnit.sqf for
				//--- Ins_Soldier_AT/MVD_Soldier_AT). Classnames verified in
				//--- Common\Config\Loadout\Loadout_GUE.sqf and Common\Config\Gear\Gear_GUE.sqf
				//--- (GUER faction's own existing gear pool - no new content).
				if (_cacheTier > 0) then {
					//--- Tier 1: "AK+RPK mix + extra mags." One extra AK mag for every defender; ~35%
					//--- of PLAIN AK riflemen (not MG/marksman/shotgun specialists) get converted to
					//--- an RPK gunner. One frag grenade per defender (the "grenades" component).
					_x addMagazine "30Rnd_545x39_AK";
					_x addMagazine "HandGrenade_East";
					if (!(_x hasWeapon "RPK_74") && {(primaryWeapon _x) in ["AK_47_M","AK_47_S","AK_74","AKS_74_kobra","AKS_74_pso","AKS_74_U","AKS_74_UN_kobra","AKS_GOLD"]} && {random 100 < 35}) then {
						_x removeWeapon (primaryWeapon _x);
						_x addWeapon "RPK_74";
						_x addMagazine "75Rnd_545x39_RPK";
						_x addMagazine "75Rnd_545x39_RPK";
					};

					//--- Tier 2: "+RPG-7V gunners." ~20% of defenders with an empty launcher slot become
					//--- an RPG-7V AT gunner.
					if (_cacheTier >= 2 && {secondaryWeapon _x == ""} && {random 100 < 20}) then {
						_x addWeapon "RPG7V";
						_x addMagazine "PG7V";
						_x addMagazine "PG7V";
					};

					//--- Tier 3: "+Strela defender." Exactly ONE dedicated Strela AA/AT gunner per
					//--- activation episode (not a per-unit chance - a single named defender, matching
					//--- the singular "defender" in the gate's own comment).
					if (_cacheTier >= 3 && {!_strelaAssigned} && {secondaryWeapon _x == ""}) then {
						_x addWeapon "Strela";
						_x addMagazine "Strela";
						_x addMagazine "Strela";
						_strelaAssigned = true;
					};
				};
				//--- fable/smallarms-air-envelope: (re)stamp the AA classifier AFTER the tiered garrison
				//--- loadout is applied - the Tier-3 Strela AA gunner above gets its launcher HERE, post-
				//--- CreateUnit, so the one dedicated air-defender reads effAntiAir=true and is never steered
				//--- off. Flag-gated: inert (no stamp) when WFBE_C_SMALLARMS_AIR_ENVELOPE = 0. _x = this unit.
				if ((missionNamespace getVariable ["WFBE_C_SMALLARMS_AIR_ENVELOPE", 0]) > 0) then {
					_x setVariable ["WFBE_effAntiAir", [_x] Call WFBE_CO_FNC_SmallArmsEffAntiAir, false];
				};
			};
		} forEach _units;
	};

	{
		[_town_vehicles, _x] call WFBE_CO_FNC_ArrayPush;
		if (isServer) then {
			[_x] spawn WFBE_SE_FNC_HandleEmptyVehicle;
			_x setVariable ["WFBE_Taxi_Prohib", true];
		};
	} forEach _vehicles;
};

//--- B5: coalesced reveal — ONE nearEntities scan per activation episode (was one per
//--- garrison group). Reveal the nearby entities to every town team created this episode.
//--- Scan is town-centred with a radius that covers the union of the old per-group 400m
//--- circles (groups spawn up to ~300m from the town, so 700m envelops them). The crew of
//--- each revealed vehicle is revealed too, matching Common_RevealArea's behaviour.
if (count _town_teams > 0) then {
	[_town_teams, _town] spawn {
		Private ["_teams","_town","_revealPos","_revealRange","_near","_reveal","_ent","_grp"];
		_teams = _this select 0;
		_town  = _this select 1;
		_revealPos = getPos _town;
		_revealRange = 700;
		_near = _revealPos nearEntities _revealRange;
		{
			_ent = _x;
			_reveal = [_ent];
			if (_ent != vehicle _ent) then {_reveal = _reveal + (crew _ent)};
			{
				_grp = _x;
				{_grp reveal _ent} forEach _reveal;
			} forEach _teams;
		} forEach _near;
	};
};

if (_built > 0) then {[str _side,'UnitsCreated',_built] call UpdateStatistics};
if (_builtveh > 0) then {[str _side,'VehiclesCreated',_builtveh] call UpdateStatistics};

// Marty: Record the post-spawn group count even when activation succeeds, so logs show if a side is approaching the 144 group limit.
["activation_after", "INFORMATION"] call _logGroupCount;

// Marty: When a town activates empty, print the machine-side group counts near the failure.
if ((_built + _builtveh) == 0) then {
	["town_empty", "WARNING"] call _logGroupCount;
};

["INFORMATION", Format["Common_CreateTownUnits.sqf: Town [%1] held by [%2] was activated witha total of [%3] units.", _town, _side, _built + _builtveh]] Call WFBE_CO_FNC_LogContent;

[_town_teams, _town_vehicles]
