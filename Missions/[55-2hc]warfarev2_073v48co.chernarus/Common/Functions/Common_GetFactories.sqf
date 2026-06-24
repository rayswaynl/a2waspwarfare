Private ["_buildings","_kind","_list","_side","_type"];
_side = _this select 0;
_kind = _this select 1;
_buildings = _this select 2;

_list = [];
//--- collection guard: caller may pass a nil/short array or a nil structure list (fresh client / JIP before wfbe_structures replicates); a bare forEach throws "Undefined variable _buildings" every frame from the AC FSM.
if (isNil "_buildings") exitWith {_list};
if (typeName _buildings != "ARRAY") exitWith {_list};
_type = (missionNamespace getVariable Format["WFBE_%1STRUCTURENAMES", _side]) select _kind;
//--- nil-hole guard: deleted/compacted structure arrays can carry nil entries; a bare _x read throws (102x/boot in RPT).
{if (!isNil "_x") then {if (typeOf _x == _type && {alive _x}) then {_list = _list + [_x]}}} forEach _buildings;

_list