private ["_playerCount", "_logMatchWinPlayerCountThreshold", "_hcCount"];

_logMatchWinPlayerCountThreshold = _this select 0;

sleep 120;

_playerCount = 0;

{
	if (isPlayer _x) then {
		_playerCount = _playerCount + 1;
	}
} forEach allUnits;

//--- Exclude connected headless clients (this mission runs multiple HCs, and an HC is isPlayer
//--- regardless of side). Subtract the live HC count from the registry, floored at 0, so an empty
//--- server never trips the match-win threshold. Mirrors GlobalGameStats.sqf.
_hcCount = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
_playerCount = (_playerCount - _hcCount) max 0;

if (_playerCount >= _logMatchWinPlayerCountThreshold) then {
	WFBE_Server_LogMatchWin = true;
}