//*****************************************************************************************
//Description: Creates a small construction site.
//*****************************************************************************************
Private ["_buildStage","_completion","_construct","_constructed","_defenses","_direction","_group","_index","_logik","_nearLogic","_objects","_position","_startResultKey","_rlType","_side","_sideID","_site","_siteName","_stage2Objects","_startTime","_structures","_structuresNames","_time","_timeNextUpdate","_type"];
_type = _this select 0;
_side = _this select 1;
_position = _this select 2;
_direction = _this select 3;
_index = _this select 4;
_startResultKey = if ((count _this) > 5) then {_this select 5} else {""};
if ((typeName _startResultKey) != "STRING") then {_startResultKey = ""};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;

_time = ((missionNamespace getVariable Format ["WFBE_%1STRUCTURETIMES",str _side]) select _index) / 2;
	
_siteName = missionNamespace getVariable Format["WFBE_%1CONSTRUCTIONSITE",str _side];

// Refactor to get the parameters from RequestStructure.sqf, no need to run duplicate code
_structures = missionNamespace getVariable Format ['WFBE_%1STRUCTURES',str _side];
_structuresNames = missionNamespace getVariable Format ['WFBE_%1STRUCTURENAMES',str _side];
_rlType = _structures select (_structuresNames find _type);

if (WF_Debug) then {["DEBUG (Construction_SmallSite.sqf)", Format ["Variables - Type: %1, Side: %2, Position: %3, Direction: %4, Index: %5, Logik: %6, SideID: %7, Time: %8, SiteName: %9, Structures: %10, StructuresNames: %11, RLType: %12", _type, _side, _position, _direction, _index, _logik, _sideID, _time, _siteName, _structures, _structuresNames, _rlType]] Call WFBE_CO_FNC_LogContent};

_startTime = time;
_timeNextUpdate = _startTime + _time;

_objects = [];
if (WF_A2_Arrowhead) then {_objects = [[_siteName,[0,0,-0.000230789],359.997,1,0],["Paleta2",[0.416992,-5.62012,-0.305746],0.0130822,1,0],["Land_Barrel_sand",[-5.59448,3.26929,6.29425e-005],359.997,1,0],["Paleta1",[-2.62976,-6.04736,5.53131e-005],0.0130822,1,0],["Barrel4",[6.63696,0.694336,0.000753403],359.991,1,0],["Land_Barrel_sand",[-6.73267,2.06372,6.10352e-005],359.997,1,0],["Barrel5",[7.19604,2.8855,0.00028801],0.0135841,1,0],["Barrel1",[6.08984,5.5415,0.00028801],0.0135841,1,0],["Land_Barrel_sand",[-7.13452,4.40747,6.29425e-005],359.997,1,0],["Land_Ind_Timbers",[0.221924,-8.58496,0.00206566],0.0130822,1,0],["Land_Barrel_sand",[-8.27271,2.80054,6.10352e-005],359.997,1,0],["Barrels",[-7.91895,-4.09668,0.00037384],0.0128253,1,0],["RoadCone",[-10.4381,-8.94336,0.000131607],0.0119093,1,0],["RoadCone",[11.1655,-8.79932,0.00034523],359.991,1,0],["RoadCone",[-10.5692,12.6655,0.000509262],359.948,1,0],["RoadCone",[11.0276,12.3904,0.000509262],359.948,1,0]]};
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {_objects = [[_siteName,[0,0,-0.000230789],359.997,1,0],["Paleta2",[0.416992,-5.62012,-0.305746],0.0130822,1,0],["Land_Barrel_sand",[-5.59448,3.26929,6.29425e-005],359.997,1,0],["Paleta1",[-2.62976,-6.04736,5.53131e-005],0.0130822,1,0],["Barrel4",[6.63696,0.694336,0.000753403],359.991,1,0],["Land_Ind_BoardsPack2",[6.41797,-2.52051,0.000915527],270,1,0],["Land_Barrel_sand",[-6.73267,2.06372,6.10352e-005],359.997,1,0],["Barrel5",[7.19604,2.8855,0.00028801],0.0135841,1,0],["Barrel1",[6.08984,5.5415,0.00028801],0.0135841,1,0],["Land_Barrel_sand",[-7.13452,4.40747,6.29425e-005],359.997,1,0],["Land_Ind_Timbers",[0.221924,-8.58496,0.00206566],0.0130822,1,0],["Land_Barrel_sand",[-8.27271,2.80054,6.10352e-005],359.997,1,0],["Barrels",[-7.91895,-4.09668,0.00037384],0.0128253,1,0],["Land_Ind_BoardsPack1",[6.40332,-7.16162,0.000520706],0.0130822,1,0],["Land_Ind_BoardsPack1",[-6.18384,-8.09961,0.000535965],50.0093,1,0],["RoadCone",[-10.4381,-8.94336,0.000131607],0.0119093,1,0],["RoadCone",[11.1655,-8.79932,0.00034523],359.991,1,0],["RoadCone",[-10.5692,12.6655,0.000509262],359.948,1,0],["RoadCone",[11.0276,12.3904,0.000509262],359.948,1,0]]};
_stage2Objects = [];
if (WF_A2_Arrowhead) then {_stage2Objects = [["Land_WoodenRamp",[-2.45703,-0.593262,0.357508],270,1,0],["Land_WoodenRamp",[-2.5083,1.3811,0.357508],270,1,0],[_siteName,[4.6333,0.338135,0.00393867],90,1,0],["Land_Dirthump02_EP1",[-0.587891,8.57935,0.00207901],359.967,1,0],["Land_Dirthump01_EP1",[-3.97363,-8.49219,-4.57764e-005],29.9804,1,0],["Land_WoodenRamp",[8.8335,-0.125977,0.403545],90,1,0]]};
if (WF_A2_Vanilla || WF_A2_CombinedOps) then {_stage2Objects = [["Land_WoodenRamp",[-2.45703,-0.593262,0.357508],270,1,0],["Land_WoodenRamp",[-2.5083,1.3811,0.357508],270,1,0],[_siteName,[4.6333,0.338135,0.00393867],90,1,0],["Land_Dirthump02",[-0.587891,8.57935,0.00207901],359.967,1,0],["Land_Dirthump01",[-3.97363,-8.49219,-4.57764e-005],29.9804,1,0],["Land_WoodenRamp",[8.8335,-0.125977,0.403545],90,1,0]]};

//--- Capture the exact created logic. The former nearEntities re-discovery could miss this object or select another
//--- simultaneous construction. A top-level failure publishes an optional requester result before any site prop exists.
_group = createGroup sideLogic;
_nearLogic = objNull;
if !(isNull _group) then {_nearLogic = _group createUnit ["LocationLogicStart",_position,[],0,"NONE"]};
if (isNull _nearLogic) exitWith {
	if (_startResultKey != "") then {missionNamespace setVariable [_startResultKey, [-1,"LocationLogicStart missing"]]};
	if !(isNull _group) then {deleteGroup _group};
	diag_log Format ["CONSTRUCTION|v1|reject|reason=missing-start-logic|script=SmallSite|type=%1|pos=%2", _type, _position];
};
_nearLogic setPos _position;
_construct = Compile PreprocessFile "ca\modules\dyno\data\scripts\objectMapper.sqf";
_constructed = ([_position,_direction,_objects] Call _construct);
if (_startResultKey != "") then {missionNamespace setVariable [_startResultKey, [1,""]]};

if ((missionNamespace getVariable "WFBE_C_STRUCTURES_CONSTRUCTION_MODE") == 0) then {
	_nearLogic setVariable ["WFBE_B_Type", _rlType];

	waitUntil {time >= _timeNextUpdate};
	_timeNextUpdate = _startTime + _time * 2;
} else {
	//--- Instanciate the logic.
	_nearLogic setVariable ["WFBE_B_Completion", 0];
	_nearLogic setVariable ["WFBE_B_CompletionRatio", 1.1];
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
	
	if !(isNull _nearLogic) then {
		_group = group _nearLogic;
		deleteVehicle _nearLogic;
		deleteGroup _group;
	};
} else {
	//--- One completion watcher advances the staged site at the same thresholds as the old per-stage loops.
	_buildStage = 1;
	while {_buildStage < 3} do {
		sleep 1;
		_completion = _nearLogic getVariable "WFBE_B_Completion";
		if ((_buildStage == 1) && {_completion >= 50}) then {
			_constructed = _constructed + ([_position,_direction,_stage2Objects] Call _construct);
			_buildStage = 2;
		} else {
			if ((_buildStage == 2) && {_completion >= 100}) then {_buildStage = 3};
		};
	};
	
	//--- Remove the logic from the list since it's built. Add it back if destroyed.
	_logik setVariable ["wfbe_structures_logic", (_logik getVariable "wfbe_structures_logic") - [_nearLogic]]; //--- wiki-wins: was + (double-append); MediumSite uses -
};
	
{if !(isNull _x) then {DeleteVehicle _x}} ForEach _constructed;

_site = createVehicle [_type, _position, [], 0, "NONE"];
_site setDir _direction;
_site setPos _position;
_site setVariable ["wfbe_side", _side];
_site setVariable ["wfbe_structure_type", _rlType];

//--- CBR: spawn composition dressing and register in per-side registry.
if (_rlType == "CBRadar" && (missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0) then {
	private ["_dressTpl","_cbrRegistry","_cbrKey"];
	_dressTpl = Format ["WFBE_NEURODEF_CBRADAR_%1", if (_side == west) then {"WEST"} else {"EAST"}];
	[_site, _dressTpl, _direction] Call WFBE_SE_FNC_SpawnStructureDressing;
	//--- Register in the per-side CBR array.
	_cbrKey = if (_side == west) then {"WFBE_CBR_WEST"} else {"WFBE_CBR_EAST"};
	_cbrRegistry = missionNamespace getVariable [_cbrKey, []];
	_cbrRegistry = _cbrRegistry + [_site];
	missionNamespace setVariable [_cbrKey, _cbrRegistry];
	["INFORMATION", Format ["Construction_SmallSite.sqf: [%1] CBRadar registered. Registry size: %2.", str _side, count _cbrRegistry]] Call WFBE_CO_FNC_LogContent;
	//--- fable/ew-economy: clear the synchronous pending reservation set in RequestStructure.sqf
	//--- now that the real CBRadar is registered (the alive-scan guard there takes over from here).
	//--- Mirrors the Bank pending-clear idiom (Construction_MediumSite.sqf).
	missionNamespace setVariable [Format ["WFBE_%1_CBRadar_PENDING", str _side], -1e11];
};

//--- Radio Tower: register in per-side registry + flip the public alive-flag the client-side radio manager gates on.
if (_rlType == "RadioTower" && (missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER", 0]) > 0) then {
	private ["_rtRegistry","_rtKey","_rtAliveVar"];
	_rtKey = if (_side == west) then {"WFBE_RADIOTOWER_WEST"} else {"WFBE_RADIOTOWER_EAST"};
	_rtRegistry = missionNamespace getVariable [_rtKey, []];
	_rtRegistry = _rtRegistry + [_site];
	missionNamespace setVariable [_rtKey, _rtRegistry];
	_rtAliveVar = if (_side == west) then {"WFBE_RADIOTOWER_WEST_ALIVE"} else {"WFBE_RADIOTOWER_EAST_ALIVE"};
	missionNamespace setVariable [_rtAliveVar, true];
	publicVariable _rtAliveVar;
	["INFORMATION", Format ["Construction_SmallSite.sqf: [%1] RadioTower registered. Registry size: %2.", str _side, count _rtRegistry]] Call WFBE_CO_FNC_LogContent;
};

if((missionNamespace getVariable [Format["WFBE_AUTOWALL_%1", _side], true]) && !(_rlType in ["AARadar","CBRadar"]))then{ //--- wiki-wins: per-side toggle (was the global isAutoWallConstructingEnabled, shared across sides)
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
	//--- fable/fix-walltpl-nil-radiotower (bugrun BUGHUNT-4 / live 1.2.0 RPT): a structure type with no
	//--- WFBE_NEURODEF_<type>_WALLS template (e.g. the AI-built RadioTower added in 1.2.0) leaves _wallTpl
	//--- nil, and CreateDefenseTemplate then errored every build. Treat "no template" as "no auto-walls",
	//--- exactly like the AUTOWALL-off else branch below.
	if (isNil "_wallTpl") then {
		_site setVariable ["WFBE_Walls", []];
	} else {
	_defenses = [_site, _wallTpl] call CreateDefenseTemplate;
	_site setVariable ["WFBE_Walls", _defenses];
	};
} else {
	_site setVariable ["WFBE_Walls", []];
	if (_rlType in ["AARadar","CBRadar"]) then {
		["INFORMATION", Format ["Construction_SmallSite.sqf: [%1] %2 auto walls skipped.", str _side, _rlType]] Call WFBE_CO_FNC_LogContent;
	};
};

[_side, "Constructed", ["Base", _site]] Spawn SideMessage;

if (!isNull _site) then {
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
	
	["INFORMATION", Format ["Construction_SmallSite.sqf: [%1] Structure [%2] has been constructed.", str _side, _type]] Call WFBE_CO_FNC_LogContent;

	//--- B74.2: leaderboard STRUCTURE-built credit. The builder UID is not threaded through the
	//--- RequestStructure->Construction path, so attribute to the nearest same-side player at the
	//--- completed site (the placer stands at the build spot). Nearest-player scan over playableUnits
	//--- (codebase idiom); range is an inline tunable. _site/_side/_position in scope here.
	private ["_bAttrPos","_bAttrSide","_bAttrRange","_bNear","_bDist","_bUid"];
	_bAttrPos   = _position;
	_bAttrSide  = _side;
	_bAttrRange = missionNamespace getVariable ["WFBE_C_STATS_BUILD_ATTR_RANGE", 150];
	_bNear = objNull; _bDist = _bAttrRange + 1;
	{ if (isPlayer _x && {alive _x} && {side _x == _bAttrSide} && {(_x distance _bAttrPos) < _bDist}) then {_bNear = _x; _bDist = _x distance _bAttrPos} } forEach playableUnits;
	if (!isNull _bNear) then {_bUid = getPlayerUID _bNear; if (_bUid != "") then {[_bUid, WFBE_STAT_STRUCTURES_BUILT, 1] call WFBE_SE_FNC_RecordStat}};
};
