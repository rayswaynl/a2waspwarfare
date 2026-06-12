/*
	Create a unit.
	 Parameters:
		- Classname
		- Group
		- Position
		- Side ID
		- {Global Init}
		- {PLacement}
*/

Private ["_get", "_global", "_globalInitMode", "_leaderIsPlayer", "_perfScope", "_perfStart", "_position", "_side", "_skill", "_special", "_team", "_trackInfantry", "_type", "_unit"];

_type = _this select 0;
_team = _this select 1;
_position = _this select 2;
_side = _this select 3;
_global = if (count _this > 4) then {_this select 4} else {true};
_special = if (count _this > 5) then {_this select 5} else {"FORM"};
// Marty: Performance Audit tracks whether unit creation causes global client initialization.
_perfStart = diag_tickTime;
_globalInitMode = "globalFalse";
_trackInfantry = missionNamespace getVariable ["WFBE_C_UNITS_TRACK_INFANTRY", -1];
_leaderIsPlayer = false;

if (typeName _side == "SIDE") then {_side = (_side) Call WFBE_CO_FNC_GetSideID};

_get = missionNamespace getVariable _type;
_skill = if !(isNil '_get') then {_get select QUERYUNITSKILL} else {missionNamespace getVariable "WFBE_C_UNITS_SKILL_DEFAULT"};
_unit = _team createUnit [_type, _position, [], 5, _special];
_unit setSkill _skill;

if(side _unit == east && !(_unit hasWeapon "NVGoggles")) then {
   _unit addWeapon "NVGoggles";
};

// Add custom dragon soldier (Ins_Soldier_AT)
if (_type == "Ins_Soldier_AT") then {
	_unit removeMagazine "PG7VL";
	_unit removeMagazine "PG7VL";
	_unit removeMagazine "PG7VL";
	_unit removeWeapon "RPG7V";
	_unit addWeapon "M47Launcher_EP1";
	_unit addMagazine "Dragon_EP1";
	_unit addMagazine "Dragon_EP1";
};

// Add custom RPG-7 VR soldier (MVD_Soldier_AT)
if (_type == "MVD_Soldier_AT") then {
	_unit removeMagazine "PG7VL";
	_unit removeMagazine "PG7VL";
	_unit removeMagazine "OG7";
	_unit addMagazine "PG7VR";
	_unit addMagazine "PG7VR";
};

if (_global) then {
	if (_side != WFBE_DEFENDER_ID || WFBE_ISTHREEWAY) then {
		if ((missionNamespace getVariable "WFBE_C_UNITS_TRACK_INFANTRY") > 0) then {
			_globalInitMode = "vehicleInit";
			_unit setVehicleInit Format["[this,%1] ExecVM 'Common\Init\Init_Unit.sqf';", _side];
			processInitCommands;
		} else {
			_leaderIsPlayer = isPlayer leader _team;
			if (_leaderIsPlayer) then {
				_globalInitMode = "localPlayerInit";
				[_unit, _side] ExecVM 'Common\Init\Init_Unit.sqf'
			} else {
				_globalInitMode = "trackOffNoPlayer";
			};
		};
	} else {
		_globalInitMode = "defenderSkipped";
	};
};

_unit addEventHandler ['Killed', Format ['[_this select 0,_this select 1,%1] Spawn WFBE_CO_FNC_OnUnitKilled', _side]];

["INFORMATION", Format ["Common_CreateUnit.sqf: [%1] Unit [%2] was created at [%3] and has been assigned to team [%4]", _side Call WFBE_CO_FNC_GetSideFromID, _type, _position, _team]] Call WFBE_CO_FNC_LogContent;

// Marty: Audit one unit creation so logs can correlate client marker init storms with AI growth.
if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["createunit", diag_tickTime - _perfStart, Format["type:%1;side:%2;global:%3;trackInf:%4;init:%5;leaderPlayer:%6;isMan:%7", _type, _side, _global, _trackInfantry, _globalInitMode, _leaderIsPlayer, _unit isKindOf "Man"], _perfScope] Call PerformanceAudit_Record;
	};
};

_unit
