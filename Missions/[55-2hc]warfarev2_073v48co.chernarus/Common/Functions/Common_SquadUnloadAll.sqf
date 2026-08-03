//--- Common_SquadUnloadAll.sqf
//--- Team-menu bulk dismount (WFBE_C_SQUAD_BULK_MOUNT, default 0). Pattern studied from the
//--- rhs_cargosystem staggered bulk-dismount idiom, remade here in vanilla A2 SQF: every AI
//--- crew member (never the player) gets out one at a time, sleeping
//--- WFBE_C_SQUAD_BULK_MOUNT_STAGGER seconds between actions so a full vehicle does not all
//--- GetOut on the same tick at 144-per-side scale.
//---
//--- MUST be Spawned (holds a sleep loop), never Call'd. Params: [_veh]
//---   _veh - OBJECT vehicle whose AI crew should dismount.
//--- Clears the caller-set "wfbe_tm2_unload_lock" broadcast lock on exit (mirrors the
//--- existing "wfbe_tm2_repair_lock" idiom already used by the Get-Out-and-Repair action
//--- in GUI_Menu_TeamV2.sqf).
//--- Returns: NUMBER of units that had GetOut issued.

Private ["_veh","_stagger","_crewList","_du","_dismounted"];

_dismounted = 0;

if (isNil "_this") exitWith {_dismounted};
if (typeName _this != "ARRAY") exitWith {_dismounted};
if (count _this < 1) exitWith {_dismounted};

_veh = _this select 0;

if (isNil "_veh") exitWith {_dismounted};
if (isNull _veh) exitWith {_dismounted};

_stagger  = missionNamespace getVariable ["WFBE_C_SQUAD_BULK_MOUNT_STAGGER", 0.15];
_crewList = crew _veh;

{
	_du = _x;
	if (!isNull _veh) then {
		if (!isPlayer _du) then {
			if (alive _du) then {
				_du action ["GetOut", _veh];
				_dismounted = _dismounted + 1;
				sleep _stagger;
			};
		};
	};
} forEach _crewList;

if (!isNull _veh) then {_veh setVariable ["wfbe_tm2_unload_lock", false, true]};

_dismounted
