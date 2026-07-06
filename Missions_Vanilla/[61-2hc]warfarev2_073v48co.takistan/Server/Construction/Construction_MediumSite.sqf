//*****************************************************************************************
//Description: Creates a small construction site.
//*****************************************************************************************
Private ["_buildStage","_completion","_construct","_constructed","_defenses","_direction","_group","_index","_logik","_nearLogic","_objects","_position","_rlType","_side","_sideID","_site","_siteName","_stage2Objects","_stage3Objects","_startTime","_structures","_structuresNames","_time","_timeNextUpdate","_type"];
_type = _this select 0;
_side = _this select 1;
_position = _this select 2;
_direction = _this select 3;
_index = _this select 4;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;

_time = ((missionNamespace getVariable Format ["WFBE_%1STRUCTURETIMES",str _side]) select _index) / 2;

_siteName = missionNamespace getVariable Format["WFBE_%1CONSTRUCTIONSITE",str _side];

// Refactor to get the parameters from RequestStructure.sqf, no need to run duplicate code
_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES',str _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',str _side];
_rlType = _structures select (_structuresNames find _type);

if (WF_Debug) then {["DEBUG (Construction_MediumSite.sqf)", Format ["Variables - Type: %1, Side: %2, Position: %3, Direction: %4, Index: %5, Logik: %6, SideID: %7, Time: %8, SiteName: %9, Structures: %10, StructuresNames: %11, RLType: %12", _type, _side, _position, _direction, _index, _logik, _sideID, _time, _siteName, _structures, _structuresNames, _rlType]] Call WFBE_CO_FNC_LogContent};

_startTime = time;
_timeNextUpdate = _startTime + _time;

_objects = [];
if (WF_A2_Arrowhead) then {_objects = [[_siteName,[0,0,0.00242043],359.958,1,0],["Paleta2",[0.430908,-5.60693,-0.30535],359.945,1,0],["Paleta1",[-2.62598,-6.0437,0.000275612],359.951,1,0],["Land_Barrel_sand",[-10.1826,0.356689,7.62939e-005],0.00146227,1,0],["Land_Barrel_sand",[-10.7854,-1.97974,0.000187874],359.987,1,0],["Paleta1",[-9.7251,5.53955,0.000106812],359.976,1,0],["Land_Barrel_sand",[-11.053,-4.12183,0.00019455],359.987,1,0],["Land_Barrel_sand",[-12.3416,-1.57056,7.43866e-005],0.00146227,1,0],["Barrels",[-12.5134,0.682861,0.000136375],0.00146227,1,0],["Land_Ind_Timbers",[1.63794,-12.8806,-0.000716209],359.92,1,0],["Land_Barrel_sand",[-11.5149,-6.25757,0.00084877],359.938,1,0],["Land_Barrel_sand",[-12.7363,-3.63184,0.000207901],359.938,1,0],["Barrel4",[14.1938,0.500732,0.000412941],359.98,1,0],["Land_Barrel_sand",[-13.0708,-5.9082,0.000863075],359.938,1,0],["Barrel5",[14.7661,-1.11182,0.000411987],359.98,1,0],["Barrel1",[14.7314,2.21338,0.000409126],359.98,1,0],["Paleta2",[12.0034,9.8418,-0.305568],0.0412118,1,0],["RoadCone",[-12.2202,-13.7024,0.000279427],359.984,1,0],["RoadCone",[-12.1877,15.0469,0.000328064],359.969,1,0],["RoadCone",[14.5701,-13.311,0.000322342],359.995,1,0],["RoadCone",[14.6084,14.6824,0.000889778],359.994,1,0]]};
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {_objects = [[_siteName,[0,0,0.00242043],359.958,1,0],["Paleta2",[0.430908,-5.60693,-0.30535],359.945,1,0],["Paleta1",[-2.62598,-6.0437,0.000275612],359.951,1,0],["Land_Ind_BoardsPack1",[-0.82251,-9.15479,0.00291061],49.9467,1,0],["Land_Barrel_sand",[-10.1826,0.356689,7.62939e-005],0.00146227,1,0],["Land_Barrel_sand",[-10.7854,-1.97974,0.000187874],359.987,1,0],["Paleta1",[-9.7251,5.53955,0.000106812],359.976,1,0],["Land_Ind_Timbers",[1.88354,11.1238,-0.487763],95.0061,1,0],["Land_Barrel_sand",[-11.053,-4.12183,0.00019455],359.987,1,0],["Land_Ind_BoardsPack1",[-6.6582,-10.0774,0.0021534],324.956,1,0],["Land_Ind_BoardsPack1",[9.50244,-7.4668,0.00151634],270,1,0],["Land_Ind_Timbers",[12.0264,4.19629,-0.534346],359.98,1,0],["Land_Barrel_sand",[-12.3416,-1.57056,7.43866e-005],0.00146227,1,0],["Barrels",[-12.5134,0.682861,0.000136375],0.00146227,1,0],["Land_Ind_Timbers",[1.63794,-12.8806,-0.000716209],359.92,1,0],["Land_Barrel_sand",[-11.5149,-6.25757,0.00084877],359.938,1,0],["Land_Barrel_sand",[-12.7363,-3.63184,0.000207901],359.938,1,0],["Land_Ind_BoardsPack1",[-4.74194,-12.4204,0.00105476],49.9807,1,0],["Barrel4",[14.1938,0.500732,0.000412941],359.98,1,0],["Land_Barrel_sand",[-13.0708,-5.9082,0.000863075],359.938,1,0],["Barrel5",[14.7661,-1.11182,0.000411987],359.98,1,0],["Land_Ind_BoardsPack1",[9.42847,-11.5142,0.00151634],359.964,1,0],["Barrel1",[14.7314,2.21338,0.000409126],359.98,1,0],["Paleta2",[12.0034,9.8418,-0.305568],0.0412118,1,0],["RoadCone",[-12.2202,-13.7024,0.000279427],359.984,1,0],["RoadCone",[-12.1877,15.0469,0.000328064],359.969,1,0],["RoadCone",[14.5701,-13.311,0.000322342],359.995,1,0],["RoadCone",[14.6084,14.6824,0.000889778],359.994,1,0]]};
_construct = Compile PreprocessFile "ca\modules\dyno\data\scripts\objectMapper.sqf";
_constructed = ([_position,_direction,_objects] Call _construct);

_stage2Objects = [];
if (WF_A2_Arrowhead) then {_stage2Objects = [[_siteName,[2.52539,-0.0065918,-0.000685692],359.928,1,0],["Land_WoodenRamp",[-2.27954,-0.582764,0.377601],270,1,0],["Land_WoodenRamp",[0.94751,-4.2085,0.388518],179.986,1,0],[_siteName,[2.60547,6.20386,-0.000685692],359.928,1,0],["Land_Dirthump01_EP1",[-8.63159,8.021,-0.00167847],29.985,1,0]]};
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {_stage2Objects = [[_siteName,[2.52539,-0.0065918,-0.000685692],359.928,1,0],["Land_WoodenRamp",[-2.27954,-0.582764,0.377601],270,1,0],["Land_WoodenRamp",[0.94751,-4.2085,0.388518],179.986,1,0],[_siteName,[2.60547,6.20386,-0.000685692],359.928,1,0],["Land_Dirthump01",[-8.63159,8.021,-0.00167847],29.985,1,0]]};

_stage3Objects = [];
if (WF_A2_Arrowhead) then {_stage3Objects = [["Land_Misc_Scaffolding",[5.67456,2.39307,0.0763969],179.92,1,0],["Land_Dirthump02_EP1",[-8.63159,8.021,0.000141144],29.9958,1,0],["Barrels",[11.4519,12.5623,0.00311279],359.877,1,0],["RoadCone",[-12.1465,-13.7354,0.000406265],359.958,1,0]]};
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {_stage3Objects = [["Land_Misc_Scaffolding",[5.67456,2.39307,0.0763969],179.92,1,0],["Land_Ind_Timbers",[10.0811,4.63477,-0.127748],359.961,1,0],["Land_Dirthump02",[-8.63159,8.021,0.000141144],29.9958,1,0],["Land_Ind_BoardsPack1",[13.3027,-7.63159,0.00639725],359.838,1,0],["Land_Ind_BoardsPack1",[-9.70117,-12.4263,0.00152397],324.976,1,0],["Land_Ind_BoardsPack1",[-7.78491,-14.7693,0.00152779],49.9774,1,0],["Barrels",[11.4519,12.5623,0.00311279],359.877,1,0],["Land_Ind_BoardsPack1",[13.4668,-11.5061,0.00515175],359.942,1,0],["RoadCone",[-12.1465,-13.7354,0.000406265],359.958,1,0]]};

//--- Create the logic.
(createGroup sideLogic) createUnit ["LocationLogicStart",_position,[],0,"NONE"];

_nearLogic = objNull;
if ((missionNamespace getVariable "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") == 0) then {
	//--- Grab the logic.
	_nearLogic = _position nearEntities [["LocationLogicStart"],15];
	_nearLogic = [_position, _nearLogic] Call WFBE_CO_FNC_GetClosestEntity;
	
	if (isNull _nearLogic) exitWith {};
	
	//--- Position the logic.
	_nearLogic setPos _position;
	
	_nearLogic setVariable ["WFBE_B_Type", _rlType];

	waitUntil {time >= _timeNextUpdate};
	_timeNextUpdate = _startTime + _time * 2;
} else {
	//--- Grab the logic.
	_nearLogic = _position nearEntities [["LocationLogicStart"],15];
	_nearLogic = [_position, _nearLogic] Call WFBE_CO_FNC_GetClosestEntity;
	
	if (isNull _nearLogic) exitWith {};
	
	//--- Position the logic.
	_nearLogic setPos _position;
	
	//--- Instanciate the logic.
	_nearLogic setVariable ["WFBE_B_Completion", 0];
	_nearLogic setVariable ["WFBE_B_CompletionRatio", 0.6];
	_nearLogic setVariable ["WFBE_B_Direction", _direction];
	_nearLogic setVariable ["WFBE_B_Position", _position];
	_nearLogic setVariable ["WFBE_B_Repair", false];
	_nearLogic setVariable ["WFBE_B_Type", _rlType];
	
	//--- Add the logic to the list.
	_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") + [_nearLogic]];
};

if ((missionNamespace getVariable "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") == 0) then {
	_constructed = _constructed + ([_position,_direction,_stage2Objects] Call _construct);
	waitUntil {time >= _timeNextUpdate};
	_timeNextUpdate = _startTime + _time * 3;
	_constructed = _constructed + ([_position,_direction,_stage3Objects] Call _construct);
	waitUntil {time >= _timeNextUpdate};
	
	if !(isNull _nearLogic) then {
		_group = group _nearLogic;
		deleteVehicle _nearLogic;
		deleteGroup _group;
	};
} else {
	//--- One completion watcher advances the staged site at the same thresholds as the old per-stage loops.
	_buildStage = 1;
	while {_buildStage < 4} do {
		sleep 1;
		_completion = _nearLogic getVariable "WFBE_B_Completion";
		if ((_buildStage == 1) && {_completion >= 33.33}) then {
			_constructed = _constructed + ([_position,_direction,_stage2Objects] Call _construct);
			_buildStage = 2;
		} else {
			if ((_buildStage == 2) && {_completion >= 66.66}) then {
				_constructed = _constructed + ([_position,_direction,_stage3Objects] Call _construct);
				_buildStage = 3;
			} else {
				if ((_buildStage == 3) && {_completion >= 100}) then {_buildStage = 4};
			};
		};
	};
	
	//--- Remove the logic from the list since it's built. Add it back if destroyed.
	_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") - [_nearLogic]];
};

{if !(isNull _x) then {deleteVehicle _x}} forEach _constructed;

_site = createVehicle [_type, _position, [], 0, "NONE"];
_site setDir _direction;
_site setPos _position;
_site setVariable ["wfbe_side", _side];
_site setVariable ["wfbe_structure_type", _rlType];

//--- Bank: spawn composition dressing, register in per-side registry, create global marker, start income drip.
if (_rlType == "Bank" && (missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	private ["_dressTpl","_bankKey","_markerName","_markerColor","_markerText"];
	_dressTpl = Format ["WFBE_NEURODEF_BANK_%1", if (_side == west) then {"WEST"} else {"EAST"}];
	//--- cmdcon43-c: the cmdcon42-g Bank wall-ladder dressing (_V2) is REVERTED — the Bank is not a
	//--- factory, so it is out of scope for the Build 88 "factory walls + slabs" change. Back to the
	//--- legacy WFBE_NEURODEF_BANK_WEST/EAST dressing bodies.
	[_site, _dressTpl, _direction] Call WFBE_SE_FNC_SpawnStructureDressing;
	//--- Register single-instance reference.
	_bankKey = if (_side == west) then {"WFBE_BANK_WEST"} else {"WFBE_BANK_EAST"};
	missionNamespace setVariable [_bankKey, _site];
	//--- B66: clear the synchronous pending reservation set in RequestStructure.sqf now that the
	//--- real bank is registered (the live-bank guard takes over from here).
	missionNamespace setVariable [_bankKey + "_PENDING", -1e11];
	//--- Global map marker visible to all players (createMarker is global on server).
	_markerName = Format ["wfbe_bank_%1", if (_side == west) then {"west"} else {"east"}];
	_markerColor = if (_side == west) then {"ColorBlue"} else {"ColorRed"};
	_markerText = if (_side == west) then {"FEDERAL RESERVE"} else {"BANK ROSSII"};
	createMarker [_markerName, _position];
	_markerName setMarkerType "mil_warning";
	_markerName setMarkerColor _markerColor;
	_markerName setMarkerText _markerText;
	_site setVariable ["wfbe_bank_marker", _markerName];
	//--- Spawn income drip script via registered function.
	[_site, _side] Spawn WFBE_SE_FNC_BankIncome;
	["INFORMATION", Format ["Construction_MediumSite.sqf: [%1] Bank registered. Marker [%2] created.", str _side, _markerName]] Call WFBE_CO_FNC_LogContent;
};

//--- Reserve / ArtilleryRadar: spawn faction composition dressing (task 13 — WDDM starred presets).
//--- Mirrors the Bank branch above. Templates WFBE_NEURODEF_RESERVE_WEST/EAST and
//--- WFBE_NEURODEF_ARTILLERYRADAR_WEST/EAST live in Server\Init\Init_Defenses.sqf.
//--- These two are now EXCLUDED from the auto-walls block below so walls don't double up
//--- with the dressing rings (the dressing IS the walls + furniture, like Bank/CBR).
//--- Purely cosmetic, one-time spawn; cleanup via the function's Killed EH on _site.
if (_rlType in ["Reserve","ArtilleryRadar"]) then {
	private ["_dressTpl"];
	_dressTpl = Format ["WFBE_NEURODEF_%1_%2", toUpper _rlType, if (_side == west) then {"WEST"} else {"EAST"}];
	[_site, _dressTpl, _direction] Call WFBE_SE_FNC_SpawnStructureDressing;
	["INFORMATION", Format ["Construction_MediumSite.sqf: [%1] %2 composition dressing spawned via [%3].", str _side, _rlType, _dressTpl]] Call WFBE_CO_FNC_LogContent;
};

if((missionNamespace getVariable [Format["WFBE_AUTOWALL_%1", _side], true]) && !(_rlType in ["AARadar","Bank","Reserve","ArtilleryRadar"]))then{ //--- wiki-wins: per-side toggle (was the global isAutoWallConstructingEnabled, shared across sides)
	//--- cmdcon43-c: WFBE_C_WALLS_V3 selects the "original walls + HQ-style concrete slabs" array
	//--- (_WALLS_V3) over the plain legacy one at spawn time. Falls back to legacy if the _V3 var is
	//--- missing (defensive, never nil-spawns). Flag=0 -> legacy name -> exact original walls (no slabs).
	//--- (The cmdcon42-g _WALLS_V2 wall-ladder is reverted; WFBE_C_WALLS_V2 is dead.) See Server\Init\Init_Defenses.sqf.
	private ["_wallVarName","_wallTpl"];
	_wallVarName = format ["WFBE_NEURODEF_%1_WALLS", _rlType];
	//--- fable/wddm-functional-defenses: WFBE_C_WALLS_V4 (default 0) prefers the redesigned _WALLS_V4
	//--- slab layer (legacy ring + contiguous HQ-pitch Concrete_Wall_EP1 runs, walking gaps preserved,
	//--- +X egress faces open) when the flag is on AND the _V4 array exists (ServicePoint has none ->
	//--- falls through). Flag 0 or no _V4 array -> the V3/legacy logic below runs UNTOUCHED.
	if (((missionNamespace getVariable ["WFBE_C_WALLS_V4", 0]) > 0) && {!(isNil {missionNamespace getVariable (_wallVarName + "_V4")})}) then {
		_wallVarName = _wallVarName + "_V4";
	} else {
		if ((missionNamespace getVariable ["WFBE_C_WALLS_V3", 1]) > 0) then {
			if !(isNil {missionNamespace getVariable (_wallVarName + "_V3")}) then {_wallVarName = _wallVarName + "_V3"};
		};
	};
	_wallTpl = missionNamespace getVariable _wallVarName;
	_defenses = [_site, _wallTpl] call CreateDefenseTemplate;
	_site setVariable ["WFBE_Walls", _defenses];
} else {
	_site setVariable ["WFBE_Walls", []];
	if (_rlType in ["AARadar","Bank","Reserve","ArtilleryRadar"]) then {
		["INFORMATION", Format ["Construction_MediumSite.sqf: [%1] %2 auto walls skipped.", str _side, _rlType]] Call WFBE_CO_FNC_LogContent;
	};
};

[_side, "Constructed", ["Base", _site]] Spawn SideMessage;

if (!IsNull _site) then {
	_logik setVariable ["wfbe_structures", (_logik getVariable "wfbe_structures") + [_site], true];
	
	_site setVehicleInit Format["[this,false,%1] ExecVM 'Client\Init\Init_BaseStructure.sqf'",_sideID];
	processInitCommands;
	
	_site addEventHandler ["hit",{_this Spawn BuildingDamaged}];
	if ((missionNamespace getVariable "WFBE_C_GAMEPLAY_HANDLE_FRIENDLYFIRE") > 0) then {
		_site addEventHandler ['handleDamage',{[_this select 0,_this select 2,_this select 3] Call BuildingHandleDamages}];
	} else {
		_site addEventHandler ['handleDamage',{[_this select 0, _this select 2] Call HandleBuildingDamage}];
	};
	Call Compile Format ["_site AddEventHandler ['killed',{[_this select 0,_this select 1,'%1'] Spawn BuildingKilled}];",_type];
	
	["INFORMATION", Format ["Construction_MediumSite.sqf: [%1] Structure [%2] has been constructed.", str _side, _type]] Call WFBE_CO_FNC_LogContent;

	//--- B74.2: leaderboard STRUCTURE-built credit. Builder UID is not threaded through the
	//--- RequestStructure->Construction path; attribute to the nearest same-side player at the
	//--- completed site (the placer stands at the build spot). Same idiom as Construction_SmallSite.sqf.
	private ["_bAttrPos","_bAttrSide","_bAttrRange","_bNear","_bDist","_bUid"];
	_bAttrPos   = _position;
	_bAttrSide  = _side;
	_bAttrRange = missionNamespace getVariable ["WFBE_C_STATS_BUILD_ATTR_RANGE", 150];
	_bNear = objNull; _bDist = _bAttrRange + 1;
	{ if (isPlayer _x && {alive _x} && {side _x == _bAttrSide} && {(_x distance _bAttrPos) < _bDist}) then {_bNear = _x; _bDist = _x distance _bAttrPos} } forEach playableUnits;
	if (!isNull _bNear) then {_bUid = getPlayerUID _bNear; if (_bUid != "") then {[_bUid, WFBE_STAT_STRUCTURES_BUILT, 1] call WFBE_SE_FNC_RecordStat}};
};
