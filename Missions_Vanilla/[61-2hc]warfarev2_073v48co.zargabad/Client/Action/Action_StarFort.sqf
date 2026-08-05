/*
	Action_StarFort.sqf - WEST/EAST COMMANDER "Star Fortress" WF-scroll addAction handler
	(kimi/starfort-mvp, flag WFBE_C_STARFORT_ENABLE default 0). Added to the player's own Man body by
	Client_OnRespawnHandler.sqf; the addAction's own condition string re-checks the master flag, the
	side, and commander status (commanderTeam == group player) every frame, so with the flag at 0 no
	action is ever shown (byte-identical to HEAD).

	Flow on a single scroll-wheel click (SAME shape as Action_GuerHeliBombCall.sqf):
	  - commander gate + barracks unlock check (UX copy - the server re-validates everything);
	  - one-shot map designation via vanilla onMapSingleClick: open the map, the next map click is
	    the keep position. The fort's gate face points TOWARD the commander's position at click time
	    (the fort opens toward its own lines);
	  - on a click: clear the handler, close the map, send the RequestStarFort PV. The server
	    (Server\PVFunctions\RequestStarFort.sqf) runs the 6-gate validator and answers with a targeted
	    accept/reject chat message - this script charges nothing and decides nothing.

	A2 OA 1.64 safe: array-form private only, `_arr + [x]` (no pushBack), no params/isEqualType,
	titleText. The onMapSingleClick code is a STRING (A2 onMapSingleClick passes
	[_units,_pos,_alt,_shift] -> the clicked pos is `_this select 1` inside that string).

	_this = [target(player), caller(player), actionId, args] - target == caller, this is a Man-body action.
*/
Private ["_player","_upg","_lvl","_req","_key","_existing"];
_player = _this select 1;

if (isNull _player || {!alive _player}) exitWith {};
if !(sideJoined in [west, east]) exitWith {};                       //--- belt-and-braces vs the action condition.
if (isNull commanderTeam || {commanderTeam != group _player}) exitWith {
	titleText ["Star Fortress: commander only.", "PLAIN"];
};

//--- Barracks unlock (UX copy of the server-side gate; reuses the RequestDefense _barrackLvl idiom).
_upg = (sideJoined) Call WFBE_CO_FNC_GetSideUpgrades;
_lvl = 0;
if (count _upg > WFBE_UP_BARRACKS) then {_lvl = _upg select WFBE_UP_BARRACKS};
_req = missionNamespace getVariable ["WFBE_C_STARFORT_UNLOCK_BARRACKS_LVL", 3];
if (_lvl < _req) exitWith {
	titleText [Format ["Star Fortress requires Barracks level %1 (current %2).", _req, _lvl], "PLAIN"];
};

//--- Already-standing UX copy (the server registry check remains authoritative).
_key = if (sideJoined == west) then {"WFBE_STARFORT_WEST"} else {"WFBE_STARFORT_EAST"};
_existing = missionNamespace getVariable [_key, objNull];
if (!isNull _existing && {alive _existing}) exitWith {
	titleText ["Your side's Star Fortress already stands.", "PLAIN"];
};

//--- Re-select guard: do not stack a second onMapSingleClick while one is pending.
if (_player getVariable ["wfbe_starfort_designating", false]) exitWith {
	titleText ["Designating - click the map for the keep position.", "PLAIN"];
};
_player setVariable ["wfbe_starfort_designating", true];

//--- Stash the caller for the onMapSingleClick string to read (it runs in a different scope).
WFBE_StarFortDesignator = _player;

titleText ["Click the map to place the STAR FORTRESS keep (the gate faces your position).", "PLAIN"];
openMap true;

//--- One-shot map designation. Inside the string the clicked world position is `_this select 1`.
//--- Gate facing = bearing from the clicked point back to the commander (the fort opens home).
onMapSingleClick "
	private ['_pos','_p','_pp','_d'];
	_pos = _this select 1;
	_p = WFBE_StarFortDesignator;
	onMapSingleClick '';
	openMap false;
	if (isNull _p || {!alive _p}) exitWith {
		if (!isNull _p) then {_p setVariable ['wfbe_starfort_designating', false]};
	};
	_p setVariable ['wfbe_starfort_designating', false];
	_pp = getPos _p;
	_d = ((_pp select 0) - (_pos select 0)) atan2 ((_pp select 1) - (_pos select 1));
	if (_d < 0) then {_d = _d + 360};
	['RequestStarFort', [sideJoined, _pos, _d, _p]] Call WFBE_CO_FNC_SendToServer;
	titleText ['Star Fortress requested - the server is validating the site.', 'PLAIN'];
";
