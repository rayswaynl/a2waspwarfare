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

Private ["_get", "_global", "_globalInitMode", "_leaderIsPlayer", "_perfScope", "_perfStart", "_position", "_side", "_sideValue", "_skill", "_special", "_team", "_teamLeader", "_trackInfantry", "_type", "_unit"];

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

_sideValue = _side;
if (typeName _side == "SIDE") then {
	_side = (_side) Call WFBE_CO_FNC_GetSideID;
} else {
	_sideValue = _side Call WFBE_CO_FNC_GetSideFromID;
};
if (isNull _team) then {_team = [_sideValue, "misc"] Call WFBE_CO_FNC_CreateGroup};
if ((count units _team) > 0) then {
	_teamLeader = leader _team;
	if (!(isNull _teamLeader) && {!local _teamLeader}) then {
		["WARNING", Format ["Common_CreateUnit.sqf: Team [%1] leader [%2] for unit [%3] is not local here; creating local fallback group.", _team, _teamLeader, _type]] Call WFBE_CO_FNC_LogContent;
		_team = [_sideValue, "misc"] Call WFBE_CO_FNC_CreateGroup;
	};
};

// Marty: Do not attempt createUnit on grpNull; callers can degrade without spawning empty vehicles.
if (isNull _team) exitWith {
	["WARNING", Format ["Common_CreateUnit.sqf: Unit [%1] for side [%2] was not created because target group is null.", _type, _side]] Call WFBE_CO_FNC_LogContent;
	objNull
};

_get = missionNamespace getVariable _type;
_skill = if !(isNil '_get') then {_get select QUERYUNITSKILL} else {missionNamespace getVariable "WFBE_C_UNITS_SKILL_DEFAULT"};
_unit = _team createUnit [_type, _position, [], 5, _special];

// Marty: Stop cleanly if the engine refused the unit, usually because a group/unit limit was reached.
if (isNull _unit) exitWith {
	["WARNING", Format ["Common_CreateUnit.sqf: Unit [%1] for side [%2] failed to create in group [%3] at [%4].", _type, _side, _team, _position]] Call WFBE_CO_FNC_LogContent;
	objNull
};

_unit setSkill _skill;

// Claude: weapon-backfill. Some specialist EP1 / crew classes come back from
// createUnit with an EMPTY primary loadout (engine quirk), producing the
// weaponless dismounts seen capturing towns. Re-apply the class's OWN config
// loadout - faction/class-safe - but ONLY when it ended up with no rifle AND no
// launcher, so it never touches intentionally pistol-only roles. Gameplay-
// transparent: it can only ADD a weapon that should have been there.
if (_unit isKindOf "Man" && {primaryWeapon _unit == "" && secondaryWeapon _unit == ""}) then {
	private ["_cfgWeps", "_cfgMags"];
	_cfgWeps = getArray (configFile >> "CfgVehicles" >> _type >> "weapons");
	_cfgMags = getArray (configFile >> "CfgVehicles" >> _type >> "magazines");
	{_unit addMagazine _x} forEach _cfgMags;
	{if (!(_unit hasWeapon _x) && {!(_x in ["Throw", "Put"])}) then {_unit addWeapon _x}} forEach _cfgWeps;
	["WARNING", Format ["Common_CreateUnit.sqf: weapon-backfill applied to weaponless [%1] (primary now [%2]).", _type, primaryWeapon _unit]] Call WFBE_CO_FNC_LogContent;
};

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
	if (!isNil "isHeadLessClient" && {isHeadLessClient}) then {
		//--- HC-created (delegated) AI skips the global Init_Unit broadcast entirely: the
		//--- setVehicleInit path would spawn marker/action loops on every client (and every
		//--- JIP) for units that are pure AI offload. Mirrors the defenderSkipped rationale.
		_globalInitMode = "hcSkipped";
	} else {
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
