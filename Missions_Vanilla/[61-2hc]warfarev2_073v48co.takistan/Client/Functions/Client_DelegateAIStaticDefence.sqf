/*
	Create a delegation request.
	 Parameters:
		- Side
		- Groups
		- Spawn positions
		- Teams
		- defence
		- Move In Gunner immidietly or not
*/

Private ["_groups", "_positions", "_side", "_teams", "_town_vehicles"];

_side = _this select 0;
_groups = _this select 1;
_positions = _this select 2;
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;

["INFORMATION", Format["Client_DelegateAIStaticDefence.sqf: Received a delegation request from the server for [%1].", _side]] Call WFBE_CO_FNC_LogContent;

sleep (random 1); //--- Delay a bit to prevent a bandwidth congestion.

//--- GROUP BLOAT REDUCTION: do NOT pre-create a group here.  _team is the server-side
//--- per-town group (non-local on this HC).  Common_CreateUnitForStaticDefence will
//--- bridge to (or create) a per-town HC-local group keyed on _team.  Pre-creating a
//--- group here caused a leaked empty group per delegation call (old behaviour).

_retVal = [_side, _groups, _positions, _team, _defence, _moveInGunner] call WFBE_CO_FNC_CreateUnitForStaticDefence;
_teams = _retVal select 0;

//--- Defender classification: HC-created static-defence gunners. PUBLIC tag - the
//--- activation scan that must ignore these runs on the server, not on this machine.
{
	{if (!isNull _x) then {_x setVariable ["WFBE_IsTownDefenderAI", true, true]}} forEach (units _x);
} forEach _teams;

//["RequestSpecial", ["update-delegation-static_defence", _teams]] Call WFBE_CO_FNC_SendToServer;

//--- HC-local per-town groups: only delete when the shared group drains to zero.
//--- Duplicate entries in _teams are expected (same group repeated per gunner in the
//--- batch); collect unique groups before starting the watcher to avoid multiple
//--- concurrent watchers racing to deleteGroup on the same object.
Private ["_watchedGrps", "_grp"];
_watchedGrps = [];
{
	_grp = _x;
	if (!(isNull _grp) && {!(_grp in _watchedGrps)}) then {
		[_watchedGrps, _grp] call WFBE_CO_FNC_ArrayPush;
	};
} forEach _teams;
//--- wiki-wins: cap the watcher; WFBE_C_StaticDefCorpseDrain=1 enables fast-drain with player/locality guards.
{
	_x Spawn {
		Private ["_team", "_corpseMode", "_u", "_prox"];
		_team = _this;
		_corpseMode = missionNamespace getVariable ["WFBE_C_StaticDefCorpseDrain", 0];
		private "_wDeadline"; _wDeadline = time + 600;
		if (_corpseMode > 0) then {
			_prox = missionNamespace getVariable ["WFBE_C_UNITS_BODIES_PROX", 30];
			while {({alive _x} count (units _team)) > 0 && time < _wDeadline} do {sleep 1};
			{
				_u = _x;
				if (!(isPlayer _u) && {!(alive _u)} && {!(isNull _u)} && {local _u} && {(({isPlayer _x && {alive _x} && {(_x distance _u) < _prox}} count allPlayers)) == 0}) then {deleteVehicle _u};
			} forEach (units _team);
		} else {
			while {count (units _team) > 0 && time < _wDeadline} do {sleep 1};
		};
		deleteGroup _team;
	};
} forEach _watchedGrps;
