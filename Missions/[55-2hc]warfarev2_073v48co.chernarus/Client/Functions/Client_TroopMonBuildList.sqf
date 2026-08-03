/*
	Client_TroopMonBuildList.sqf

	Cached-array builder for the commander TROOP MONITOR (GUI_Menu_TroopMon.sqf, RscMenu_TroopMon).
	Read-only client function: it never requests or publishes anything, it only reads already-
	replicated own-side team state - the SAME clientTeams / WFBE_Client_Logic "wfbe_teams" resolve
	the war-room roster already uses in GUI_Menu_Command.sqf - and the SAME squad-type classifier
	those rows already use (heaviest-hull priority: AIR > HVY > LGHT > INF).

	CACHED-ARRAY PATTERN (per the card's scope note): the full own-side scan below walks every own-
	side team's units, which is too expensive to redo on every dialog open or every filter change.
	It runs at most once per WFBE_C_COMMANDER_TROOPMON_REFRESH seconds; any call inside that window
	returns the SAME cached array untouched. Callers that need to bypass the cache (the dialog's
	REFRESH button) pass [true].

	Unlike the war-room roster (AI-led teams only), TroopMon lists EVERY own-side group - AI-led AND
	player-led - so the commander can see the whole force, not just the teams they can order. Own-
	side only; never enumerates another side's groups (own-side intel gate, same doctrine as the
	Towns/Garrison tab).

	Call:    _rows = [_forceRefresh] call WFBE_CL_FNC_TroopMonBuildList;
	Returns: ARRAY of rows, each [group, typeTag(STRING), leaderName(STRING), aliveCount, totalCount,
	         orderVerb(STRING), playerLed(BOOL)].
*/

private ["_force","_now","_refresh","_srcTeams","_rows"];

_force = false;
if (count _this > 0) then {_force = _this select 0};
_now = time;
_refresh = missionNamespace getVariable ["WFBE_C_COMMANDER_TROOPMON_REFRESH", 2];

if (!_force && {!isNil "WFBE_TroopMon_CacheTime"} && {!isNil "WFBE_TroopMon_CacheRows"} && {(_now - WFBE_TroopMon_CacheTime) < _refresh}) exitWith {
	WFBE_TroopMon_CacheRows
};

//--- Live own-side team registry - identical resolve to the war-room roster (GUI_Menu_Command.sqf):
//--- clientTeams is the frozen boot snapshot of playable slot-groups; the runtime AI squads are only
//--- appended to the side-logic wfbe_teams (broadcast). Prefer the live array, fall back on a fresh
//--- JIP client where the logic/var is not yet replicated.
_srcTeams = clientTeams;
if (!isNil "WFBE_Client_Logic" && {!isNull WFBE_Client_Logic}) then {
	private "_lt"; _lt = WFBE_Client_Logic getVariable "wfbe_teams";
	if (!isNil "_lt" && {(typeName _lt) == "ARRAY"}) then {_srcTeams = _lt};
};

_rows = [];
{
	private "_grp"; _grp = _x;                                    //--- capture into a named local before the inner forEach rebinds _x (A2-OA trap).
	if (!isNull _grp && {({alive _x} count units _grp) > 0}) then {
		private ["_typeTag","_playerLed","_leaderName","_alive","_total","_verb","_hg","_rg","_sg","_mg","_mgL"];
		_playerLed = isPlayer (leader _grp);

		//--- SQUAD TYPE: same heaviest-hull classifier as the war-room roster / map team markers
		//--- (updateaicommarkers.sqf) - priority AIR > HVY > LGHT > INF.
		_typeTag = "INF";
		{
			if (!isNull _x && {alive _x}) then {
				private "_veh"; _veh = vehicle _x;
				if (_veh != _x) then {
					if (_veh isKindOf "Air") exitWith {_typeTag = "AIR"};
					if (_veh isKindOf "Tank") then {if (_typeTag != "AIR") then {_typeTag = "HVY"}};
					if ((_veh isKindOf "Wheeled_APC") || {_veh isKindOf "Car"}) then {if (_typeTag == "INF") then {_typeTag = "LGHT"}};
				};
			};
		} forEach units _grp;

		_leaderName = name (leader _grp);
		_alive = {alive _x} count units _grp;
		_total = count units _grp;

		//--- ORDER VERB: same holding/rallying/strike/teammode priority the war-room roster row already
		//--- reads (1-arg getVariable + isNil - the GROUP-receiver-safe form, never the 2-arg A3 trap); a
		//--- player-led squad has no AICOM order state, so it is tagged "player" instead.
		_verb = "auto";
		if (_playerLed) then {
			_verb = "player";
		} else {
			_hg = _grp getVariable "wfbe_aicom_holding_town";
			_rg = _grp getVariable "wfbe_aicom_rallying";
			_sg = _grp getVariable "wfbe_aicom_strike";
			_mg = _grp getVariable "wfbe_teammode";
			if (!isNil "_mg" && {typeName _mg == "STRING"}) then {
				_mgL = toLower _mg;
				if (_mgL == "move" || _mgL == "patrol" || _mgL == "defense") then {_verb = _mgL};
			};
			if (!isNil "_sg" && {_sg}) then {_verb = "strike"};
			if (!isNil "_rg" && {_rg}) then {_verb = "rally"};
			if (!isNil "_hg" && {!isNull _hg}) then {_verb = "hold"};
		};

		_rows set [count _rows, [_grp, _typeTag, _leaderName, _alive, _total, _verb, _playerLed]];
	};
} forEach _srcTeams;

WFBE_TroopMon_CacheRows = _rows;
WFBE_TroopMon_CacheTime = _now;
WFBE_TroopMon_CacheRows
