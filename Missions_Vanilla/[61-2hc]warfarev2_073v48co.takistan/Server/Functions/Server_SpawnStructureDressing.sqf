/* Server_SpawnStructureDressing.sqf
   Spawns a static-prop composition around a newly built structure (core object).
   Called server-side right after createVehicle completes in Construction_SmallSite.sqf.

   Parameters:
     0 - core object (the structure entity, already placed)
     1 - template variable name (string, e.g. "WFBE_NEURODEF_CBRADAR_WEST")
     2 - facing direction of core in degrees (same _direction passed to Construction_SmallSite)

   Uses the same rotation math as Server_ConstructPosition.sqf lines 50-56.
   Spawned props are stored on the core as wfbe_dressing [array].
   A Killed EH on the core deletes all dressing props when the core dies.
*/
Private ["_core","_tplName","_dir","_template","_i","_entry","_cls","_relPos","_relDir","_origin","_worldPos","_worldDir","_prop","_props"];

_core   = _this select 0;
_tplName = _this select 1;
_dir    = _this select 2;

if (isNull _core) exitWith {
    ["WARNING", Format ["Server_SpawnStructureDressing.sqf: core is null, template [%1] skipped.", _tplName]] Call WFBE_CO_FNC_LogContent;
};

_template = missionNamespace getVariable [_tplName, []];
if (count _template == 0) exitWith {
    ["INFORMATION", Format ["Server_SpawnStructureDressing.sqf: template [%1] is empty — no dressing for [%2].", _tplName, typeOf _core]] Call WFBE_CO_FNC_LogContent;
};

_origin = getPos _core;
_props = [];

for "_i" from 0 to (count _template - 1) do {
    _entry  = _template select _i;
    _cls    = _entry select 0;
    _relPos = _entry select 1;
    _relDir = _entry select 2;

    //--- Rotate relPos offset by core direction (identical to Server_ConstructPosition.sqf lines 50-56).
    _worldPos = [
        (_origin select 0) + (_relPos select 0) * (cos _dir) + (_relPos select 1) * (sin _dir),
        (_origin select 1) - (_relPos select 0) * (sin _dir) + (_relPos select 1) * (cos _dir),
        0
    ];
    _worldPos set [2, 0];
    _worldDir = _dir - _relDir;

    _prop = createVehicle [_cls, _worldPos, [], 0, "NONE"];
    _prop setDir _worldDir;
    _prop setPos _worldPos;
    _props = _props + [_prop];
};

_core setVariable ["wfbe_dressing", _props];

//--- Clean up dressing when the core is killed.
_core addEventHandler ["Killed", {
    private ["_dead","_dressing"];
    _dead = _this select 0;
    _dressing = _dead getVariable ["wfbe_dressing", []];
    {if !(isNull _x) then {deleteVehicle _x}} forEach _dressing;
    ["INFORMATION", Format ["Server_SpawnStructureDressing.sqf: cleaned %1 dressing props for killed [%2].", count _dressing, typeOf _dead]] Call WFBE_CO_FNC_LogContent;
}];

["INFORMATION", Format ["Server_SpawnStructureDressing.sqf: spawned %1 dressing props around [%2] using [%3].", count _props, typeOf _core, _tplName]] Call WFBE_CO_FNC_LogContent;
