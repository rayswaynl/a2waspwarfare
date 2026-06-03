//============================================================================
//  [CLAUDE x CODEX COLLAB - DRAFT, NOT FINISHED]   Bazaar Intel Network
//  ---------------------------------------------------------------------------
//  COLLABORATIVE feature #2 (target 50-200 LOC). Built TOGETHER with Codex.
//  Claude's CONCRETE PROPOSAL for Codex to review/edit. Default OFF, NOT wired,
//  and NOT "done" until BOTH agents agree + flip it on.
//
//  Concept: a handful of "radio masts" around the bazaar/city are held by
//  whoever stands on them uncontested. The holding side gains INTEL: enemy units
//  near the mast are revealed to that side's forces (AI awareness boost), so the
//  city becomes a fought-over surveillance asset.
//
//  OPEN DESIGN QUESTIONS for Codex (let's converge before enabling):
//    1. Human-player intel: show revealed enemies as temporary per-side MAP MARKERS?
//       (markers are global in A2, so true per-side intel needs a little client
//        code / publicVariable to the holder's clients. This draft does the
//        server-side AI `reveal` only; the human-marker layer is the open part.)
//    2. Mast positions (3 proposed below, around the bazaar/city) - confirm/adjust.
//    3. Reveal radius + cadence + strength. Should it stack with the Power Grid hold?
//  Toggle (when finished): WFBE_C_CLAUDE_INTELNET_ENABLED (default 0 for now).
//  Arma 2 OA SQF only. ~80 LOC.
//============================================================================
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLAUDE_INTELNET_ENABLED", 0]) <= 0) exitWith {};  //--- OFF until co-finished

waitUntil {!isNil "serverInitComplete" && {serverInitComplete}};

#define IN_HOLD   80     //--- capture radius (m)
#define IN_SCAN   650    //--- intel scan radius around a held mast (m)
#define IN_TICK   45     //--- seconds per sweep

WFBE_CLAUDE_IN_MASTS = [[4300,4400,0],[3760,3650,0],[4880,4060,0]];   //--- PROPOSAL near the bazaar/city
WFBE_CLAUDE_IN_MK    = [];

{
	private "_mk";
	_mk = createMarker [format ["WFBE_Claude_IN_%1", _forEachIndex], _x];
	_mk setMarkerType "mil_circle"; _mk setMarkerColor "ColorBlack"; _mk setMarkerText "Radio Mast";
	WFBE_CLAUDE_IN_MK set [_forEachIndex, _mk];
} forEach WFBE_CLAUDE_IN_MASTS;

["INITIALIZATION", "Claude_Collab_BazaarIntel.sqf: Bazaar Intel Network active (3 masts)."] call WFBE_CO_FNC_LogContent;

while {true} do {
	{
		private ["_i","_near","_wN","_eN","_holder","_holderSide","_enemySide","_scan"];
		_i = _forEachIndex;
		_near = nearestObjects [_x, ["Man","Car","Tank"], IN_HOLD];
		_wN = 0; _eN = 0;
		{ if (alive _x) then { if (side _x == west) then {_wN = _wN + 1}; if (side _x == east) then {_eN = _eN + 1} } } forEach _near;
		_holder = -1;
		if (_wN > 0 && _eN == 0) then {_holder = 0};
		if (_eN > 0 && _wN == 0) then {_holder = 1};
		(WFBE_CLAUDE_IN_MK select _i) setMarkerColor (switch (_holder) do { case 0: {"ColorBlue"}; case 1: {"ColorRed"}; default {"ColorBlack"} });

		//--- the holder's nearby forces get a read on enemies around the mast
		if (_holder != -1) then {
			_holderSide = if (_holder == 0) then {west} else {east};
			_enemySide  = if (_holder == 0) then {east} else {west};
			_scan = nearestObjects [_x, ["Man","Car","Tank"], IN_SCAN];
			{
				private "_e"; _e = _x;
				if (alive _e && {side _e == _enemySide}) then {
					{ if (side _x == _holderSide && {alive _x}) then { _x reveal [_e, 4] } } forEach _scan;
				};
			} forEach _scan;
		};
	} forEach WFBE_CLAUDE_IN_MASTS;
	sleep IN_TICK;
};
