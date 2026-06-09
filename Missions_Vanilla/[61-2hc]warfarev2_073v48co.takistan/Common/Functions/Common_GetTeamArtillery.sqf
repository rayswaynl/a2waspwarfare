Private["_artillery","_artyTypes","_artyWeapons","_baseAreas","_commanderRadius","_commanderTeam","_count","_hq","_ignoreAmmo","_inCommandArea","_index","_ownerSide","_position","_search","_side","_sideText","_sideValue","_team","_tryAddArtillery","_units","_vehicle","_weapon","_x","_y"];

_team = _this select 0;
_ignoreAmmo = _this select 1;
_index = _this select 2;
_side = _this select 3;
_sideText = if (typeName _side == "SIDE") then {str _side} else {_side};
_sideValue = if (typeName _side == "SIDE") then {_side} else {
	switch (_side) do {
		case "WEST": {west};
		case "EAST": {east};
		case "GUER": {resistance};
		case "RESISTANCE": {resistance};
		default {west};
	};
};

if (_index < 0) exitWith {[]};

_units = units _team;
_artyTypes = (missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES",_sideText]) select _index;
_artyWeapons = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_WEAPONS",_sideText];

_artillery = [];

_tryAddArtillery = {
	_vehicle = _this;

	if (typeOf(_vehicle) in _artyTypes) then {
		if (!(isNull(gunner _vehicle)) && !(_vehicle in _artillery) && !(isPlayer(gunner _vehicle))) then {
			if !(isPlayer(gunner _vehicle)) then {
				_weapon = _artyWeapons select _index;

				if (_ignoreAmmo || (_vehicle ammo _weapon > 0)) then {
					_artillery = _artillery + [_vehicle];
				};
			};
		};
	};
};

{
	(vehicle _x) Call _tryAddArtillery;
} forEach _units;

_commanderTeam = _sideValue Call WFBE_CO_FNC_GetCommanderTeam;
if !(isNull _commanderTeam) then {
	if (_team == _commanderTeam) then {
		_hq = _sideValue Call WFBE_CO_FNC_GetSideHQ;
		_baseAreas = (_sideValue Call WFBE_CO_FNC_GetSideLogic) getVariable "wfbe_basearea";
		if (isNil "_baseAreas") then {_baseAreas = []};
		_commanderRadius = (missionNamespace getVariable "WFBE_C_BASE_AREA_RANGE") + (missionNamespace getVariable "WFBE_C_BASE_HQ_BUILD_RANGE");

		{
			_vehicle = _x;
			_ownerSide = _vehicle getVariable "WFBE_CommanderArtillerySide";
			if (isNil "_ownerSide") then {_ownerSide = ""};

			if (_ownerSide == _sideText) then {
				_inCommandArea = false;
				if !(isNull _hq) then {
					if (_vehicle distance _hq <= _commanderRadius) then {_inCommandArea = true};
				};

				if !(_inCommandArea) then {
					{
						if !(isNull _x) then {
							if (_vehicle distance _x <= _commanderRadius) exitWith {_inCommandArea = true};
						};
					} forEach _baseAreas;
				};

				if (_inCommandArea) then {
					(_vehicle) Call _tryAddArtillery;
				};
			};
		} forEach vehicles;
	};
};

_artillery
