/*
	Triggerd upon a unit death.
	 Parameters:
		- Killed
		- Killer
*/

Private ["_killed","_killer","_killed_id"];

_killed = _this select 0;
_killer = _this select 1;
_killed_id = _this select 2;


["RequestOnUnitKilled", [_killed, _killer, _killed_id]] Call WFBE_CO_FNC_SendToServer;