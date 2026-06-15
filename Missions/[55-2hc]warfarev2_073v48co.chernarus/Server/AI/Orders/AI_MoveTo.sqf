Private ["_destination","_formations","_mission","_radius","_team","_update","_aicomHc","_aicomFnd"];
_team = _this select 0;
_destination = _this select 1;
_mission = _this select 2;
_radius = if (count _this > 3) then {_this select 3} else {30};
_team setCombatMode "RED";          //--- STANCE (task #1): advance-and-engage (was YELLOW).
_team setBehaviour "AWARE";
_team setFormation "COLUMN";
_team setSpeedMode "FULL";           //--- STANCE (task #1): full march speed (was NORMAL).

_update = true;
if (side _team == west || side _team == east) then {
	_update = (_team) Call CanUpdateTeam;
};

//--- STANCE (task #1): UpdateTeam re-stamps AWARE/NORMAL/YELLOW + a RANDOM formation, which would
//--- overwrite the aggressive RED/FULL/COLUMN set above. AI-commander-founded teams keep their
//--- posture by skipping the shared UpdateTeam; all other (town/patrol) teams are unaffected.
//--- A2 OA G1 fix: the 2-arg group getVariable returns nil (NOT the default) when the var is UNSET.
//--- For non-AICOM groups (paradrop / para-ammo / para-vehicle / town / patrol) wfbe_aicom_hc/founded
//--- are unset, so `[name,false]` returned nil and `nil || {nil}` threw "Type Nothing" — aborting
//--- AI_MoveTo before AIWPAdd, so those moves got no waypoint. Read 1-arg + isNil (treat unset as false).
_aicomHc  = _team getVariable "wfbe_aicom_hc";
_aicomFnd = _team getVariable "wfbe_aicom_founded";
if ((!isNil "_aicomHc" && {_aicomHc}) || {!isNil "_aicomFnd" && {_aicomFnd}}) then {_update = false};

//--- Override.
if (_update) then {_team Call UpdateTeam};

["INFORMATION", Format ["AI_MoveTo.sqf: [%1] Team [%2] is heading to [%3].", side _team,_team,_destination]] Call WFBE_CO_FNC_LogContent;

[_team,true,[[_destination, _mission, _radius, 20, "", []]]] Call AIWPAdd;