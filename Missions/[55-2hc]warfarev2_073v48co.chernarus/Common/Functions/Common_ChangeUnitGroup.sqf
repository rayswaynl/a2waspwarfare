Private ["_entitie", "_group", "_side", "_unit"];

_entitie = objNull;
_unit = _this select 0;
_group = _this select 1;
_side = _this select 2;

_units = (units group _unit) Call WFBE_CO_FNC_GetLiveUnits;
//--- Be aware, if the unit that is changing group is the only one left, the join command will erase the group. We fix it by adding a "temp" unit before the join.
if ((count _units) < 2) then {_entitie = [missionNamespace getVariable Format ["WFBE_%1SOLDIER", _side], group _unit, [0,0,0], _side, false] Call WFBE_CO_FNC_CreateUnit};
[_unit] join _group;
if !(isNull _entitie) then {deleteVehicle _entitie};
//--- TEAMBAR probe (round-2 review: generic group-transfer coverage). Fires only on the machine
//--- where the transferred unit IS the local player - inert everywhere else and when the probe is off.
if (_unit == player && {!isNil "WFBE_CL_FNC_TeambarProbe"}) then {["group-transfer", "post-join"] Call WFBE_CL_FNC_TeambarProbe};