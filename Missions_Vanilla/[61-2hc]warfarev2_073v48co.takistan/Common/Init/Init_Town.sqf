Private ['_camps','_marker','_town','_townDubbingName','_townMaxSV','_townName','_townRange','_townStartSV','_townValue','_town_type','_wCamps','_wCommonInit','_wServerInit','_wSupplyValue','_wTownInitServer','_wTownMode'];

_town = _this select 0;
_townName = _this select 1;
_townDubbingName = _this select 2;
_townStartSV = _this select 3;
_townMaxSV = _this select 4;
//--- Older/custom maps may omit the town-value column and pass town type in arg 5.
_townValue = 0;
if ((count _this) > 6) then {
	_townValue = _this select 5;
	_town_type = _this select 6;
} else {
	_town_type = if ((count _this) > 5) then {_this select 5} else {""};
};
_townRange = 600;

if(isNil "WFBE_Parameters_Ready")then{
	WFBE_Parameters_Ready = false;
};


//--- J6 HANGGUARD: mode/parameter readiness must not leave a town thread parked forever.
_wTownMode = 0;
while {(!townModeSet || !WFBE_Parameters_Ready) && (_wTownMode < 240)} do { uiSleep 0.25; _wTownMode = _wTownMode + 1; };
if (!townModeSet || !WFBE_Parameters_Ready) then {
	diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: town mode/parameters were not ready after 60s - proceeding (town=%1).", (_town getVariable ["name", "?"])];
};

//--- Prevent the isServer bug on the client.
sleep (1.2 + random 0.2);

//todo, opposite system.
if ((str _town) in TownTemplate) exitWith {
	["INITIALIZATION",Format ["Init_Town.sqf : Removed town [%1] since it is disabled.", _townName]] Call WFBE_CO_FNC_LogContent;
	_town setVariable ["wfbe_inactive", true];
};

if (isNull _town || (_town getVariable "wfbe_inactive")) exitWith {};

_town setVariable ["name",_townName];
_town setVariable ["range",_townRange];
_town setVariable ["startingSupplyValue",_townStartSV];
_town setVariable ["maxSupplyValue",_townMaxSV];
_town setVariable ["LastSupplyMissionRun", 0]; //--- XR4: match the read/write casing in isSupplyMissionActiveInTown / supplyMissionStarted (was lowercase "lastSupplyMissionRun" -> first cooldown check read nil).
_town setVariable ["supplyMissionCoolDownEnabled", false];

//--- If the town type is an array rather than a single value, pick a random template (see Server_GetTownGroupsDefender.sqf).
if (typeName _town_type == "ARRAY") then {_town_type = _town_type select floor(random count _town_type)};
_town setVariable ["wfbe_town_type", _town_type];
//--- A8 (claude-gaming): wire in the previously-dead _townValue (Init_Town arg 6) so the
//--- AI-commander spearhead ranking can reward high-value towns (read nil-safe in Strategy).
if (!isNil "_townValue") then {_town setVariable ["wfbe_town_value", _townValue]};

//--- J6 HANGGUARD: common initialization must not park every town forever.
_wCommonInit = 0;
while {(!commonInitComplete) && (_wCommonInit < 240)} do { uiSleep 0.25; _wCommonInit = _wCommonInit + 1; };
if (!commonInitComplete) then {
	diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: common initialization was not complete after 60s - proceeding (town=%1).", (_town getVariable ["name", "?"])];
};

if (isServer) then {
	Private ["_camps", "_defenses", "_synced"];
	//--- Get the camps and defenses, note that synchronizedObjects only work for the server.
	_camps = [];
	_defenses = [];

	for '_i' from 0 to count(synchronizedObjects _town)-1 do {
		_synced = (synchronizedObjects _town) select _i;
		if (typeOf _synced == "LocationLogicCamp" && (missionNamespace getVariable "WFBE_C_CAMPS_CREATE") > 0) then {
			[_camps, _synced] Call WFBE_CO_FNC_ArrayPush;
			_synced setVariable ["town", _town];
		};
		if (!isNil {_synced getVariable "wfbe_defense_kind"}) then {[_defenses, _synced] Call WFBE_CO_FNC_ArrayPush};
	};

	["INITIALIZATION",Format ["Init_Town.sqf : Found [%1] synchronized camps in [%2].", count _camps, _town getVariable "name"]] Call WFBE_CO_FNC_LogContent;



	_town setVariable ["camps", _camps, true];
	_town setVariable ["wfbe_town_defenses", _defenses];

	_townDubbingName = switch (_townDubbingName) do {
		case "+": {_townName};//--- Copy the name.
		case "": {"Town"};//--- Unknown name, apply Town dubbing.
		default {_townDubbingName};//--- Input name.
	};
	_town setVariable ["wfbe_town_dubbing", _townDubbingName];

	//--- Don't pause.
	[_town,_townStartSV,_townRange] Spawn {
		Private ["_camps","_defenses","_marker","_size","_town","_townModel","_townRange","_townStartSV","_wServerInit","_wSupplyValue","_wTownInitServer"];
		_town = _this select 0;
		_townStartSV = _this select 1;
		_townRange = _this select 2;
		_camps = _town getVariable "camps";

		//--- Models creation.
		_townModel = createVehicle [missionNamespace getVariable "WFBE_C_DEPOT", getPos _town, [], 0, "NONE"];
		_townModel setDir ((getDir _town) + (missionNamespace getVariable "WFBE_C_DEPOT_RDIR"));
		_townModel setPos (getPos _town);
		_townModel addEventHandler ["handleDamage", {0}];

		if (isNil {_town getVariable "sideID"}) then {_town setVariable ["sideID",WFBE_DEFENDER_ID,true]};
		_town setVariable ["supplyValue",_townStartSV,true];

		sleep (random 1);

		//--- J6 HANGGUARD: server initialization must not park a town worker forever.
		_wServerInit = 0;
		while {(!serverInitComplete) && (_wServerInit < 240)} do { uiSleep 0.25; _wServerInit = _wServerInit + 1; };
		if (!serverInitComplete) then {
			diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: server initialization was not complete after 60s - proceeding (town=%1).", (_town getVariable ["name", "?"])];
		};
		_towns_camps 		= [];
		_town_camp_flags    = [];
		_camp_counter = 0;
		{
			Private ["_camp_health","_flag","_pos","_townModel","_campXY"];
			//--- fable/fix-camp-placement (2026-07-08): ground-snap the spawn XY to ATL 0 (terrain surface).
			//--- Fixes Zargabad's 13 LocationLogicCamp anchors, authored at literal elevation 0 in mission.sqm
			//--- (buried/underwater on non-flat terrain - zargabad/mission.sqm:62 etc, all 13 confirmed Y=0).
			//--- Chernarus/Takistan anchors already carry real elevations, so this is a no-op there. A2 OA has
			//--- no getTerrainHeightASL (Server\server_heli_terrain_guard.sqf:8); z=0 in a 3-element
			//--- createVehicle/setPos array IS the ATL ground-level literal (same idiom already shipped at
			//--- Server\Init\Init_NavalHVT.sqf:947).
			_campXY = getPos _x;
			//--- Create the camp model.
			_townModel = createVehicle [missionNamespace getVariable "WFBE_C_CAMP", [_campXY select 0, _campXY select 1, 0], [], 0, "NONE"];
			_townModel setDir ((getDir _x) + (missionNamespace getVariable "WFBE_C_CAMP_RDIR"));
			_townModel setPos [_campXY select 0, _campXY select 1, 0];
			["INFORMATION", Format ["Init_Town.sqf: camp ground-snap dz=%1m at %2 (town=%3).", ((getPos _x) select 2), _campXY, _town getVariable "name"]] Call WFBE_CO_FNC_LogContent;

			//--- Maybe we want to make the camp stronger.
			_camp_health = missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF";
			if !(isNil '_camp_health') then {
				_townModel addEventHandler ["handleDamage",{getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))}];
			};

			//--- Create a flag near the camp location & position it. fable/fix-camp-placement: ground-snap Z
			//--- too (the raw modelToWorld result inherits _x's own buried Z on ZG; XY offset/rotation math
			//--- from _x's transform is unchanged).
			_pos = _x modelToWorld (missionNamespace getVariable "WFBE_C_CAMP_FLAG_POS");
			_flag = createVehicle [missionNamespace getVariable "WFBE_C_CAMP_FLAG", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
			_flag setPos [_pos select 0, _pos select 1, 0];

			_x setVariable ["wfbe_flag", _flag];

			//--- Initialize the camp.
			if (isNil {_x getVariable "sideID"}) then {_x setVariable ["sideID",WFBE_DEFENDER_ID,true]};
			if (isNil {_x getVariable "supplyValue"}) then {
				_wSupplyValue = 0;
				while {isNil {_town getVariable "supplyValue"} && (_wSupplyValue < 120)} do { uiSleep 0.25; _wSupplyValue = _wSupplyValue + 1; };
				if (!isNil {_town getVariable "supplyValue"}) then {
					_x setVariable ["supplyValue", _town getVariable "supplyValue", true];
					_x setVariable ["wfbe_camp_bunker", _townModel, true];
					_towns_camps = _towns_camps + [_x];
					//--- kimi/bughunt-mission-core (2026-07-20): keep _town_camp_flags index-parallel with
					//--- _towns_camps - it used to grow UNCONDITIONALLY below, so a camp that failed the SV
					//--- sync (HANGGUARD path) left the flag list one element longer and server_town_camp.sqf
					//--- paired every subsequent camp with the WRONG flag (capture re-textured the wrong pole).
					_town_camp_flags = _town_camp_flags + [_flag];
					//[_x, _town, _flag] execVM "Server\FSM\server_town_camp.sqf";
				} else {
					diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: town supplyValue was not ready after 30s - skipping camp supply sync (town=%1).", (_town getVariable ["name", "?"])];
				};
			};
			["INITIALIZATION",Format ["Init_Town.sqf : Initialized Camp in [%1].", _town getVariable "name"]] Call WFBE_CO_FNC_LogContent;
			_camp_counter = _camp_counter + 1;
		} forEach _camps;

		if(_camp_counter == count _camps && {(count _camps > 0) || {!((missionNamespace getVariable ["WFBE_C_SKIP_EMPTY_CAMP_THREAD", 0]) > 0)}})then{
			[_towns_camps, _town, _town_camp_flags] execVM "Server\FSM\server_town_camp.sqf";
		};


		//--- J6 HANGGUARD: the server town census must not park this worker forever.
		_wTownInitServer = 0;
		while {(!townInitServer) && (_wTownInitServer < 240)} do { uiSleep 0.25; _wTownInitServer = _wTownInitServer + 1; };
		if (!townInitServer) then {
			diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: townInitServer was not ready after 60s - proceeding (town=%1).", (_town getVariable ["name", "?"])];
		};

		// Marty: Prepare default static defenses only for resistance towns; BLUFOR/OPFOR occupation towns use mobile defenders only.
		if ((_town getVariable "sideID") == WFBE_DEFENDER_ID && (missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER") > 0 && {!(_town getVariable ["wfbe_inactive", false])}) then { //--- WFBE_C_TEST_TOWN_CAP (test-only, default off): skip static-defense setup for towns capped out of towns[] by Server\Init\Init_Towns.sqf.
			[_town, (_town getVariable "sideID") Call WFBE_CO_FNC_GetSideFromID, -1] Call WFBE_SE_FNC_ManageTownDefenses;
		};

		//--- Town SV & Control script.
		//[_town, _townRange] execVM 'Server\FSM\server_town.sqf';

		//--- Main Town AI Script
		//if ((missionNamespace getVariable "WFBE_C_TOWNS_DEFENDER") > 0 || (missionNamespace getVariable "WFBE_C_TOWNS_OCCUPATION") > 0) then {[_town, _townRange] execVM 'Server\FSM\server_town_ai.sqf'};
	};
};

//--- Client camp init.
if (local player) then {
	_wCamps = 0;
	while {isNil {_town getVariable "camps"} && (_wCamps < 120)} do { uiSleep 0.25; _wCamps = _wCamps + 1; };
	if (!isNil {_town getVariable "camps"}) then {
		_camps = _town getVariable "camps";
		for '_i' from 0 to count(_camps)-1 do {
			_camp = _camps select _i;
			_camp setVariable ["wfbe_camp_marker", Format ["WFBE_%1_CityMarker_Camp%2", str _town, _i]];
			_camp setVariable ["town", _town];
		};

		["INITIALIZATION",Format ["Init_Town.sqf : (Client) Initialized Camps [%1] for town [%2].", count _camps, _townName]] Call WFBE_CO_FNC_LogContent;
	} else {
		diag_log format ["[WFBE (INIT)] HANGGUARD| Init_Town.sqf: town camps were not synced after 30s - skipping client camp setup (town=%1).", (_town getVariable ["name", "?"])];
	};
};

["INITIALIZATION",Format ["Init_Town.sqf : Initialized town [%1].", _townName]] Call WFBE_CO_FNC_LogContent;

towns = towns + [_town];
