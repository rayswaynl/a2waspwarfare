/* Server_Oilfields.sqf — OILFIELDS neutral capturable resource node (Ray 2026-07-01, Takistan).

   A capturable resource node that is NOT a town (no town FSM, no garrison spawning, no town-list
   registration). Server-authoritative, one lightweight loop. Design summary:

     (1) MAP-GATED to Takistan only. Gate is (toLower worldName == "takistan") so this whole file is
         inert on Chernarus (the code lives in the CH source and mirrors to TK via LoadoutManager).
         The mission-wide worldName idiom already used in Common\Init\Init_Boundaries.sqf.

     (2) UNLOCKS at the 1-hour ingame mark. Until time > WFBE_C_OILFIELD_UNLOCK_TIME (default 3600s)
         the node is DORMANT: no capture logic, no income, no marker. When the mark passes it:
           - creates the global map marker (WFBE_OILFIELD),
           - flips into the live capture/income loop,
           - ANNOUNCES the opening to every client's chat via the existing DashboardAnnounce PVF
             (systemChat) broadcast through WFBE_CO_FNC_SendToClients (nil = global). Same reach as
             every other server->all-clients broadcast in this mission.

     (3) INCOME while HELD. On each income tick the owning side (if any) is credited a small, capped
         supply amount via the existing side-income path: [_side, _amount, _reason, _includeStagnation]
         Call ChangeSideSupply — the SAME call town supply income uses in Server\FSM\updateresources.sqf.
         includeStagnation=true so it applies the no-players stagnation coefficient exactly like town
         income (never a synthetic windfall on an empty server). Neutral (unheld) node pays nobody.

     (4) CAPTURE = proximity + cleared-of-enemy. A side "holds" the node when it has >=1 alive unit
         (player OR AI) within WFBE_C_OILFIELD_RADIUS of the node AND the OTHER main side has none.
         Contested (both present) or empty (neither present) leaves ownership unchanged. On a real flip
         the marker recolours to the new owner and a capture line is announced to all clients.

     ~ZERO standing AI: no guards are spawned by this feature (0 units). The node is won purely by
     whoever brings units into the radius, so it never burns FPS or trips the no-sim-gating rules.

   ALL new tunables are read via missionNamespace getVariable [NAME, default] so the Constants owner
   can add authoritative definitions; the defaults below keep the feature fully working if they don't.

   A2-OA 1.64 ONLY. No A3 commands (no isEqualType/selectRandom/params/pushBack/remoteExec/
   allMapMarkers/getTerrainHeightASL). Classic A2-OA idioms only, verified against neighbouring code
   (Init_NavalHVT.sqf, server_town.sqf capture block, Construction_MediumSite.sqf bank marker).
*/

scriptName "Server\Server_Oilfields.sqf";

if (!isServer) exitWith {};

//--- (1) MAP GATE: Takistan only. Inert (and cheap) on every other world.
if (toLower worldName != "takistan") exitWith {
	["INFORMATION", Format ["Server_Oilfields.sqf: not Takistan (worldName=%1) - OILFIELDS feature is TK-only, skipping.", worldName]] Call WFBE_CO_FNC_LogContent;
};

//--- ENABLE gate (default ON). Lets the Constants owner dark-flip the whole feature without a code edit.
if ((missionNamespace getVariable ["WFBE_C_OILFIELD_ENABLE", 1]) != 1) exitWith {
	["INFORMATION", "Server_Oilfields.sqf: WFBE_C_OILFIELD_ENABLE=0 - OILFIELDS feature OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

//--- Wait for the world to be fully live (towns init done, game clock running) before we resolve a
//--- map anchor position. Mirrors the Init_NavalHVT.sqf gate.
waitUntil { sleep 1; !isNil "townInit" && townInit };
waitUntil { time > 0 };

//------------------------------------------------------------------------------------
//--- RESOLVE NODE POSITION.
//--- Preferred: anchor on a real Takistan oil/fuel map object via nearestObjects around a plausible
//--- industrial area, so the node sits on an in-world derrick/fuel installation. If none resolves
//--- (class list may not match this terrain's exact P3D names), fall back to the tunable constant
//--- WFBE_C_OILFIELD_POS placeholder — flagged in the agent report as needing a finalized coordinate.
//------------------------------------------------------------------------------------
private ["_posConst","_anchorSearch","_oilClasses","_found","_hit","_nodePos","_resolvedBy"];

//--- Tunable placeholder anchor (map [x,y,z]). Central-Takistan industrial-ish default; the search
//--- below tries to snap onto a real installation near here first. FINAL derrick coord to confirm.
_posConst = missionNamespace getVariable ["WFBE_C_OILFIELD_POS", [4600, 6200, 0]];

//--- Candidate oil/fuel installation classnames to snap onto (A2-OA base + TK/EP1 fuel props).
//--- We do NOT assume any one exists; nearestObjects simply returns [] for absent classes.
_oilClasses = [
	"Land_A_FuelStation_Feed",
	"Land_A_FuelStation_Build",
	"Land_Fuelstation",
	"Land_Fuelstation_army",
	"FuelStation",
	"Land_Ind_TankSmall",
	"Land_Ind_TankBig",
	"Land_Ind_Oil_Tower_EP1",
	"Land_Ind_IlluminantTower"
];

_found   = objNull;
_nodePos = _posConst;
_resolvedBy = "constant-placeholder";

//--- nearestObjects [pos, classnames, radius] is A2-OA 1.64-safe (used in Init_Server.sqf B62 filter).
//--- Search a generous radius around the placeholder anchor for any listed installation.
_anchorSearch = nearestObjects [_posConst, _oilClasses, (missionNamespace getVariable ["WFBE_C_OILFIELD_ANCHOR_SEARCH", 1200])];
if (count _anchorSearch > 0) then {
	_hit = _anchorSearch select 0;   //--- nearestObjects returns nearest-first
	if (!isNull _hit) then {
		_found = _hit;
		_nodePos = getPos _hit;
		_resolvedBy = Format ["map-object:%1", typeOf _hit];
	};
};

//--- Force a ground/2D-clean [x,y,0] node position (capture uses 2D distance below anyway).
_nodePos = [_nodePos select 0, _nodePos select 1, 0];
missionNamespace setVariable ["WFBE_OILFIELD_POS_LIVE", _nodePos, true];

diag_log Format ["OILFIELD|v1|INIT|pos=%1|resolvedBy=%2|unlockAt=%3", _nodePos, _resolvedBy, (missionNamespace getVariable ["WFBE_C_OILFIELD_UNLOCK_TIME", 3600])];
["INITIALIZATION", Format ["Server_Oilfields.sqf: OILFIELD node position resolved to %1 (via %2). Unlocks at t=%3s.", _nodePos, _resolvedBy, (missionNamespace getVariable ["WFBE_C_OILFIELD_UNLOCK_TIME", 3600])]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- SIDE-ABSOLUTE marker colour helper (server-created global marker must read the SAME on every
//--- client, so we do NOT use the client-relative WFBE_C_*_COLOR vars — those depend on `side group
//--- player` and are inverted on the dedicated server). Fixed absolute colours, mirroring the bank
//--- marker (ColorBlue WEST / ColorRed EAST) with a neutral yellow for the unheld node.
//------------------------------------------------------------------------------------
WFBE_FNC_OilfieldColor = {
	private ["_s"];
	_s = _this;
	switch (true) do {
		case (_s == west):  { "ColorBlue" };
		case (_s == east):  { "ColorRed" };
		case (_s == resistance): { "ColorGreen" };
		default { "ColorYellow" };   //--- neutral / unheld
	};
};

//------------------------------------------------------------------------------------
//--- (2) UNLOCK WAIT + ANNOUNCE.
//--- Sleep until the ingame clock passes the unlock mark, then create the marker and announce.
//------------------------------------------------------------------------------------
private ["_unlockAt"];
_unlockAt = missionNamespace getVariable ["WFBE_C_OILFIELD_UNLOCK_TIME", 3600];

//--- DORMANT until unlock: poll cheaply (no marker, no capture, no income yet).
waitUntil { sleep 10; time > _unlockAt };

//--- Create the persistent GLOBAL marker (createMarker on the server replicates to all clients incl. JIP,
//--- exactly like the bank marker in Construction_MediumSite.sqf). Start NEUTRAL (yellow).
private ["_mkr","_neutralColor"];
_mkr = "WFBE_OILFIELD";
_neutralColor = "ColorYellow"; //--- unheld / neutral node colour (side-absolute; see WFBE_FNC_OilfieldColor default)

createMarker [_mkr, _nodePos];
_mkr setMarkerType (missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_TYPE", "mil_circle"]);
_mkr setMarkerColor _neutralColor;
_mkr setMarkerText (missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_TEXT", "OILFIELD"]);
_mkr setMarkerSize [1, 1];

//--- Ownership state: sideLogic = neutral/unheld sentinel (never a real playing side).
missionNamespace setVariable ["WFBE_OILFIELD_OWNER", sideLogic, true];

//--- ANNOUNCE to ALL clients (global chat) via the existing DashboardAnnounce PVF (systemChat).
//--- nil destination = broadcast to everyone on every side (see server_dashboard_announcer.sqf).
private ["_openMsg"];
_openMsg = missionNamespace getVariable ["WFBE_C_OILFIELD_OPEN_MSG", "The OILFIELD is now active! Hold it with your units to earn passive supply income. Check your map."];
[nil, "DashboardAnnounce", [_openMsg]] Call WFBE_CO_FNC_SendToClients;

diag_log Format ["OILFIELD|v1|UNLOCK|t=%1|pos=%2", round time, _nodePos];
["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD UNLOCKED at t=%1s, marker [%2] created at %3, opening announced to all clients.", round time, _mkr, _nodePos]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- (3)+(4) LIVE LOOP: capture (proximity + cleared-of-enemy) + income while held.
//------------------------------------------------------------------------------------
private ["_radius","_scanTick","_incomeEvery","_incomeAmt","_incomeCap","_incomeAccrued","_lastIncomeT"];
_radius       = missionNamespace getVariable ["WFBE_C_OILFIELD_RADIUS", 120];        //--- capture/hold radius (m)
_scanTick     = missionNamespace getVariable ["WFBE_C_OILFIELD_SCAN_INTERVAL", 15];  //--- capture scan cadence (s)
_incomeEvery  = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_INTERVAL", 60];//--- pay cadence (s)
_incomeAmt    = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_SUPPLY", 25];  //--- supply per pay tick (small)
_incomeCap    = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_CAP", 15000];  //--- lifetime supply cap paid by this node (per round)

if (_scanTick < 5) then {_scanTick = 5};        //--- never hammer the scan
if (_incomeEvery < _scanTick) then {_incomeEvery = _scanTick};

_incomeAccrued = 0;      //--- total supply this node has paid (against the cap)
_lastIncomeT   = time;   //--- last pay timestamp

while { !(missionNamespace getVariable ["WFBE_GameOver", false]) } do {
	sleep _scanTick;

	private ["_owner","_westNear","_eastNear","_u","_flip","_newOwner"];
	_owner = missionNamespace getVariable ["WFBE_OILFIELD_OWNER", sideLogic];

	//--- Presence scan: count alive WEST and EAST units (players OR AI) within radius (2D).
	//--- Use nearestObjects with a broad "Man"+vehicle net; classic A2-OA. We keep it cheap by using a
	//--- single nearEntities pass over living men/vehicles near the node.
	_westNear = 0;
	_eastNear = 0;
	{
		_u = _x;
		if (alive _u) then {
			//--- crewed vehicle counts by its crew's side; a "Man" counts directly. side of an empty hull
			//--- is unreliable in A2-OA, so we only tally MEN (drivers/gunners/infantry), which is exactly
			//--- "units present". This keeps the capture rule to real personnel, per the ~zero-AI design.
			if (_u isKindOf "Man") then {
				switch (side _u) do {
					case west: { _westNear = _westNear + 1 };
					case east: { _eastNear = _eastNear + 1 };
				};
			};
		};
	} forEach (_nodePos nearEntities [["Man"], _radius]);

	//--- Determine controlling side this scan: exactly one main side present -> that side controls.
	//--- Contested (both) or empty (neither) -> no controller this scan.
	_newOwner = sideLogic;
	if (_westNear > 0 && _eastNear == 0) then {_newOwner = west};
	if (_eastNear > 0 && _westNear == 0) then {_newOwner = east};

	//--- (4) FLIP on change to a real side (never flips back to neutral just because the holder walked
	//--- away — holding persists until the OTHER side clears+occupies, matching town capture feel).
	_flip = false;
	if (_newOwner != sideLogic && _newOwner != _owner) then {
		_flip = true;
		_owner = _newOwner;
		missionNamespace setVariable ["WFBE_OILFIELD_OWNER", _owner, true];

		//--- Recolour the global marker to the new owner (server-side setMarkerColor replicates globally).
		_mkr setMarkerColor (_owner call WFBE_FNC_OilfieldColor);

		//--- Announce the capture to all clients (global systemChat via DashboardAnnounce PVF).
		private ["_capMsg","_sideName"];
		_sideName = switch (_owner) do { case west: {"BLUFOR"}; case east: {"OPFOR"}; default {str _owner} };
		_capMsg = Format ["%1 has captured the OILFIELD!", _sideName];
		[nil, "DashboardAnnounce", [_capMsg]] Call WFBE_CO_FNC_SendToClients;

		diag_log Format ["OILFIELD|v1|CAPTURE|t=%1|owner=%2|w=%3|e=%4", round time, str _owner, _westNear, _eastNear];
		["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD captured by %1 at t=%2s (WEST near=%3, EAST near=%4).", str _owner, round time, _westNear, _eastNear]] Call WFBE_CO_FNC_LogContent;
	};

	//--- (3) INCOME while held by a real side, on the income cadence, capped for the round.
	if (_owner == west || _owner == east) then {
		if ((time - _lastIncomeT) >= _incomeEvery) then {
			_lastIncomeT = time;
			if (_incomeAccrued < _incomeCap) then {
				private ["_pay"];
				_pay = _incomeAmt;
				if ((_incomeAccrued + _pay) > _incomeCap) then {_pay = _incomeCap - _incomeAccrued};
				if (_pay > 0) then {
					_incomeAccrued = _incomeAccrued + _pay;
					//--- Existing side-income path (same call town supply income uses in updateresources.sqf).
					//--- includeStagnation=true -> applies the no-players stagnation coefficient like town income.
					[_owner, _pay, Format ["OILFIELD passive income (held by %1).", str _owner], true] Call ChangeSideSupply;
					diag_log Format ["OILFIELD|v1|INCOME|t=%1|owner=%2|pay=%3|accrued=%4|cap=%5", round time, str _owner, _pay, _incomeAccrued, _incomeCap];
				};
			};
		};
	};
};

["INFORMATION", "Server_Oilfields.sqf: game over - OILFIELD loop ended."] Call WFBE_CO_FNC_LogContent;
