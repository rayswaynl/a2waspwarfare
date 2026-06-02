if (!isServer || !IS_zargabad_lowpop_map) exitWith {};

Private ["_buildBase", "_buildCentralWall", "_baseWalls", "_centralWall", "_centralWallSpans", "_mgWall", "_sides"];

_baseWalls = [
	["Land_HBarrier_large",[-55,-55,0],45],["Land_HBarrier_large",[-30,-70,0],15],
	["Land_HBarrier_large",[0,-76,0],0],["Land_HBarrier_large",[30,-70,0],345],
	["Land_HBarrier_large",[55,-55,0],315],["Land_HBarrier_large",[70,-25,0],270],
	["Land_HBarrier_large",[70,25,0],270],["Land_HBarrier_large",[55,55,0],225],
	["Land_HBarrier_large",[25,70,0],180],["Land_HBarrier_large",[-25,70,0],180],
	["Land_HBarrier_large",[-55,55,0],135],["Land_HBarrier_large",[-70,25,0],90],
	["Land_HBarrier_large",[-70,-25,0],90]
];

_mgWall = missionNamespace getVariable ["WFBE_NEURODEF_MG", []];
_centralWall = [];
_centralWallSpans = [[-1180,-1018],[-790,-628],[-420,-258],[30,192],[470,632],[870,1032]];
{
	for "_offset" from (_x select 0) to (_x select 1) step 18 do {
		_centralWall = _centralWall + [["Land_HBarrier_large",[0,_offset,0],0]];
	};
} forEach _centralWallSpans;
missionNamespace setVariable ["WFBE_ZARGABAD_CENTRAL_WALL", _centralWall];

_buildCentralWall = {
	Private ["_origin", "_pos"];
	_pos = [3425,3375,0];
	_origin = (createGroup sideLogic) createUnit ["Logic", _pos, [], 0, "NONE"];
	_origin setDir 316;
	[_origin, missionNamespace getVariable ["WFBE_ZARGABAD_CENTRAL_WALL", []]] call CreateDefenseTemplate;
	deleteVehicle _origin;
};

_buildBase = {
	Private ["_def", "_dir", "_logic", "_origin", "_pos", "_side", "_sideID", "_statics", "_team", "_unit"];
	_side = _this select 0;
	_dir = _this select 1;
	_logic = (_side Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_startpos";
	if (isNil "_logic" || {isNull _logic}) exitWith {};
	_pos = getPos _logic;
	_origin = (createGroup sideLogic) createUnit ["Logic", _pos, [], 0, "NONE"];
	_origin setDir _dir;

	[_origin, _baseWalls] call CreateDefenseTemplate;
	[_origin, _mgWall] call CreateDefenseTemplate;

	_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
	_team = missionNamespace getVariable Format ["WFBE_%1_DefenseTeam", _side];
	if (isNull _team) then {_team = createGroup _side; missionNamespace setVariable [Format ["WFBE_%1_DefenseTeam", _side], _team]};
	_statics = if (_side == west) then {
		[["M2StaticMG_US_EP1",[-45,0,0],270],["M2StaticMG_US_EP1",[45,0,0],90],["TOW_TriPod_US_EP1",[0,58,0],0],["Stinger_Pod_US_EP1",[0,-58,0],180]]
	} else {
		[["KORD_high_TK_EP1",[-45,0,0],270],["KORD_high_TK_EP1",[45,0,0],90],["Metis_TK_EP1",[0,-58,0],180],["Igla_AA_pod_TK_EP1",[0,58,0],0]]
	};

	{
		_pos = _origin modelToWorld (_x select 1);
		_pos set [2, 0];
		_def = createVehicle [_x select 0, _pos, [], 0, "NONE"];
		_def setDir (_dir + (_x select 2));
		_def setPos _pos;
		_def setVariable ["side", _side];
		_def setVariable ["wfbe_defense", true];
		Call Compile Format ["_def addEventHandler ['Killed',{[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled}]", _sideID];
		_unit = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side], _team, _pos, _side] Call WFBE_CO_FNC_CreateUnit;
		_unit setVariable ["WFBE_IsBaseDefenderAI", true, true];
		_unit assignAsGunner _def;
		[_unit] orderGetIn true;
		_unit moveInGunner _def;
		emptyQueu = emptyQueu + [_def];
		[_def] Spawn WFBE_SE_FNC_HandleEmptyVehicle;
	} forEach _statics;

	deleteVehicle _origin;
};

_sides = [[west, 45], [east, 225]];
{_x call _buildBase} forEach _sides;
[] call _buildCentralWall;

[] execVM "Server\Module\Zargabad\Zargabad_EdgeGuard.sqf";
[] execVM "Server\Module\Zargabad\Zargabad_BlackMarket.sqf";

["INITIALIZATION", "Init_Zargabad.sqf: Spawn fortifications, central wall gaps, and side defenses are placed."] Call WFBE_CO_FNC_LogContent;
