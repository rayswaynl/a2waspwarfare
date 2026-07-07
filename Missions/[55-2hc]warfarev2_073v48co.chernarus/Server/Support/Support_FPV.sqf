Private["_args","_driver","_drone","_playerTeam","_side","_tier","_timeStart","_timeout"];

_args = _this;
_side = _args select 1;

_drone = (_args select 2);
_driver = driver _drone;
_playerTeam = (_args select 3);
//--- Warhead tier: whitelist-validated here and bound to the hull SERVER-side; the detonate
//--- handler (Support_FPV_Detonate.sqf) reads it off the matched ownership-token drone, so the
//--- client can neither escalate the paid tier per-shot nor inject an ammo classname.
_tier = "standard";
if ((count _args) > 4) then {
	private ["_tRaw"];
	_tRaw = _args select 4;
	if ((typeName _tRaw) == "STRING") then {
		if (_tRaw in ["light","standard","heavy"]) then {_tier = _tRaw};
	};
};
_drone setVariable ["wfbe_fpv_tier", _tier];
_timeStart = time;
//--- Watchdog only: the owning client scuttles at battery TTL; this catches disconnects.
_timeout = (missionNamespace getVariable ["WFBE_C_FPV_DRONE_TTL", 240]) + 120;

["INFORMATION", Format ["Server_HandleSpecial.sqf: [%1] Team [%2] [%3] launched an FPV strike drone (tier %4).", str _side, _playerTeam, name (leader _playerTeam), _tier]] Call WFBE_CO_FNC_LogContent;
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
