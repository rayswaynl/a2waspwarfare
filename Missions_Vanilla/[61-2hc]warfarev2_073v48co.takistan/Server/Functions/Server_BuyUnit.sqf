Private ["_building","_built","_config","_crew","_direction","_dir","_distance","_factoryType","_factoryPosition","_gbq","_id","_index","_isVehicle","_longest","_position","_queu","_queu2","_ret","_side","_sideID","_sideText","_soldier","_team","_turrets","_type","_unitType","_vehicle","_waitTime"];
_id = _this select 0;
_building = _this select 1;
_unitType = _this select 2;
_side = _this select 3;
_sideID = (_side) Call GetSideID;
_team = _this select 4;
_isVehicle = _this select 5;

_sideText = str _side;

if (!(alive _building)||(isPlayer (leader _team))) exitWith {
	_gbq = (_team getVariable "wfbe_queue") - _id;
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
_distance = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDISTANCES",_sideText]) select _index;
_direction = (missionNamespace getVariable Format ["WFBE_%1STRUCTUREDIRECTIONS",_sideText]) select _index;
_factoryType = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES",_sideText]) select _index;
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
};
_longest = missionNamespace getVariable Format ["WFBE_LONGEST%1BUILDTIME",toUpper _factoryType];  //--- queue-fix 2026-06-14: keys stored UPPERCASE (Init_Common.sqf:356) but _factoryType is mixed-case -> _longest was nil -> the stuck-head purge (_ret>_longest) NEVER fired. toUpper re-arms it.
if (isNil "_longest" || {_longest <= 0}) then {_longest = 60};  //--- safety floor so the deadline is always a real number

_ret = 0;
_queu2 = [0];

if (count _queu > 0) then {
	_queu2 = _building getVariable "queu";
};

while {_id select 0 != _queu select 0} do {
	sleep 4;
	_ret = _ret + 4;
	_queu = _building getVariable "queu";

	if (!(alive _building)||(isNull _building)||(isPlayer (leader _team))) exitWith {
		_gbq = (_team getVariable "wfbe_queue") - _id;
		_team setVariable ["wfbe_queue",_gbq];
		_queu = _building getVariable "queu";
		_queu = _queu - [_queu select 0];
		_building setVariable ["queu",_queu,true];
		if !(alive _building) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] construction has been stopped due to factory destruction.", _unitType]] Call WFBE_CO_FNC_LogContent};
		if (isPlayer (leader _team)) then {["INFORMATION", Format ["Server_BuyUnit.sqf: Unit [%1] has been canceled, player [%2] has replace the ai.", _unitType, name (leader _team)]] Call WFBE_CO_FNC_LogContent};
	};

	if (_queu select 0 == _queu2 select 0) then {
		if (_ret > _longest) then {
			if (count _queu > 0) then {
				_queu = _building getVariable "queu";
				_queu = _queu - [_queu select 0];
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
	_gbq = (_team getVariable "wfbe_queue") - _id;
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
	_vehicle = [_unitType, _position, _sideID, _dir, true, true, true, _special] Call WFBE_CO_FNC_CreateVehicle;
	_vehicle addEventHandler ["Fired",{_this Spawn HandleRocketTraccer}];

	// Could seperate the array here for modded vehicles
	if(typeOf _vehicle in ['F35B','AV8B','AV8B2','A10','A10_US_EP1','Su25_Ins','Su25_TK_EP1','Su34','Su39','An2_TK_EP1','L159_ACR','L39_TK_EP1','ibrPRACS_MiG21mol']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles}];};
	if (_vehicle isKindOf "Plane" && (missionNamespace getVariable ["WFBE_C_JET_AA_SURVIVE", 1]) > 0) then {_vehicle addEventHandler ["HandleDamage", {_this Call HandleJetAADamage}];};
    if(typeOf _vehicle in ['2S6M_Tunguska','M6_EP1']) then {_vehicle addeventhandler ['Fired',{_this spawn HandleAAMissiles;}];};
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
	if ((missionNamespace getVariable "WFBE_C_UNITS_BALANCING") > 0) then {(_vehicle) Call BalanceInit};

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
	[_sideText,'UnitsCreated',_built] Call UpdateStatistics;
};

_gbq = (_team getVariable "wfbe_queue") - _id;
_team setVariable ["wfbe_queue",_gbq];