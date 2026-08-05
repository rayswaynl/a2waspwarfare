Private ["_truck"];

//--- Repair-truck CoIn entry: null/dead truck mid-action must not open coin_interface on a ghost.
_truck = if (typeName _this == "ARRAY" && {count _this > 0}) then {_this select 0} else {_this};
if (isNull _truck || {!alive _truck}) exitWith {};
if (isNil "RCoin") exitWith {};

[player, player, 2, RCoin, getPos player, _truck] ExecVM "Client\Module\CoIn\coin_interface.sqf";
