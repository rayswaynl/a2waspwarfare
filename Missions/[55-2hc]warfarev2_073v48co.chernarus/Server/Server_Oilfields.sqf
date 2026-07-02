/* Server_Oilfields.sqf — OILFIELDS neutral capturable resource node (Ray 2026-07-01, Takistan).
   cmdcon42 upgrade (claude-gaming 2026-07-02): stakes visibility + sabotage/repair loop + AICOM pull + GUER raids.

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

     (3) INCOME while HELD (and NOT sabotaged). On each income tick the owning side (if any) is credited
         a small, capped supply amount via the existing side-income path: [_side, _amount, _reason,
         _includeStagnation] Call ChangeSideSupply — the SAME call town supply income uses in
         Server\FSM\updateresources.sqf. includeStagnation=true so it applies the no-players stagnation
         coefficient exactly like town income (never a synthetic windfall on an empty server). Neutral
         (unheld) node pays nobody; a SABOTAGED node pays nobody until repaired.

     (4) CAPTURE = proximity + cleared-of-enemy. A side "holds" the node when it has >=1 alive unit
         (player OR AI) within WFBE_C_OILFIELD_RADIUS of the node AND the OTHER main side has none.
         Contested (both present) or empty (neither present) leaves ownership unchanged. On a real flip
         the marker recolours to the new owner and a capture line is announced to all clients.

     (5) cmdcon42 STAKES VISIBILITY (WFBE_C_OILFIELD_MARKER_LIVE, default ON): the marker LABEL is kept
         live — owner tag + supply/tick + a "SABOTAGED" flag — so the map itself tells the story. The
         WASPSCALE emitter also publishes oilOwn/oilInc (server telemetry; keys chosen collision-free).

     (6) cmdcon42 SABOTAGE + REPAIR LOOP (WFBE_C_OILFIELD_SABOTAGE, default ON): an ENEMY of the current
         holder who dwells in the radius (with the holder cleared out) for WFBE_C_OILFIELD_SABOTAGE_SECS
         SABOTAGES the field: income halts and a server-global BURNING FIRE (inflame — the exact
         Init_IcbmTel.sqf:482 idiom) + a periodically re-spawned BLACK SMOKE COLUMN (the
         Server_OnHQKilled.sqf:59 SmokeShellBlack idiom) light up as a daylight-friendly spectacle at a
         fixed, known, contested place. The OWNING side repairs by dwelling in the radius for
         WFBE_C_OILFIELD_REPAIR_SECS (halved when an engineer/repair-truck is present) -> fire out,
         income resumes. Counterplay both ways. Folded into the SAME scan loop (no new worker loop).

     (7) cmdcon42 AI CONTESTS (WFBE_C_OILFIELD_AICOM_PULL, default ON): while the field is NOT held by an
         AI side, that side's NEAREST real town gets a spearhead-weight bonus (wfbe_aicom_town_weight),
         so the AI commander's existing town scorer pulls assaulting teams toward the field's area; they
         pass through the radius and capture the field organically. The field is NEVER added to the towns
         array (it is deliberately NOT a town). Bonus is cleared the moment that side holds the field.

     (8) cmdcon42 GUER RAIDS (WFBE_C_OILFIELD_GUER_RAID, DEFAULT OFF — it adds AI units): an occasional,
         group-budget-aware GUER foot party spawns and patrols the field while it is PAYING, so
         players/AI must defend infrastructure = a recurring a-life encounter at a fixed known place.
         Reuses WFBE_CO_FNC_CreateGroup (140-cap aware) + WFBE_CO_FNC_CreateUnit + AIPatrol.

     ~ZERO standing AI in the base feature: no guards are spawned unless the (default-OFF) GUER raid flag
     is on. The node is won purely by whoever brings units into the radius, so the core loop never burns
     FPS or trips the no-sim-gating rules.

   ALL new tunables are read via missionNamespace getVariable [NAME, default] so the Constants owner
   can add authoritative definitions; the defaults below keep the feature fully working if they don't.

   A2-OA 1.64 ONLY. No A3 commands (no isEqualType/selectRandom/params/pushBack/remoteExec/
   allMapMarkers/getTerrainHeightASL). Classic A2-OA idioms only, verified against neighbouring code
   (Init_NavalHVT.sqf, server_town.sqf capture block, Construction_MediumSite.sqf bank marker,
   Init_IcbmTel.sqf inflame fire, Server_OnHQKilled.sqf SmokeShellBlack, AI_Commander_Wildcard_GUER.sqf
   group/unit spawn, AI_Commander_Strategy.sqf wfbe_aicom_town_weight scoring hook).
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

//--- Short display name for a side, used in marker labels + announces.
WFBE_FNC_OilfieldSideName = {
	private ["_s"]; _s = _this;
	switch (_s) do { case west: {"BLUFOR"}; case east: {"OPFOR"}; case resistance: {"GUER"}; default {"NEUTRAL"} };
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
private ["_mkr","_neutralColor","_baseLabel"];
_mkr = "WFBE_OILFIELD";
_neutralColor = "ColorYellow"; //--- unheld / neutral node colour (side-absolute; see WFBE_FNC_OilfieldColor default)
_baseLabel = missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_TEXT", "OILFIELD"];

createMarker [_mkr, _nodePos];
_mkr setMarkerType (missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_TYPE", "mil_circle"]);
_mkr setMarkerColor _neutralColor;
_mkr setMarkerText _baseLabel;
_mkr setMarkerSize [1, 1];

//--- Ownership state: sideLogic = neutral/unheld sentinel (never a real playing side).
missionNamespace setVariable ["WFBE_OILFIELD_OWNER", sideLogic, true];
//--- Sabotage state: false = healthy/paying; true = burning/not-paying. Published for telemetry + label.
missionNamespace setVariable ["WFBE_OILFIELD_SABOTAGED", false, true];

//--- ANNOUNCE to ALL clients (global chat) via the existing DashboardAnnounce PVF (systemChat).
//--- nil destination = broadcast to everyone on every side (see server_dashboard_announcer.sqf).
private ["_openMsg"];
_openMsg = missionNamespace getVariable ["WFBE_C_OILFIELD_OPEN_MSG", "The OILFIELD is now active! Hold it with your units to earn passive supply income. Check your map."];
[nil, "DashboardAnnounce", [_openMsg]] Call WFBE_CO_FNC_SendToClients;

diag_log Format ["OILFIELD|v1|UNLOCK|t=%1|pos=%2", round time, _nodePos];
["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD UNLOCKED at t=%1s, marker [%2] created at %3, opening announced to all clients.", round time, _mkr, _nodePos]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- (5) LIVE MARKER LABEL helper. Rebuilds the marker text from live state so the map narrates the
//--- stakes. Cheap (one setMarkerText); only called on state changes, not per scan. Owner-gated by
//--- WFBE_C_OILFIELD_MARKER_LIVE (default ON) so the label can be reverted to static with a flag.
//------------------------------------------------------------------------------------
WFBE_FNC_OilfieldRefreshLabel = {
	private ["_ownerL","_sabL","_incAmtL","_incEveryL","_txt"];
	if ((missionNamespace getVariable ["WFBE_C_OILFIELD_MARKER_LIVE", 1]) != 1) exitWith {};
	_ownerL   = missionNamespace getVariable ["WFBE_OILFIELD_OWNER", sideLogic];
	_sabL     = missionNamespace getVariable ["WFBE_OILFIELD_SABOTAGED", false];
	_incAmtL  = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_SUPPLY", 25];
	_incEveryL= missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_INTERVAL", 60];
	_txt = _baseLabel;
	if (_ownerL == west || _ownerL == east) then {
		_txt = _baseLabel + " [" + (_ownerL Call WFBE_FNC_OilfieldSideName) + "]";
		if (_sabL) then {
			_txt = _txt + " SABOTAGED";
		} else {
			_txt = _txt + " +" + str _incAmtL + "/" + str _incEveryL + "s";
		};
	} else {
		_txt = _baseLabel + " [NEUTRAL]";
	};
	_mkr setMarkerText _txt;
};

//--- Paint the initial (neutral) label immediately.
Call WFBE_FNC_OilfieldRefreshLabel;

//------------------------------------------------------------------------------------
//--- (6) FIRE / SMOKE FX. Server-global spectacle for a SABOTAGED field, daylight-friendly (fire glow +
//--- towering black smoke), reusing the two PROVEN server-side global idioms already in this mission:
//---   - a burning object via createVehicle + inflame true  (Init_IcbmTel.sqf:481-482)
//---   - a black smoke column via "SmokeShellBlack" createVehicle  (Server_OnHQKilled.sqf:59)
//--- A single smoke shell dissipates, so a bounded spawned re-emitter re-drops one every
//--- WFBE_C_OILFIELD_SMOKE_INTERVAL seconds WHILE the sabotaged flag holds (self-terminates on repair
//--- or game over). The persistent flame object is created once on sabotage and deleteVehicle'd on
//--- repair. One fire object + one smoke shell at a time = count-safe (no per-frame work, no A3 cmds).
//------------------------------------------------------------------------------------
WFBE_FNC_OilfieldStartFX = {
	private ["_fire"];
	//--- Persistent flame: cruiseMissileFlare1 is confirmed in-tree (nukeincoming.sqf / Init_IcbmTel.sqf)
	//--- and inflame renders an engine fire on it, globally, with no client-locality problem.
	if (isNull (missionNamespace getVariable ["WFBE_OILFIELD_FIRE_OBJ", objNull])) then {
		_fire = createVehicle ["cruiseMissileFlare1", [_nodePos select 0, _nodePos select 1, 0], [], 0, "NONE"];
		if (!isNull _fire) then {
			_fire setPos [_nodePos select 0, _nodePos select 1, 0];
			_fire inflame true;
			missionNamespace setVariable ["WFBE_OILFIELD_FIRE_OBJ", _fire, true];
		};
	};
	//--- Bounded smoke re-emitter: one thread, guarded by the sabotaged flag; one shell live at a time.
	if (!(missionNamespace getVariable ["WFBE_OILFIELD_SMOKE_LOOP", false])) then {
		missionNamespace setVariable ["WFBE_OILFIELD_SMOKE_LOOP", true];
		[_nodePos] spawn {
			private ["_p","_every","_smoke"];
			_p = _this select 0;
			while { (missionNamespace getVariable ["WFBE_OILFIELD_SABOTAGED", false]) && {!(missionNamespace getVariable ["WFBE_GameOver", false])} } do {
				_smoke = "SmokeShellBlack" createVehicle [_p select 0, _p select 1, 0];
				if (!isNull _smoke) then {_smoke setPos [_p select 0, _p select 1, 0]};
				_every = missionNamespace getVariable ["WFBE_C_OILFIELD_SMOKE_INTERVAL", 18];
				if (_every < 6) then {_every = 6};
				sleep _every;
			};
			missionNamespace setVariable ["WFBE_OILFIELD_SMOKE_LOOP", false];
		};
	};
};

WFBE_FNC_OilfieldStopFX = {
	private ["_fire"];
	_fire = missionNamespace getVariable ["WFBE_OILFIELD_FIRE_OBJ", objNull];
	if (!isNull _fire) then { _fire inflame false; deleteVehicle _fire };
	missionNamespace setVariable ["WFBE_OILFIELD_FIRE_OBJ", objNull, true];
	//--- The smoke re-emitter thread self-terminates on the next tick when the sabotaged flag is false.
};

//------------------------------------------------------------------------------------
//--- (7) AICOM PULL helper. While the field is NOT held by an AI side, stamp a spearhead-weight bonus
//--- on that side's NEAREST real town so the existing AICOM scorer (AI_Commander_Strategy.sqf:204,
//--- + wfbe_aicom_town_weight) pulls assaulting teams toward the field's area. We track the exact town
//--- we bumped per side and the exact delta we added, so we can cleanly SUBTRACT it again (never leave
//--- a permanent weight on a town, and never fight a Constants-set town weight). The field itself is
//--- never a town. Called once per scan tick; O(towns) once — same order as the presence scan.
//------------------------------------------------------------------------------------
WFBE_FNC_OilfieldNearestTown = {
	private ["_best","_bestD","_d"];
	_best = objNull; _bestD = 1e12;
	{ _d = _x distance _nodePos; if (_d < _bestD) then {_bestD = _d; _best = _x} } forEach towns;
	_best
};

//--- Clears any AICOM weight this feature applied for _side (subtract the exact recorded delta, then
//--- forget it). Safe to call when nothing is applied.
WFBE_FNC_OilfieldClearPull = {
	private ["_side","_key","_rec","_t","_amt","_cur"];
	_side = _this;
	_key = format ["WFBE_OILFIELD_PULL_%1", _side];
	_rec = missionNamespace getVariable [_key, []];
	if (count _rec == 2) then {
		_t   = _rec select 0;
		_amt = _rec select 1;
		if (!isNull _t) then {
			_cur = _t getVariable ["wfbe_aicom_town_weight", 0];
			_t setVariable ["wfbe_aicom_town_weight", _cur - _amt, true];
		};
		missionNamespace setVariable [_key, [], true];
	};
};

//--- Applies (or moves) the AICOM pull for _side onto the field's current nearest town. If already
//--- applied to that same town, no-op; if applied to a different town, clears the old one first.
WFBE_FNC_OilfieldApplyPull = {
	private ["_side","_key","_rec","_t","_amt","_prevT","_cur"];
	_side = _this;
	if ((missionNamespace getVariable ["WFBE_C_OILFIELD_AICOM_PULL", 1]) != 1) exitWith {};
	_t = Call WFBE_FNC_OilfieldNearestTown;
	if (isNull _t) exitWith {};
	_amt = missionNamespace getVariable ["WFBE_C_OILFIELD_AICOM_WEIGHT", 600];
	_key = format ["WFBE_OILFIELD_PULL_%1", _side];
	_rec = missionNamespace getVariable [_key, []];
	if (count _rec == 2) then {
		_prevT = _rec select 0;
		if (_prevT == _t) exitWith {};        //--- already bumping the right town.
		_side Call WFBE_FNC_OilfieldClearPull;  //--- moved: undo old bump first.
	};
	_cur = _t getVariable ["wfbe_aicom_town_weight", 0];
	_t setVariable ["wfbe_aicom_town_weight", _cur + _amt, true];
	missionNamespace setVariable [_key, [_t, _amt], true];
};

//------------------------------------------------------------------------------------
//--- (8) GUER RAID spawner (DEFAULT OFF). Bounded, group-budget-aware. Reuses the proven
//--- WFBE_CO_FNC_CreateGroup (140-cap aware) + WFBE_CO_FNC_CreateUnit + AIPatrol idioms
//--- (AI_Commander_Wildcard_GUER.sqf). Only spawns while the field is PAYING (held + not sabotaged),
//--- respecting a min interval and a resistance group headroom cap. Server-local group => server-local
//--- units/waypoints (no HC delegation needed; this whole file is server-side).
//------------------------------------------------------------------------------------
WFBE_FNC_OilfieldTryGuerRaid = {
	private ["_last","_interval","_grpCap","_gcnt","_grp","_size","_cls","_i","_sp","_u"];
	if ((missionNamespace getVariable ["WFBE_C_OILFIELD_GUER_RAID", 0]) != 1) exitWith {};
	_last     = missionNamespace getVariable ["WFBE_OILFIELD_GUER_LAST", -1e9];
	_interval = missionNamespace getVariable ["WFBE_C_OILFIELD_GUER_RAID_INTERVAL", 1500];
	if ((time - _last) < _interval) exitWith {};
	//--- Group-budget guard: leave headroom below A2-OA's 144/side hard cap.
	_grpCap = missionNamespace getVariable ["WFBE_C_OILFIELD_GUER_RAID_GRPCAP", 120];
	_gcnt = 0; { if (side _x == resistance) then {_gcnt = _gcnt + 1} } forEach allGroups;
	if (_gcnt >= _grpCap) exitWith {
		["INFORMATION", Format ["Server_Oilfields.sqf: GUER raid skipped - resistance groups %1 >= cap %2.", _gcnt, _grpCap]] Call WFBE_CO_FNC_LogContent;
	};
	_grp = [resistance, "oilfield-guer-raid"] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _grp) exitWith {
		["WARNING", "Server_Oilfields.sqf: GUER raid - CreateGroup returned grpNull, aborting raid."] Call WFBE_CO_FNC_LogContent;
	};
	_size = missionNamespace getVariable ["WFBE_C_OILFIELD_GUER_RAID_SIZE", 4];
	if (_size < 1) then {_size = 1};
	_cls = missionNamespace getVariable ["WFBE_GUERRESSOLDIER", "GUE_Soldier_1"];
	//--- Spawn on a ring ~180-260m off the field so raiders visibly approach it (not on top of it).
	private ["_ang","_r","_ringPos"];
	_ang = random 360; _r = 180 + random 80;
	_ringPos = [(_nodePos select 0) + _r * sin _ang, (_nodePos select 1) + _r * cos _ang, 0];
	for "_i" from 1 to _size do {
		_sp = [(_ringPos select 0) + (random 20) - 10, (_ringPos select 1) + (random 20) - 10, 0];
		_u = [_cls, _grp, _sp, resistance] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _u) then { _u setVariable ["WFBE_IsTownDefenderAI", true, true] };
	};
	//--- Patrol AROUND the field (AIPatrol lays MOVE/CYCLE waypoints centred on the destination).
	[_grp, _nodePos, 90] Call AIPatrol;
	_grp setBehaviour "AWARE";
	_grp setCombatMode "RED";
	missionNamespace setVariable ["WFBE_OILFIELD_GUER_LAST", time];
	diag_log Format ["OILFIELD|v2|GUERRAID|t=%1|size=%2|from=%3", round time, _size, _ringPos];
	["INFORMATION", Format ["Server_Oilfields.sqf: GUER raid (%1 raiders) dispatched to the OILFIELD from %2.", _size, _ringPos]] Call WFBE_CO_FNC_LogContent;
};

//------------------------------------------------------------------------------------
//--- (3)+(4)+(5)+(6)+(7)+(8) LIVE LOOP: capture + income + live label + sabotage/repair + AICOM pull + GUER raids.
//------------------------------------------------------------------------------------
private ["_radius","_scanTick","_incomeEvery","_incomeAmt","_incomeCap","_incomeAccrued","_lastIncomeT",
	"_sabotageOn","_sabSecs","_repSecs","_sabProg","_repProg","_repairTypes"];
_radius       = missionNamespace getVariable ["WFBE_C_OILFIELD_RADIUS", 120];        //--- capture/hold radius (m)
_scanTick     = missionNamespace getVariable ["WFBE_C_OILFIELD_SCAN_INTERVAL", 15];  //--- capture scan cadence (s)
_incomeEvery  = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_INTERVAL", 60];//--- pay cadence (s)
_incomeAmt    = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_SUPPLY", 25];  //--- supply per pay tick (small)
_incomeCap    = missionNamespace getVariable ["WFBE_C_OILFIELD_INCOME_CAP", 15000];  //--- lifetime supply cap paid by this node (per round)
_sabotageOn   = (missionNamespace getVariable ["WFBE_C_OILFIELD_SABOTAGE", 1]) == 1; //--- sabotage/repair loop enabled?
_sabSecs      = missionNamespace getVariable ["WFBE_C_OILFIELD_SABOTAGE_SECS", 45];  //--- enemy dwell (s) to sabotage
_repSecs      = missionNamespace getVariable ["WFBE_C_OILFIELD_REPAIR_SECS", 40];    //--- owner dwell (s) to repair

if (_scanTick < 5) then {_scanTick = 5};        //--- never hammer the scan
if (_incomeEvery < _scanTick) then {_incomeEvery = _scanTick};

//--- Engineer / repair-truck classes (any side): presence halves the repair time. Reuses the mission's
//--- OWN consolidated repair-truck list (WFBE_REPAIRTRUCKS - merged across WFBE_PRESENTSIDES in
//--- Init_Common.sqf:397) so we never have to guess the per-side %1 tokens, + the EP1 engineer classes.
_repairTypes = [];
private ["_rtList"];
_rtList = missionNamespace getVariable ["WFBE_REPAIRTRUCKS", []];
if (typeName _rtList == "ARRAY") then { { if (!(_x in _repairTypes)) then {_repairTypes = _repairTypes + [_x]} } forEach _rtList };
{ if (!(_x in _repairTypes)) then {_repairTypes = _repairTypes + [_x]} } forEach ["US_Soldier_Engineer_EP1","TK_Soldier_Engineer_EP1","GUE_Soldier_Crew"];

_incomeAccrued = 0;      //--- total supply this node has paid (against the cap)
_lastIncomeT   = time;   //--- last pay timestamp
_sabProg       = 0;      //--- accumulated enemy-dwell seconds toward sabotage
_repProg       = 0;      //--- accumulated owner-dwell seconds toward repair

while { !(missionNamespace getVariable ["WFBE_GameOver", false]) } do {
	sleep _scanTick;

	private ["_owner","_westNear","_eastNear","_guerNear","_repairNear","_u","_ut","_flip","_newOwner","_sab"];
	_owner = missionNamespace getVariable ["WFBE_OILFIELD_OWNER", sideLogic];
	_sab   = missionNamespace getVariable ["WFBE_OILFIELD_SABOTAGED", false];

	//--- Presence scan: count alive WEST/EAST/GUER MEN within radius (2D), and whether an engineer/
	//--- repair vehicle is present (speeds repair). One nearEntities pass over living men + vehicles.
	_westNear = 0; _eastNear = 0; _guerNear = 0; _repairNear = false;
	{
		_u = _x;
		if (alive _u) then {
			//--- crewed vehicle counts by its crew's side; a "Man" counts directly. side of an empty hull
			//--- is unreliable in A2-OA, so we only tally MEN (drivers/gunners/infantry), which is exactly
			//--- "units present". This keeps the capture rule to real personnel, per the ~zero-AI design.
			if (_u isKindOf "Man") then {
				switch (side _u) do {
					case west:       { _westNear = _westNear + 1 };
					case east:       { _eastNear = _eastNear + 1 };
					case resistance: { _guerNear = _guerNear + 1 };
				};
				_ut = typeOf _u;
				if (_ut in _repairTypes) then {_repairNear = true};
			} else {
				//--- vehicle: only used to detect a repair TRUCK near the field (never for capture tally).
				if (count (crew _u) > 0) then { if ((typeOf _u) in _repairTypes) then {_repairNear = true} };
			};
		};
	} forEach (_nodePos nearEntities [["Man","Car","Tank"], _radius]);

	//--- Determine controlling side this scan: exactly one MAIN side present -> that side controls.
	//--- Contested (both) or empty (neither) -> no controller this scan. (GUER can sabotage but not own.)
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

		//--- A capture RESETS the sabotage clock (fresh holder) but does NOT auto-repair a burning field:
		//--- the new owner must still repair it. Reset the dwell accumulators on any flip.
		_sabProg = 0; _repProg = 0;

		//--- Recolour the global marker to the new owner (server-side setMarkerColor replicates globally).
		_mkr setMarkerColor (_owner call WFBE_FNC_OilfieldColor);
		Call WFBE_FNC_OilfieldRefreshLabel;

		//--- Announce the capture to all clients (global systemChat via DashboardAnnounce PVF).
		private ["_capMsg"];
		_capMsg = Format ["%1 has captured the OILFIELD!", (_owner Call WFBE_FNC_OilfieldSideName)];
		[nil, "DashboardAnnounce", [_capMsg]] Call WFBE_CO_FNC_SendToClients;

		diag_log Format ["OILFIELD|v1|CAPTURE|t=%1|owner=%2|w=%3|e=%4", round time, str _owner, _westNear, _eastNear];
		["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD captured by %1 at t=%2s (WEST near=%3, EAST near=%4).", str _owner, round time, _westNear, _eastNear]] Call WFBE_CO_FNC_LogContent;
	};

	//--- (6) SABOTAGE + REPAIR. Only meaningful when a real side holds the field.
	if (_sabotageOn && (_owner == west || _owner == east)) then {
		private ["_enemyNear","_ownerNear"];
		//--- "enemy of the holder" = the OTHER main side + GUER. Holder must be cleared to sabotage
		//--- (uncontested enemy presence), matching the capture feel and giving the holder counterplay.
		_enemyNear = if (_owner == west) then {_eastNear + _guerNear} else {_westNear + _guerNear};
		_ownerNear = if (_owner == west) then {_westNear} else {_eastNear};

		if (!_sab) then {
			//--- Healthy field: uncontested enemy dwell accrues toward sabotage; owner presence resets it.
			if (_enemyNear > 0 && _ownerNear == 0) then {
				_sabProg = _sabProg + _scanTick;
			} else {
				if (_sabProg > 0) then {_sabProg = 0};
			};
			if (_sabProg >= _sabSecs) then {
				//--- SABOTAGED: halt income, start FX, announce, relabel.
				missionNamespace setVariable ["WFBE_OILFIELD_SABOTAGED", true, true];
				_sab = true; _sabProg = 0; _repProg = 0;
				Call WFBE_FNC_OilfieldStartFX;
				Call WFBE_FNC_OilfieldRefreshLabel;
				[nil, "DashboardAnnounce", [(missionNamespace getVariable ["WFBE_C_OILFIELD_SABOTAGE_MSG", "The OILFIELD has been SABOTAGED! It stops paying until the owner repairs it - watch for the smoke."])]] Call WFBE_CO_FNC_SendToClients;
				diag_log Format ["OILFIELD|v2|SABOTAGE|t=%1|owner=%2", round time, str _owner];
				["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD SABOTAGED at t=%1s (owner=%2).", round time, str _owner]] Call WFBE_CO_FNC_LogContent;
			};
		} else {
			//--- Burning field: owner dwell (uncontested) accrues toward repair; enemy presence resets it.
			//--- Engineer / repair-truck presence on the owner's side HALVES the required repair time.
			if (_ownerNear > 0 && _enemyNear == 0) then {
				private ["_step"];
				_step = _scanTick;
				if (_repairNear) then {_step = _scanTick * 2};   //--- engineer/truck => effectively half the repair time.
				_repProg = _repProg + _step;
			} else {
				if (_repProg > 0) then {_repProg = 0};
			};
			if (_repProg >= _repSecs) then {
				//--- REPAIRED: resume income, stop FX, announce, relabel.
				missionNamespace setVariable ["WFBE_OILFIELD_SABOTAGED", false, true];
				_sab = false; _repProg = 0; _sabProg = 0;
				Call WFBE_FNC_OilfieldStopFX;
				Call WFBE_FNC_OilfieldRefreshLabel;
				[nil, "DashboardAnnounce", [(missionNamespace getVariable ["WFBE_C_OILFIELD_REPAIR_MSG", "The OILFIELD has been repaired and is paying out again."])]] Call WFBE_CO_FNC_SendToClients;
				diag_log Format ["OILFIELD|v2|REPAIR|t=%1|owner=%2", round time, str _owner];
				["INFORMATION", Format ["Server_Oilfields.sqf: OILFIELD REPAIRED at t=%1s (owner=%2, engineer/truck=%3).", round time, str _owner, _repairNear]] Call WFBE_CO_FNC_LogContent;
			};
		};
	};

	//--- (3) INCOME while held by a real side, NOT sabotaged, on the income cadence, capped for the round.
	if ((_owner == west || _owner == east) && !(missionNamespace getVariable ["WFBE_OILFIELD_SABOTAGED", false])) then {
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
		//--- (8) GUER raids only while the field is PAYING (held + not sabotaged). Bounded + budget-aware.
		Call WFBE_FNC_OilfieldTryGuerRaid;
	};

	//--- (7) AICOM PULL: for each AI side, apply the nearest-town spearhead bonus while it does NOT hold
	//--- the field; clear it the moment it does. Cheap (O(towns) once per side; same order as the scan).
	{
		if (_owner == _x) then { _x Call WFBE_FNC_OilfieldClearPull } else { _x Call WFBE_FNC_OilfieldApplyPull };
	} forEach [west, east];

	//--- (5) Keep the live label fresh (income figures/owner/sabotage state) even without a flip this tick.
	Call WFBE_FNC_OilfieldRefreshLabel;

	//--- Publish telemetry state the WASPSCALE emitter reads (oilOwn / oilInc). Cheap setVariables.
	missionNamespace setVariable ["WFBE_OILFIELD_OWNER", _owner, true];
	missionNamespace setVariable ["WFBE_OILFIELD_INCOME_ACCRUED", _incomeAccrued, true];
};

//--- Game over: undo any AICOM town-weight bumps so nothing leaks into a re-init, and stop FX.
{ _x Call WFBE_FNC_OilfieldClearPull } forEach [west, east];
Call WFBE_FNC_OilfieldStopFX;
["INFORMATION", "Server_Oilfields.sqf: game over - OILFIELD loop ended."] Call WFBE_CO_FNC_LogContent;
