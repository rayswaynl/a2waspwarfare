/* Server-owned side-patrol registry writer. */
Private ["_sideID","_leader","_dispatchID","_side","_group","_list","_registered"];
if (!isServer) exitWith {false};
if (typeName _this != "ARRAY" || {count _this < 2}) exitWith {false};
_sideID = _this select 0;
_leader = _this select 1;
_dispatchID = if (count _this > 2 && {typeName (_this select 2) == "STRING"}) then {_this select 2} else {""};
if (typeName _sideID != "SCALAR" || {typeName _leader != "OBJECT"} || {isNull _leader}) exitWith {false};
_side = _sideID Call WFBE_CO_FNC_GetSideFromID;
if (!(_side in [west, east, resistance])) exitWith {false};
if (side _leader != _side) exitWith {false};
_group = group _leader;
if (isNull _group) exitWith {false};
_list = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];
_registered = false;
{
    if (typeName _x == "ARRAY" && {count _x >= 2}) then {
        if ((_x select 0) == _leader && {(_x select 1) == _sideID}) then {_registered = true};
        if (!_registered && {_dispatchID != ""} && {count _x > 4} && {typeName (_x select 4) == "STRING"} && {(_x select 4) == _dispatchID}) then {_registered = true};
    };
} forEach _list;
if (_registered) exitWith {true};
_list set [count _list, [_leader, _sideID, _group, [], _dispatchID]];
missionNamespace setVariable ["WFBE_ACTIVE_PATROLS", _list];
publicVariable "WFBE_ACTIVE_PATROLS";
true
