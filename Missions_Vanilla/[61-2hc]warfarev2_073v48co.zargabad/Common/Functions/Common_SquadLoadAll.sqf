//--- Common_SquadLoadAll.sqf
//--- Team-menu bulk mount (WFBE_C_SQUAD_BULK_MOUNT, default 0). Pattern studied from the
//--- rhs_cargosystem whole-squad bulk-load idiom, remade here in vanilla A2 SQF: mounts
//--- every live squad AI (never the player) that is already within boarding range of the
//--- target vehicle into a free seat. v1 does not path-walk distant units - only units
//--- already in range are moved (owner-recommended scope, see the Team Menu V2 card).
//---
//--- Params: [_grp, _veh]
//---   _grp - GROUP whose live members (Call GetLiveUnits) are candidates to mount.
//---   _veh - OBJECT target vehicle. Must be alive and non-null.
//--- Returns: NUMBER of units mounted this call.

Private ["_grp","_veh","_range","_squadUnits","_mounted","_du"];

_mounted = 0;

if (isNil "_this") exitWith {_mounted};
if (typeName _this != "ARRAY") exitWith {_mounted};
if (count _this < 2) exitWith {_mounted};

_grp = _this select 0;
_veh  = _this select 1;

if (isNil "_grp") exitWith {_mounted};
if (isNull _grp) exitWith {_mounted};
if (isNil "_veh") exitWith {_mounted};
if (isNull _veh) exitWith {_mounted};
if !(alive _veh) exitWith {_mounted};

_range = missionNamespace getVariable ["WFBE_C_SQUAD_BULK_MOUNT_RANGE", 10];

_squadUnits = ((units _grp) Call GetLiveUnits) - [player];

{
	_du = _x;
	if (!isPlayer _du) then {
		if (vehicle _du == _du) then {
			if ((_du distance _veh) <= _range) then {
				[_du] allowGetIn true;
				if (isNull (driver _veh)) then {
					_du moveInDriver _veh;
					_mounted = _mounted + 1;
				} else {
					if (isNull (gunner _veh)) then {
						_du moveInGunner _veh;
						_mounted = _mounted + 1;
					} else {
						if ((_veh emptyPositions "cargo") > 0) then {
							_du moveInCargo _veh;
							_mounted = _mounted + 1;
						};
					};
				};
			};
		};
	};
} forEach _squadUnits;

_mounted
