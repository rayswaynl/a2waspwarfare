Private ["_arty", "_artyWaitDeadline"];
_arty = _this select 0;
_artyWaitDeadline = diag_tickTime + 120;

//--- The BIS artillery module can load after a vehicle init command, and the vehicle can be
//--- destroyed before that load completes. Yield between checks and fail closed in both cases.
waitUntil {
	sleep 0.25;
	isNull _arty || {(!isNil "BIS_ARTY_LOADED" && {BIS_ARTY_LOADED})} || {diag_tickTime >= _artyWaitDeadline}
};
if (isNull _arty) exitWith {};
if (isNil "BIS_ARTY_LOADED" || {!BIS_ARTY_LOADED}) exitWith {};
sleep 5;
if (isNull _arty) exitWith {};

[_arty] call BIS_ARTY_F_initVehicle;
