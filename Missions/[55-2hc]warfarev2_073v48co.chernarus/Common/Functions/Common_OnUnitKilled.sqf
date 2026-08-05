/*
	Triggerd upon a unit death.
	 Parameters:
		- Killed
		- Killer
*/

Private ["_killed","_killer","_killed_id","_killed_type_captured"];

_killed = _this select 0;
_killer = _this select 1;
_killed_id = _this select 2;

//--- fix(killmoney): capture the classname SYNCHRONOUSLY here, before the SendToServer
//--- publicVariable round-trip (real network/scheduler delay from a remote client/HC).
//--- The corpse/wreck can be GC-deleted (objNull) during that delay; RequestOnUnitKilled.sqf
//--- falls back to this pre-captured value so a since-nulled _killed does not zero out the
//--- whole reward gate (score AND bounty, both paths) for an otherwise-legitimate kill.
_killed_type_captured = typeOf _killed;

["RequestOnUnitKilled", [_killed, _killer, _killed_id, _killed_type_captured]] Call WFBE_CO_FNC_SendToServer;