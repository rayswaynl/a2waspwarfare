//--- Common_SquadUnloadAll.sqf
//--- Team-menu bulk dismount (WFBE_C_SQUAD_BULK_MOUNT, default 0). Pattern studied from the
//--- rhs_cargosystem staggered bulk-dismount idiom, remade here in vanilla A2 SQF: AI crew
//--- (never the player) belonging to the calling player's own squad get out one at a time,
//--- sleeping WFBE_C_SQUAD_BULK_MOUNT_STAGGER seconds between actions so a full vehicle does
//--- not all GetOut on the same tick at 144-per-side scale. Crew who belong to a different
//--- group (e.g. another player's AI riding the same shared vehicle) are left untouched -
//--- this action must never eject units outside the caller's own squad.
//---
//--- MUST be Spawned (holds a sleep loop), never Call'd. Params: [_veh, _grp]
//---   _veh - OBJECT vehicle whose AI crew should dismount.
//---   _grp - GROUP whose members are eligible to be dismounted (the caller's squad).
//--- Clears the caller-set "wfbe_tm2_unload_lock" broadcast lock on exit (mirrors the
//--- existing "wfbe_tm2_repair_lock" idiom already used by the Get-Out-and-Repair action
//--- in GUI_Menu_TeamV2.sqf).
//--- Returns: NUMBER of units that had GetOut issued.

Private ["_veh","_grp","_stagger","_squadUnits","_crewList","_du","_dismounted"];

_dismounted = 0;

if (isNil "_this") exitWith {_dismounted};
if (typeName _this != "ARRAY") exitWith {_dismounted};
if (count _this < 2) exitWith {_dismounted};

_veh = _this select 0;
_grp = _this select 1;

if (isNil "_veh") exitWith {_dismounted};
if (isNull _veh) exitWith {_dismounted};
if (isNil "_grp") exitWith {_dismounted};
if (isNull _grp) exitWith {_dismounted};

_stagger    = missionNamespace getVariable ["WFBE_C_SQUAD_BULK_MOUNT_STAGGER", 0.15];
_squadUnits = units _grp;
_crewList   = crew _veh;

{
	_du = _x;
	if (!isNull _veh) then {
		if (!isPlayer _du) then {
			if (_du in _squadUnits) then {
				if (alive _du) then {
					_du action ["GetOut", _veh];
					_dismounted = _dismounted + 1;
					sleep _stagger;
				};
			};
		};
	};
} forEach _crewList;

if (!isNull _veh) then {_veh setVariable ["wfbe_tm2_unload_lock", false, true]};

_dismounted
