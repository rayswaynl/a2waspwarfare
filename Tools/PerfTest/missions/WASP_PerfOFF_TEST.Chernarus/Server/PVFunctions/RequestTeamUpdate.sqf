Private["_args","_properties","_team"];

_args = _this;
_team = _args select 0;

//--- One team.
if (typeName _team == "ARRAY") then {
	{
		_x setBehaviour (_args select 1);
		_x setCombatMode (_args select 2);
		_x setFormation (_args select 3);
		_x setSpeedMode (_args select 4);
		["INFORMATION", Format ["RequestTeamUpdate.sqf: Team [%1] properties were updated.", _x]] Call WFBE_CO_FNC_LogContent;
	} forEach _team;
};

//--- The whole team.
//--- DR-55 forged-PVF hardening (flag-gated; OFF = byte-equivalent legacy behavior).
//--- The bare-SIDE form rewrites EVERY team on the named side (behaviour/combat/formation/
//--- speed). The PVEH carries no trusted sender, so a forger can pass the ENEMY side and set
//--- all its AI to CARELESS/hold-fire. No in-tree caller uses this branch, so rejecting it
//--- when ON removes the mass-sabotage vector without touching any honest path.
if ((typeName _team == "SIDE") && {(missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0}) exitWith {
	["WARNING", Format ["RequestTeamUpdate.sqf: rejected forged whole-side team update for side [%1].", _team]] Call WFBE_CO_FNC_LogContent;
};

if (typeName _team == "SIDE") then {
	{
		_x setBehaviour (_args select 1);
		_x setCombatMode (_args select 2);
		_x setFormation (_args select 3);
		_x setSpeedMode (_args select 4);
	} forEach (missionNamespace getVariable Format["WFBE_%1TEAMS",str _team]);
	["INFORMATION", Format ["RequestTeamUpdate.sqf: [%1] Teams properties were updated.", _team]] Call WFBE_CO_FNC_LogContent;
};