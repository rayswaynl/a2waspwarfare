Private["_args","_driver","_drone","_playerTeam","_side","_timeStart","_timeout"];

_args = _this;
_side = _args select 1;

_drone = (_args select 2);
_driver = driver _drone;
_playerTeam = (_args select 3);
_timeStart = time;
//--- Watchdog only: the owning client scuttles at battery TTL; this catches disconnects.
_timeout = (missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240]) + 120;

["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] launched an FPV strike drone.", str _side, _playerTeam, name (leader _playerTeam)]] Call WFBE_CO_FNC_LogContent;
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
