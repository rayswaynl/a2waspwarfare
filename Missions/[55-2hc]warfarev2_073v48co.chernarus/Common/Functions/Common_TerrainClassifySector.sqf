/*
	Common_TerrainClassifySector.sqf

	Classifies a town's surrounding terrain sector for AICOM composition biasing.
	Averages WFBE_C_TERRAIN_CLASSIFY_SAMPLES (default 5) jittered selectBestPlaces samples per
	axis (Houses/Forest/Trees/Hills) around the town position, then picks the axis with the
	highest average score under a fixed tie order (Houses > Forest > Trees > Hills) to derive
	one of three classes: "garrison" (Houses-dominant), "bush-camp" (Forest/Trees-dominant), or
	"open-maneuver" (Hills-dominant / no strong axis). Runs once per town at boot, gated by the
	caller on WFBE_C_TERRAIN_CLASSIFY_SECTORS - classify+cache only, zero composition effect on
	its own (see the WFBE_C_TERRAIN_SECTOR_COMPOSITION consumer in Server_GetTownGroups.sqf /
	Server_GetTownGroupsDefender.sqf).

	Parameters:
		0: Town entity (an object with a "range" variable, as used by server_town_ai.sqf)

	Returns: nothing. Writes onto the town object:
		wfbe_sector_class      - "garrison" | "bush-camp" | "open-maneuver"
		wfbe_sector_classified - true once a class has been written
*/

Private ["_town","_pos","_range","_axisList","_axisScores","_axis","_sampleCount","_precision","_jitterMax","_i","_jitterPos","_jAng","_jDist","_sample","_top","_val","_sum","_valid","_avg","_houses","_forest","_trees","_hills","_class"];

_town = _this select 0;

if (isNil "_town" || {typeName _town != "OBJECT"} || {isNull _town}) exitWith {};

_pos = getPos _town;
_range = _town getVariable ["range", 300];
if (_range < 50) then {_range = 50};

_sampleCount = missionNamespace getVariable ["WFBE_C_TERRAIN_CLASSIFY_SAMPLES", 5];
if (_sampleCount < 1) then {_sampleCount = 1};
_precision = missionNamespace getVariable ["WFBE_C_TERRAIN_CLASSIFY_PRECISION", 5];
if (_precision < 1) then {_precision = 1};
_jitterMax = missionNamespace getVariable ["WFBE_C_TERRAIN_CLASSIFY_JITTER_M", 20];
if (_jitterMax < 0) then {_jitterMax = 0};

_axisList = ["houses","forest","trees","hills"];
_axisScores = [];

{
	_axis = _x;
	_sum = 0;
	_valid = 0;
	for "_i" from 1 to _sampleCount do {
		_jitterPos = _pos;
		if (_jitterMax > 0) then {
			_jAng = random 360;
			_jDist = random _jitterMax;
			_jitterPos = [(_pos select 0) + _jDist * sin _jAng, (_pos select 1) + _jDist * cos _jAng, 0];
		};
		_sample = selectBestPlaces [_jitterPos, _range, _axis, _precision, 1];
		//--- Validate before select 0 select 1 - a bad/empty sample must never poison the average.
		if ((typeName _sample == "ARRAY") && {(count _sample) > 0}) then {
			_top = _sample select 0;
			if ((typeName _top == "ARRAY") && {(count _top) > 1}) then {
				_val = _top select 1;
				if (typeName _val == "SCALAR") then {
					_sum = _sum + _val;
					_valid = _valid + 1;
				};
			};
		};
	};
	_avg = 0;
	if (_valid > 0) then {_avg = _sum / _valid};
	[_axisScores, _avg] Call WFBE_CO_FNC_ArrayPush;
} forEach _axisList;

_houses = _axisScores select 0;
_forest = _axisScores select 1;
_trees  = _axisScores select 2;
_hills  = _axisScores select 3;

//--- Fixed tie order (card spec): Houses > Forest > Trees > Hills. Houses-dominant = garrison;
//--- Forest/Trees-dominant = bush-camp; otherwise (Hills-dominant, or all-zero/no valid samples) = open-maneuver.
_class = "open-maneuver";
if (_houses >= _forest && {_houses >= _trees} && {_houses >= _hills} && {_houses > 0}) then {
	_class = "garrison";
} else {
	if (_forest >= _trees && {_forest >= _hills} && {_forest > 0}) then {
		_class = "bush-camp";
	} else {
		if (_trees >= _hills && {_trees > 0}) then {
			_class = "bush-camp";
		};
	};
};

_town setVariable ["wfbe_sector_class", _class];
_town setVariable ["wfbe_sector_classified", true];

["INFORMATION", Format ["Common_TerrainClassifySector.sqf: town [%1] classified [%2] (houses=%3 forest=%4 trees=%5 hills=%6).", _town getVariable ["name", "?"], _class, _houses, _forest, _trees, _hills]] Call WFBE_CO_FNC_AICOMLog;
