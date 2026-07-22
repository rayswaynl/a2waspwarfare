/*
	Destructively retire one local AI commander team after a validated commander disband
	(owner ruling 2026-07-22 20:06: disband = DESTRUCTION - vehicles explode, infantry
	grenade-drop; proximity/combat vetoes removed). The server owns validation and routes
	explicit requests to the leader owner; this function owns only local destruction.
	Deaths are ordinary combat deaths: corpses and wrecks flow through the STANDARD
	wreck/corpse cleanup - no pop-out removals for observed units.
	Config proof: CfgAmmo "GrenadeHandTimedWest" (: GrenadeHand), explosionTime=4, model
	M67 - a TIMED fuse, so it detonates reliably when spawned stationary at a unit's feet
	(base "GrenadeHand" is impact-fused with fuseDistance=5 and can fail to arm at rest).
*/

Private ["_team","_leader","_units","_vehicles","_vehicle","_sideID","_cmd","_uCount","_vCount"];

if (count _this < 1) exitWith {false};
_team = _this select 0;
if (isNull _team) exitWith {false};
_leader = leader _team;
if (isNull _leader || {!local _leader}) exitWith {false};

_sideID = (side _team) Call WFBE_CO_FNC_GetSideID;
_cmd = _team getVariable "wfbe_aicom_disband_cmd";
if (isNil "_cmd") then {_cmd = false};
_units = +(units _team);
_vehicles = [];
{
	if (!isNull _x) then {
		_vehicle = vehicle _x;
		if (_vehicle != _x && {!(_vehicle in _vehicles)}) then {_vehicles = _vehicles + [_vehicle]};
	};
} forEach _units;

//--- Vehicles first: cook the hull (mounted crew dies with it); never touch a player-crewed hull.
_vCount = 0;
{
	if (!isNull _x && {local _x} && {alive _x} && {({isPlayer _x} count (crew _x)) == 0}) then {
		_x setDamage 1;
		_vCount = _vCount + 1;
	};
} forEach _vehicles;

//--- Dismounted infantry: each drops a live timed grenade at its own feet and dies to
//--- ordinary explosive damage a few seconds later (explosionTime 4).
_uCount = 0;
{
	if (!isNull _x && {local _x} && {!isPlayer _x} && {alive _x} && {(vehicle _x) == _x}) then {
		"GrenadeHandTimedWest" createVehicle (getPos _x);
		_uCount = _uCount + 1;
	};
} forEach _units;

diag_log ("DISBAND|v1|exec|mode=destructive|side=" + str _sideID + "|team=" + str _team + "|inf=" + str _uCount + "|hulls=" + str _vCount + "|cmd=" + str _cmd + "|t=" + str (round (time / 60)));
diag_log ("AICOMSTAT|v1|EVENT|" + str _sideID + "|" + str (round (time / 60)) + "|TEAM_RETIRE_LOCAL|destructive");
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};
//--- No immediate deleteGroup: grenade fuses land the deaths ~4s out; the group empties as its
//--- members die and the standard empty-group GC reaps it (aicom-team-ended has already
//--- deregistered it from wfbe_teams).
true
