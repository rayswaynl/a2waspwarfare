Private ["_building","_built","_config","_crew","_direction","_dir","_distance","_factoryType","_factoryPosition","_gbq","_id","_index","_isVehicle","_longest","_position","_price","_queu","_queu2","_ret","_side","_sideID","_sideText","_soldier","_team","_turrets","_type","_unitType","_vehicle","_waitTime"];
_id = _this select 0;
_building = _this select 1;
_unitType = _this select 2;
_side = _this select 3;
_sideID = (_side) Call GetSideID;
_team = _this select 4;
_isVehicle = _this select 5;
//--- N8 fix: exact funds/supply charged for THIS buy (threaded through from AI_Commander_Produce.sqf's
//--- Spawn AIBuyUnit call so a live W15 Black Market discount refunds at the SAME rate it was charged,
//--- not re-derived from list price). Defaults to 0 for any other/older caller (defensive, back-compat).
_price = if (count _this > 6) then {_this select 6} else {0};

_sideText = str _side;

if (!(alive _building)||(isPlayer (leader _team))) exitWith {
	_gbq = (_team getVariable "wfbe_queue") - [_id];
	_team setVariable ["wfbe_queue",_gbq];
	if !(alive _building) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] construction has been stopped due to factory destruction.", _unitType]] Call WFBE_CO_FNC_LogContent};
	if (isPlayer (leader _team)) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] has been canceled, player [%2] has replace the ai.", _unitType, name (leader _team)]] Call WFBE_CO_FNC_LogContent};
};

["INFORMATION", Format ["Server_BuyUnit.sqf: [%1] Team [%2] has purchased [%3].", _side,_team,_unitType]] Call WFBE_CO_FNC_LogContent;

_queu = _building getVariable "queu";
if (isNil "_queu") then {_queu = []};
_queu = _queu + [_id select 0];
_building setVariable ["queu",_queu,true];

_type = typeOf _building;
_index = (missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES",_sideText]) find _type;
//--- crash-guard (mirrors Client_GetStructureMarkerLabel.sqf B62 / Client_BuildUnit.sqf): if _type is not
//--- registered in STRUCTURENAMES, find returns -1 and select _index throws "Zero divisor" on A2-OA 1.64
//--- (negative array index), aborting the whole AI buy mid-purchase. Default to the same safe zero-offset/
//--- no-type values Client_BuildUnit.sqf uses; the switch-default and isNil floor further below already
//--- handle an empty _factoryType safely.
if (_index == -1) then {["WARNING", Format ["Server_BuyUnit.sqf: factory type [%1] not found in WFBE_%2STRUCTURENAMES; using safe defaults (no spawn-pad routing).", _type, _sideText]] Call WFBE_CO_FNC_LogContent};
_distance = if (_index != -1) then {(missionNamespace getVariable Format ["WFBE_%1STRUCTUREDISTANCES",_sideText]) select _index} else {0};
_direction = if (_index != -1) then {(missionNamespace getVariable Format ["WFBE_%1STRUCTUREDIRECTIONS",_sideText]) select _index} else {0};
_factoryType = if (_index != -1) then {(missionNamespace getVariable Format ["WFBE_%1STRUCTURES",_sideText]) select _index} else {""};
_waitTime = (missionNamespace getVariable _unitType) select QUERYUNITTIME;
_position = [getPos _building,_distance,getDir _building + _direction] Call GetPositionFrom;
//--- B67 OPEN SPAWN APRON: the fixed trig offset above has no flat/empty check, so AI
//--- factory output can drop in trees / on a slope. For AI-owned factories ONLY
//--- (!isPlayer (leader _team)) sweep for a flat, dry, object-clear apron near the
//--- factory and use it; on failure fall back to the original fixed offset. The human
//--- player path is byte-identical (this whole block is skipped when a player leads).
if (!isPlayer (leader _team)) then {
	private ["_apFac","_apBaseBrg","_apOk","_apTry","_apBrg","_apDist","_apCand","_apFlat"];
	_apFac = getPos _building;
	_apBaseBrg = getDir _building + _direction;
	_apOk = false;
	//--- SPAWN-PAD FIX (bug fix, ACTIVE): the PLAYER buy path (Client_BuildUnit.sqf) exits units onto the
	//--- factory's proper spawn pads - the HeliH/HeliHRescue/HeliHCivil/Sr_border markers baked into each BI
	//--- Warfare factory composition (the "spawn points 2/3/4/5"). The AI path never consulted them, so it
	//--- dumped units on a raw trig offset that can sit IN the factory geometry / against a wall. Mirror the
	//--- player's pad-type mapping here: pick the best (closest, flat, dry, object-clear) pad of the matching
	//--- type and exit the unit there. Only fall through to the apron sweep below if NO usable pad is found,
	//--- so this never degrades the existing behaviour. (Same _building nearObjects + isFlatEmpty idioms the
	//--- player path / the apron sweep already use - A2-OA safe.)
	private ["_padType","_pads","_padBest","_padBestD","_padPos","_padD"];
	_padType = switch (_factoryType) do {
		case "Light": {"HeliH"};
		case "Heavy": {"HeliHRescue"};
		case "Aircraft": {"HeliHCivil"};
		case "Barracks": {"Sr_border"};
		default {""};
	};
	if (_padType != "") then {
		_pads = _building nearObjects [_padType, 250];
		_padBest = objNull; _padBestD = 1e9;
		{
			//--- the Light pad type "HeliH" is the base class of HeliHRescue/HeliHCivil, so exclude those exactly
			//--- like the player path does (a Heavy/Air pad must not double as a Light pad). The pad IS the designed
			//--- spawn point (the player path trusts it unconditionally), so we only reject a pad over water; the
			//--- factory-clearance fix in AI_Commander_Base keeps the pad ground clear. Pick the CLOSEST valid pad.
			if ((typeOf _x == _padType) || {_padType != "HeliH"}) then {
				_padPos = getPos _x;
				if (!(surfaceIsWater _padPos)) then {
					_padD = _padPos distance _apFac;
					if (_padD < _padBestD) then {_padBestD = _padD; _padBest = _x};
				};
			};
		} forEach _pads;
		if (!isNull _padBest) then {
			_padPos = getPos _padBest;
			_position = [_padPos select 0, _padPos select 1, 0.5];
			_apOk = true;
		};
	};
	//--- first try the exact original offset position - if it is already flat/empty, keep it.
	if (!_apOk) then {
		_apFlat = _position isFlatEmpty [8, 0, 2, 8, 0, false, objNull];
		if ((count _apFlat) > 0 && {!(surfaceIsWater _position)}) then {_apOk = true};
	};
	//--- otherwise sweep the bearing (around the factory) and the standoff outward, up to
	//--- ~12 tries, for the first flat dry spot. isFlatEmpty returns [] when not flat.
	_apTry = 0;
	while {!_apOk && {_apTry < 12}} do {
		_apBrg = _apBaseBrg + (_apTry * 30);
		_apDist = _distance + (8 * (floor (_apTry / 4)));
		_apCand = [_apFac, _apDist, _apBrg] Call GetPositionFrom;
		if (!(surfaceIsWater _apCand)) then {
			_apFlat = _apCand isFlatEmpty [8, 0, 2, 8, 0, false, objNull];
			if ((count _apFlat) > 0) then {_position = _apCand; _apOk = true};
		};
		_apTry = _apTry + 1;
	};
	//--- no flat dry apron found in budget: _position is left as the original fixed offset.
	//--- Build84 SPAWN-ON-ROADS (AI-only, gated WFBE_C_AICOM_SPAWN_ON_ROADS default 1): Ray wants AI-commander
	//--- factory output to appear ON A ROAD near the owning factory (so fresh teams start on the road net and
	//--- flow forward, not dumped on the raw apron off-road). Take the pad/apron _position resolved above as the
	//--- reference and snap it to the CLOSEST road node within ~SNAP m; if no road is near, _position is left as
	//--- the pad (fallback = current behaviour). Flag 0 => whole block skipped = pre-Build84 pad behaviour.
	//--- A2-OA-safe: nearRoads + WFBE_CO_FNC_GetClosestEntity + getPos (same idiom as Common_BuildRoadRoute.sqf).
	if ((missionNamespace getVariable ["WFBE_C_AICOM_SPAWN_ON_ROADS", 1]) != 0) then {
		private ["_padPos","_rds","_rdNode"];
		_padPos = _position;
		_rds = _padPos nearRoads (missionNamespace getVariable ["WFBE_C_AICOM_SPAWN_ROAD_RADIUS", 60]);
		if (count _rds > 0) then {
			_rdNode = [_padPos, _rds] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _rdNode) then {_position = getPos _rdNode};
		};
	};
};
//--- TP-9 PLAYER SPAWN-ON-ROADS (gated WFBE_C_PLAYER_SPAWN_ON_ROADS default 0): mirror the AI
//--- road-snap into the player-factory spawn path. When enabled, snaps _position to the nearest
//--- road node within WFBE_C_AICOM_SPAWN_ROAD_RADIUS m; if no road is found, _position is left
//--- as-is (current behaviour = byte-identical fallback). Reuses WFBE_C_AICOM_SPAWN_ROAD_RADIUS:
//--- no second radius constant because the snap geometry is identical for players and AI.
//--- A2-OA-safe: nearRoads + WFBE_CO_FNC_GetClosestEntity + getPos (same idiom as the AI block).
if (isPlayer (leader _team)) then {
	if ((missionNamespace getVariable ["WFBE_C_PLAYER_SPAWN_ON_ROADS", 0]) > 0) then {
		private ["_plRds","_plNode","_plPos"];
		_plPos = _position;
		_plRds = _plPos nearRoads (missionNamespace getVariable ["WFBE_C_AICOM_SPAWN_ROAD_RADIUS", 60]);
		if (count _plRds > 0) then {
			_plNode = [_plPos, _plRds] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _plNode) then {_position = getPos _plNode};
		} else {
			["INFORMATION", Format ["Server_BuyUnit.sqf: PLAYER_SPAWN_ON_ROADS: no road within %1 m of factory for [%2]; using pad position.", (missionNamespace getVariable ["WFBE_C_AICOM_SPAWN_ROAD_RADIUS", 60]), _unitType]] Call WFBE_CO_FNC_LogContent;
		};
	};
};
_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",toUpper _factoryType];  //--- queue-fix 2026-06-14: keys stored UPPERCASE (Init_Common.sqf:356) but _factoryType is mixed-case -> _longest was nil -> the stuck-head purge (_ret>_longest) NEVER fired. toUpper re-arms it.
if (isNil "_longest" || {_longest <= 0}) then {_longest = 60};  //--- safety floor so the deadline is always a real number

_ret = 0;
_queu2 = [0];

if (count _queu > 0) then {
	_queu2 = _building getVariable "queu";
};

while {(count _queu == 0) || {(_id select 0) != (_queu select 0)}} do {  //--- queue-fix: guard empty shared queu (concurrent AI teams / player drain) -> keep polling instead of indexing [] (was: Generic error at [] select 0)
	sleep 4;
	_ret = _ret + 4;
	_queu = _building getVariable "queu";

	//--- ENGINE-VERIFIED (A2OA 1.64, XWT probe 2026-07-03): an exitWith in a while-BODY exits only the
	//--- LOOP, not the script - after this fires, execution falls through to the sleep + spawn section
	//--- below. That is safe here for two reasons: (a) the identical top-scope re-guard after the sleep
	//--- aborts the script for real before anything spawns, and (b) the wfbe_queue release is an ARRAY
	//--- subtraction (removing the same token twice is a no-op), so the double pass cannot double-count.
	//--- Client_BuildUnit.sqf's NUMERIC counters were not safe this way - see its cmdcon44-g comments.
	if (!(alive _building)||(isNull _building)||(isPlayer (leader _team))) exitWith {
		_gbq = (_team getVariable "wfbe_queue") - [_id];
		_team setVariable ["wfbe_queue",_gbq];
		_queu = _building getVariable "queu";
		if (!isNil "_queu" && {count _queu > 0}) then {_queu = _queu - [_queu select 0]};
		_building setVariable ["queu",_queu,true];
		if !(alive _building) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] construction has been stopped due to factory destruction.", _unitType]] Call WFBE_CO_FNC_LogContent};
		if (isPlayer (leader _team)) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] has been canceled, player [%2] has replace the ai.", _unitType, name (leader _team)]] Call WFBE_CO_FNC_LogContent};
	};

	if ((count _queu > 0) && {count _queu2 > 0} && {(_queu select 0) == (_queu2 select 0)}) then {  //--- queue-fix: guard empty queu/queu2 before head-compare
		if (_ret > _longest) then {
			if (count _queu > 0) then {
				_queu = _building getVariable "queu";
				if (!isNil "_queu" && {count _queu > 0}) then {_queu = _queu - [_queu select 0]};
				_building setVariable ["queu",_queu,true];
			};
		};
	};
	if ((count _queu > 0) && {count _queu2 > 0} && {(_queu select 0) != (_queu2 select 0)}) then {  //--- queue-fix 2026-06-14: reset the stuck-head timer ONLY when the head actually advances, not when a sibling / another team's unit churns the shared factory queue (that reset was defeating the purge under batch ordering).
		_ret = 0;
		_queu2 = _building getVariable "queu";
	};
};

sleep _waitTime;

_queu = _building getVariable "queu";
_queu = _queu - [_id select 0];
_building setVariable ["queu",_queu,true];

if (!(alive _building)||(isPlayer (leader _team))) exitWith {
	_gbq = (_team getVariable "wfbe_queue") - [_id];
	_team setVariable ["wfbe_queue",_gbq];
	if !(alive _building) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] construction has been stopped due to factory destruction.", _unitType]] Call WFBE_CO_FNC_LogContent};
	if (isPlayer (leader _team)) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] has been canceled, player [%2] has replace the ai.", _unitType, name (leader _team)]] Call WFBE_CO_FNC_LogContent};
};

if (_unitType isKindOf "Man") then {
	_soldier = [_unitType,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
	[_sideText,'UnitsCreated',1] Call UpdateStatistics;
	//--- AI FACTORY RALLY (task #25): the AI commander stamps wfbe_aicom_factory_rally (a forward,
	//--- road-snapped egress point) on factories it builds. Without a destination a fresh AI unit just
	//--- stands on the factory apron (the "troops standing still in base" bug). Walk it out to the
	//--- rally. Player factories never set the var, so the count-guard makes this AI-only.
	private "_aiRally";
	_aiRally = _building getVariable "wfbe_aicom_factory_rally";
	if (!isNil "_aiRally" && {count _aiRally >= 2} && {!isPlayer (leader _team)} && {!isNull _soldier}) then {
		_soldier commandMove _aiRally;
	};
} else {
	_factoryPosition = getPos _building;
	_dir = -((((_position select 1) - (_factoryPosition select 1)) atan2 ((_position select 0) - (_factoryPosition select 0))) - 90);

	_crew = missionNamespace getVariable Format ["WFBE_%1SOLDIER",_sideText];
	if (_unitType isKindOf "Tank") then {_crew = missionNamespace getVariable Format ["WFBE_%1CREW",_sideText]};
	if (_unitType isKindOf "Air") then {_crew = missionNamespace getVariable Format ["WFBE_%1PILOT",_sideText]};

	_special = if (_unitType isKindOf "Plane") then {"FLY"} else {"NONE"};
	//--- fable/aicom-carrier-velocity (2026-07-07): AI buys at a captured carrier HVT airfield. The AI pad/apron
	//--- sweep above cannot resolve on a carrier (every candidate is open water, surfaceIsWater rejects them), so
	//--- _position falls back to the raw trig offset at the waterline. Mirror the player path's deck handling
	//--- (Client_BuildUnit.sqf naval-air-spawn-easa): give the FLY-spawned fixed-wing the deck height so it
	//--- air-starts with clearance instead of at sea level. wfbe_is_carrier_hvt / wfbe_naval_deckz are broadcast
	//--- by Init_NavalHVT (public=true), so this reads correctly wherever the buy script runs.
	if ((_unitType isKindOf "Plane") && {_building getVariable ["wfbe_is_carrier_hvt", false]}) then {
		_position set [2, (_building getVariable ["wfbe_naval_deckz", 16])];
	};
	_vehicle = [_unitType, _position, _sideID, _dir, true, true, true, _special] Call WFBE_CO_FNC_CreateVehicle;
	//--- N8 BUYFAIL GUARD (MORE-FIXES-AND-IDEAS; mirrors the player-side cmdcon42c HOTFIX in
	//--- Client_BuildUnit.sqf): WFBE_CO_FNC_CreateVehicle returns objNull whenever the engine cannot
	//--- spawn the hull. Without this guard the AI path fell through into unconditional crew creation
	//--- (orphaned unseated soldiers - moveInDriver/Gunner/Commander on a null hull is a no-op), an
	//--- unconditional VehiclesCreated stat bump for a vehicle that does not exist, and no refund of the
	//--- funds already deducted at order time (AI_Commander_Produce.sqf: ChangeAICommanderFunds). ENGINE-
	//--- VERIFIED (cmdcon44-g, Client_BuildUnit.sqf:748): this exitWith only exits the enclosing else-
	//--- block (the Man/Vehicle branch), not the whole script - the shared queue-release tail below
	//--- (wfbe_queue) still runs exactly once, same contract as the player-side guard.
	if (isNull _vehicle) exitWith {
		if (_price > 0) then {[_side, _price] Call ChangeAICommanderFunds};
		["WARNING", Format ["Server_BuyUnit.sqf: buy of [%1] produced objNull (spawn failed) - refunded %2 to side [%3]; no crew spawned.", _unitType, _price, _sideText]] Call WFBE_CO_FNC_LogContent;
	};
	_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];

	// Could seperate the array here for modded vehicles
	if(typeOf _vehicle in ['F35B','AV8B','AV8B2','A10','A10_US_EP1','Su25_Ins','Su25_TK_EP1','Su34','Su39','An2_TK_EP1','L159_ACR','L39_TK_EP1','ibrPRACS_MiG21mol']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles}];};
	if (_vehicle isKindOf "Plane" && (missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) > 0) then {_vehicle addEventHandler ["HandleDamage", {_this Call HandleJetAADamage}];};
    if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];};
	//--- B93 SEAD: tier-5 jets get anti-radar guidance EH when WFBE_C_SEAD > 0
	if ((missionNamespace getVariable ["WFBE_C_SEAD", 0]) > 0 && {typeOf _vehicle in ["F35B","Su34"]}) then {_vehicle addeventhandler ["Fired",{_this spawn WFBE_CO_FNC_HandleSEADMissile}];};
	if ({(typeOf _vehicle) isKindOf _x} count ["LAV25_Base","M2A2_Base","BMP2_Base","BTR90_Base"] != 0) then {_vehicle addeventhandler ["fired",{_this spawn HandleReload;}]};
	if(typeOf _vehicle in ['T90','BMP3']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleATReload;}];};
	if(typeOf _vehicle in ['Pandur2_ACR']) then {
    	_vehicle addeventhandler ['Fired',{_this spawn HandleCommanderReload;}];
    };

// IRS MODULE
if ((typeOf _vehicle) isKindOf "Tank" || (typeOf _vehicle) isKindOf "Car") then {


	_vehicle addeventhandler ['incomingMissile',{_this spawn HandleATMissiles}];


	if ((missionNamespace getVariable "WFBE_C_MODULE_WFBE_IRSMOKE") > 0) then { //--- IR Smoke
		if (((_side) Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_IRSMOKE > 0) then { //--- AI8: use the buying side (_side), not client-side sideJoined (wrong/nil on a dedicated server). Make sure the unit is defined in IRS_Init and the upgrade is available.
			_get = missionNamespace getVariable Format ["%1_IRS", (typeOf _vehicle)];
			if !(isNil '_get') then {
				_vehicle setVariable ["wfbe_irs_flares", _get select 1, true];
				_vehicle addEventHandler ["incomingMissile", {_this spawn WFBE_CO_MOD_IRS_OnIncomingMissile}];
			};
		};
	};
};

	emptyQueu = emptyQueu + [_vehicle];
	[_vehicle] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
	if (_vehicle distance (leader _team) < 200) then {(units _team) allowGetIn true;_team addVehicle _vehicle};

	//--- Clear the vehicle.
	(_vehicle) call WFBE_CO_FNC_ClearVehicleCargo;

	_soldier = [_crew,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;


	[_soldier] allowGetIn true;
	[_soldier] orderGetIn true;
	if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {_vehicle setVariable ["wfbe_balance_side", _side]; (_vehicle) Call BalanceInit};

	if (_unitType isKindOf "Air") then {

		//--- Countermeasures.
		if !(WF_A2_Vanilla) then {
			switch (missionNamespace getVariable "WFBE_C_MODULE_WFBE_FLARES") do { //--- Remove CM if needed.
				case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures}; //--- Disabled.
				case 1: { //--- Enabled with upgrades.
					if (((_side Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_FLARESCM) == 0) then {
						(_vehicle) Call WFBE_CO_FNC_RemoveCountermeasures;
					};
				};
			};
		};

		//--- No AA missiles.
		switch (missionNamespace getVariable "WFBE_C_GAMEPLAY_AIR_AA_MISSILES") do {
			case 0: {(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles};
			case 1: {
				if (((_side Call WFBE_CO_FNC_GetSideUpgrades) select WFBE_UP_AIRAAM) == 0) then {
					(_vehicle) Call WFBE_CO_FNC_RemoveAAMissiles;
				};
			};
		};
	};

	_soldier assignAsDriver _vehicle;
	_soldier moveInDriver _vehicle;
	[_sideText,'VehiclesCreated',1] Call UpdateStatistics;
	_built = 1;
	if (_isVehicle select 1) then {
		_soldier = [_crew,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
		[_soldier] allowGetIn true;
		[_soldier] orderGetIn true;
		_soldier assignAsGunner _vehicle;
		_soldier moveInGunner _vehicle;
		_built = _built + 1;
	};
	if (_isVehicle select 2) then {
		if (vehicle leader _team == leader _team && leader _team distance _vehicle < 200 && alive leader _team) then {
			[leader _team] allowGetIn true;
			[leader _team] orderGetIn true;
			(leader _team) assignAsCommander _vehicle;
			(leader _team) moveInCommander _vehicle;
		} else {
			_soldier = [_crew,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
			[_soldier] allowGetIn true;
			[_soldier] orderGetIn true;
			_soldier assignAsCommander _vehicle;
			_soldier moveInCommander _vehicle;
		};
		_built = _built + 1;
	};

	if (_isVehicle select 3) then {
		Private ["_get","_turrets"];
		_get = missionNamespace getVariable _unitType;
		_turrets = _get select QUERYUNITTURRETS;

		{
			if (isNull (_vehicle turretUnit _x)) then {
				_soldier = [_crew,_team,_position,_sideID] Call WFBE_CO_FNC_CreateUnit;
				[_soldier] allowGetIn true;
				_soldier moveInTurret [_vehicle, _x];
				_built = _built + 1;
			};
		} forEach _turrets;
	};

_vehicle allowCrewInImmobile true;
	//--- AI FACTORY RALLY (task #25): drive the fresh hull off the apron toward the commander's
	//--- forward rally (set on the factory by AI_Commander_Base). commandMove the driver so the
	//--- vehicle takes the lane out instead of idling in base. AI-only via the count-guard.
	private "_aiRally";
	_aiRally = _building getVariable "wfbe_aicom_factory_rally";
	if (!isNil "_aiRally" && {count _aiRally >= 2} && {!isPlayer (leader _team)} && {!isNull (driver _vehicle)}) then {
		(driver _vehicle) commandMove _aiRally;
	};
	//--- fable/aicom-carrier-velocity (2026-07-07): carrier fixed-wing air-start chip - the AI-path equivalent of
	//--- Client_BuildUnit.sqf:598-604 (player carrier velocity override). Common_CreateVehicle's FLY kick is only
	//--- 50 m/s with a level Z and the carrier factory has no wfbe_aicom_factory_rally, so the fresh plane sat in
	//--- the #845 kill window (low, slow, orderless -> mush into the sea). Match the player path's 80 m/s along
	//--- the spawn heading, then give the pilot an immediate climb-out: flyInHeight 550 (the burned-in sea-safe
	//--- naval altitude - Init_NavalHVT jets / #847 An2) and a doMove 2 km ahead with EXPLICIT Z (#845: a Z=0
	//--- doMove is a commanded DESCENT for fixed-wing).
	if ((_building getVariable ["wfbe_is_carrier_hvt", false]) && {_vehicle isKindOf "Plane"}) then {
		private ["_ccOut"];
		_vehicle setVelocity [(sin _dir) * 80, (cos _dir) * 80, 0];
		_vehicle flyInHeight 550;
		if (!isNull (driver _vehicle)) then {
			_ccOut = [getPos _vehicle, 2000, _dir] Call GetPositionFrom;
			_ccOut set [2, 550];
			(driver _vehicle) doMove _ccOut;
		};
		["INFORMATION", Format ["Server_BuyUnit.sqf: carrier air-start chip applied to [%1].", _unitType]] Call WFBE_CO_FNC_LogContent;
	};
	[_sideText,'UnitsCreated',_built] Call UpdateStatistics;
};

_gbq = (_team getVariable "wfbe_queue") - [_id];
_team setVariable ["wfbe_queue",_gbq];