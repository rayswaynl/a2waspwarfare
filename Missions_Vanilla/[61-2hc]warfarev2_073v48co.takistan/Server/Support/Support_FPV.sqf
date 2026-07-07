Private["_args","_driver","_drone","_playerTeam","_side","_timeStart","_timeout"];

_args = _this;
//--- FIX (fable/fpv-auth-hardening): the client sends _args select 1 as its sideJoined.
//--- We read the drone object first (args select 2 is a real server-side object reference
//--- passed via PVF, so it is trustworthy) and derive the owning side from the drone's
//--- group on the server.  The client-supplied side arg is cross-checked and overwritten.
//--- Residual trust: the drone handle itself is received from the client over PVF. A
//--- malicious client CANNOT forge a different player's drone reference because PVF
//--- object references are validated by the engine against the server-side object table.
//--- (Residual: engine object-reference validation is the last trust anchor.)
_drone = (_args select 2);
_driver = driver _drone;
_playerTeam = (_args select 3);
_timeStart = time;
//--- Derive side from the server-side drone group; fall back to client-supplied only if nil.
private ["_clientSide","_serverSide"];
_clientSide = _args select 1;
_serverSide = side (group _drone);
if (isNil "_serverSide" || {_serverSide == sideUnknown}) then {
	["WARNING", Format ["Support_FPV.sqf: could not derive side from drone group (got %1); falling back to client-supplied %2.", str _serverSide, str _clientSide]] Call WFBE_CO_FNC_LogContent;
	_side = _clientSide;
} else {
	if (!(_serverSide == _clientSide)) then {
		["WARNING", Format ["Support_FPV.sqf: client-supplied side [%1] != server-derived side [%2] - using server-derived.", str _clientSide, str _serverSide]] Call WFBE_CO_FNC_LogContent;
	};
	_side = _serverSide;
};
//--- Watchdog only: the owning client scuttles at battery TTL; this catches disconnects.
_timeout = (missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240]) + 120;

["INFORMATION", Format ["Support_FPV.sqf: [%1] Team [%2] [%3] launched an FPV strike drone.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;
//--- SECURITY (fable/fpv-strike-drone): stamp armed-drone ownership token so Support_FPV_Detonate
//--- can verify the requestor has a real drone in the air (one-shot; cleared on watchdog exit).
missionNamespace setVariable [Format ["wfbe_fpv_det_%1", str _side], _drone];

while {true} do {
	sleep 5;
	if (!(isPlayer (leader _playerTeam)) || !alive _drone || ((time - _timeStart) > _timeout)) exitWith {};
};

//--- SECURITY: clear the ownership token so no stale detonation can fire after the drone is gone.
missionNamespace setVariable [Format ["wfbe_fpv_det_%1", str _side], objNull];
if (!isNull _driver) then {if (alive _driver) then {_driver setDammage 1};if (isNil {_driver getVariable "wfbe_trashed"}) then {_driver setVariable ["wfbe_trashed", true];_driver Spawn TrashObject}};
if (!isNull _drone) then {if (alive _drone) then {_drone setDammage 1};if (isNil {_drone getVariable "wfbe_trashed"}) then {_drone setVariable ["wfbe_trashed", true];_drone Spawn TrashObject}};
