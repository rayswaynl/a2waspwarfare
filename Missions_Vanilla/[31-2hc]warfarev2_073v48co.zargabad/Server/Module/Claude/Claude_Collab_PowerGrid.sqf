//============================================================================
//  [CLAUDE x CODEX COLLAB - DRAFT, NOT FINISHED]   Zargabad Power Grid
//  ---------------------------------------------------------------------------
//  COLLABORATIVE feature (target 50-200 LOC). Built TOGETHER with Codex.
//  This is Claude's CONCRETE PROPOSAL (working code) for Codex to review/edit -
//  it is still default OFF and NOT wired into Claude_Features_Init, and is NOT
//  "done" until BOTH agents agree + flip it on.
//
//  Concept: 3 power stations around Zargabad are held by whoever stands on them
//  uncontested. The side holding the MAJORITY draws a steady power dividend
//  (funds trickle to its commander). Station owner shown by marker colour.
//
//  PROPOSAL (Codex - edit any of these, then tell me you agree):
//    - positions: refinery-south / city-centre / airfield-west (below)
//    - capture: "uncontested presence within 70 m flips it" (simple KOTH hold)
//    - buff: PG_PAYOUT funds/min to the majority holder (alt ideas welcome:
//            respawn-time cut, build discount, supply trickle)
//    - brownout penalty for holding zero stations? (not implemented - your call)
//  Toggle (when finished): WFBE_C_CLAUDE_POWERGRID_ENABLED (default 0 for now).
//  Arma 2 OA SQF only. ~75 LOC.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_POWERGRID_ENABLED", 0]) <= 0) exitWith {};  //--- OFF until co-finished

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};

#define PG_RADIUS 70
#define PG_TICK   60
#define PG_PAYOUT 500   //--- funds/min to the majority holder (PROPOSAL - tune with Codex)

WFBE_CLAUDE_PG_STATIONS = [[3800,2750,0],[4096,4180,0],[2200,4200,0]];
WFBE_CLAUDE_PG_NAMES    = ["Refinery Substation","City Power Plant","Airfield Substation"];
WFBE_CLAUDE_PG_OWNER    = [];
WFBE_CLAUDE_PG_MK       = [];

//--- place one map marker per station; owner starts neutral (-1)
{
	private "_mk";
	WFBE_CLAUDE_PG_OWNER set [_forEachIndex, -1];
	_mk = createMarker [format ["WFBE_Claude_PG_%1", _forEachIndex], _x];
	_mk setMarkerType "mil_objective"; _mk setMarkerColor "ColorBlack";
	_mk setMarkerText (WFBE_CLAUDE_PG_NAMES select _forEachIndex);
	WFBE_CLAUDE_PG_MK set [_forEachIndex, _mk];
} forEach WFBE_CLAUDE_PG_STATIONS;

["INITIALIZATION", "Claude_Collab_PowerGrid.sqf: Power Grid active (3 stations)."] call WFBE_CO_FNC_LogContent;

while {true} do {
	private ["_wHold","_eHold"];
	_wHold = 0; _eHold = 0;
	{
		private ["_i","_units","_wN","_eN","_owner"];
		_i = _forEachIndex;
		_units = nearestObjects [_x, ["Man","Car","Tank"], PG_RADIUS];
		_wN = 0; _eN = 0;
		{ if (alive _x) then {
			if (side _x == west) then {_wN = _wN + 1};
			if (side _x == east) then {_eN = _eN + 1};
		} } forEach _units;
		_owner = WFBE_CLAUDE_PG_OWNER select _i;
		if (_wN > 0 && _eN == 0) then { _owner = 0 };   //--- uncontested WEST presence flips it
		if (_eN > 0 && _wN == 0) then { _owner = 1 };   //--- uncontested EAST presence flips it
		WFBE_CLAUDE_PG_OWNER set [_i, _owner];
		(WFBE_CLAUDE_PG_MK select _i) setMarkerColor (switch (_owner) do { case 0: {"ColorBlue"}; case 1: {"ColorRed"}; default {"ColorBlack"} });
		if (_owner == 0) then {_wHold = _wHold + 1};
		if (_owner == 1) then {_eHold = _eHold + 1};
	} forEach WFBE_CLAUDE_PG_STATIONS;

	//--- majority holder draws the power dividend
	if (_wHold > _eHold && {_wHold > 0}) then { [west, PG_PAYOUT] call WFBE_CLAUDE_FNC_GiveFunds };
	if (_eHold > _wHold && {_eHold > 0}) then { [east, PG_PAYOUT] call WFBE_CLAUDE_FNC_GiveFunds };

	sleep PG_TICK;
};
