Private["_args","_properties","_team","_secHardening","_requester","_validProps","_teamOwned"];

_args = _this;
_team = _args select 0;

//--- One team.
if (typeName _team == "ARRAY") then {
	//--- item #harden-teamupdate hardening (flag-gated; OFF = byte-equivalent legacy behavior).
	//--- The array-of-groups form applied setBehaviour/setCombatMode/setFormation/setSpeedMode to
	//--- EVERY group named in the client-supplied array with ZERO ownership checks. The PVEH carries
	//--- no trusted sender, so a forged payload naming ENEMY groups could set them to CARELESS +
	//--- hold-fire + LIMITED speed -- a full AI combat-disable vector, same class as the DR-55
	//--- whole-side guard below. Trace: the legit caller is the commander team-menu "set team
	//--- properties" action (GUI_Menu_Command.sqf), which only ever builds its team array from the
	//--- requester's own-side team registry (clientTeams), including AI-led squads the requester
	//--- doesn't personally lead but commands as side commander -- so we bind to same-SIDE, not
	//--- same-leader. Requester is appended as a NEW 6th arg; legacy 5-arg callers keep working
	//--- byte-identical with the flag OFF (requester defaults to objNull, which only matters when
	//--- the flag is armed).
	_secHardening = (missionNamespace getVariable ["WFBE_C_SEC_HARDENING", 0]) > 0;
	if (_secHardening) then {
		_requester = objNull;
		if (count _args > 5) then {_requester = _args select 5};
		_validProps = ((_args select 1) in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"])
			&& {(_args select 2) in ["BLUE","GREEN","WHITE","YELLOW","RED"]}
			&& {(_args select 3) in ["COLUMN","STAG COLUMN","WEDGE","ECH LEFT","ECH RIGHT","VEE","LINE","FILE","DIAMOND","NO CHANGE"]}
			&& {(_args select 4) in ["LIMITED","NORMAL","FULL"]};
		if (isNull _requester || {!isPlayer _requester} || {!alive _requester} || {!_validProps}) exitWith {
			["WARNING", Format ["RequestTeamUpdate.sqf: rejected array team update, invalid requester or property value(s) from [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
		};
		_teamOwned = true;
		{
			if (typeName _x != "GROUP" || {isNull _x} || {side _x != side _requester}) exitWith {
				_teamOwned = false;
			};
		} forEach _team;
		if (!_teamOwned) exitWith {
			["WARNING", Format ["RequestTeamUpdate.sqf: rejected array team update, group(s) not on requester [%1]'s side.", _requester]] Call WFBE_CO_FNC_LogContent;
		};
	};
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
