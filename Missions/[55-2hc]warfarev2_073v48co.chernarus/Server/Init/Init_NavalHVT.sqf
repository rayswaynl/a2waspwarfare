//--- Init_NavalHVT.sqf — Naval HVT Objectives orchestrator.
//--- Called once from Init_Server.sqf, guarded by WFBE_C_NAVAL_HVT.
//--- Creates 3 offshore capturable HVTs on Chernarus east coast, defaulting to GUER ownership.
//---
//--- Assets:
//---   [A] Khe Sanh Alpha   (LHD)  — NE sea        — carrier, aircraft sell
//---   [B] Khe Sanh Bravo   (LHD)  — SE sea         — carrier, aircraft sell
//---   [C] Khe Sanh Charlie (LHD)  — Skalisty sea   — carrier, SCUD strike pad
//--- (exact anchors below; all surfaceIsWater-validated, spread along the east coast)
//---
//--- IMPORTANT NOTES:
//---   • setPosASL for point-placed sea objects (setPosATL snaps to SEABED - never use it here). LHD
//---     HULL PARTS are the exception: canonical A2 assembly is setDir + plain setPos z=0 (engine seats
//---     each section at model height; DayZ/Domination-verified). Verify partpos z at boot via NAVALHVT-DECK.
//---   • All createVehicle calls are GLOBAL (server-authoritative, so AI/collision sees them).
//---   • Town logics are PRE-PLACED in mission.sqm and registered by Init_Town.sqf before this runs.
//---   • The GUER CAP (Mi24_P + An2) is PROXIMITY-GATED: only arms at ~1500-2000m player range
//---     and despawns on the inactivity timeout — never burns FPS over empty ocean.
//---
//--- NEEDS REVIEW (see agent report):
//---   • LHD multi-part hull relative offsets are BEST-GUESS linear fore-to-aft — must be
//---     verified and adjusted in-engine.
//---   • Candidate coordinates must be confirmed with surfaceIsWater in-engine.
//---   • B74.2: VERIFIED no var-name typo — the GUE/resistance roster setter (Units_CO_GUE.sqf:141,
//---     setVariable [Format ["WFBE_%1AIRPORTUNITS", _side]]) resolves _side="GUER" (Root_GUE/TKGUE/PMC
//---     all set _side="GUER", never "GUE"), so it writes WFBE_GUERAIRPORTUNITS — already matching the
//---     reader in GUI_Menu_BuyUnits.sqf:341. No WFBE_GUEAIRPORTUNITS var exists. Nothing to fix.

if (!isServer) exitWith {};
if !(missionNamespace getVariable ["IS_naval_map", false]) exitWith {["INFORMATION", Format ["Init_NavalHVT.sqf : IS_naval_map=false (worldName=%1) - naval carriers are a NAVAL-MAP-ONLY feature, disabled here. B754 (Ray 2026-06-25): explicit guard (Takistan) instead of the incidental missing-Khe-Sanh-logic bail; kills the per-round WARNING.", worldName]] Call WFBE_CO_FNC_LogContent};
if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) != 1) exitWith {
	["INFORMATION", "Init_NavalHVT.sqf : WFBE_C_NAVAL_HVT=0 — feature is OFF, skipping."] Call WFBE_CO_FNC_LogContent;
};

["INITIALIZATION", "Init_NavalHVT.sqf : Naval HVT feature ENABLED — starting offshore asset spawn."] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- WAIT: town init must be complete before we look up pre-placed naval logics.
//------------------------------------------------------------------------------------
waitUntil { !isNil "townInit" && townInit };
waitUntil { !isNil "towns" };

//------------------------------------------------------------------------------------
//--- HELPER: spawn a static prop at ASL position; configure it.
//--- Returns the created object.
//------------------------------------------------------------------------------------
WFBE_NavalHVT_SpawnProp = {
	private ["_cls","_pos","_dir","_obj"];
	_cls = _this select 0;
	_pos = _this select 1;
	_dir = if (count _this > 2) then {_this select 2} else {0};
	_obj = createVehicle [_cls, [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
	//--- cmdcon28 (Ray 2026-06-30): if a class fails to create (missing addon / bad name) log it and bail,
	//--- so a half-built carrier is diagnosable from the RPT instead of a null silently corrupting the hull.
	if (isNull _obj) exitWith {
		diag_log (Format ["NAVALHVT-SPAWNFAIL: class '%1' failed to createVehicle at %2 - class missing/invalid; part skipped.", _cls, _pos]);
		_obj
	};
	//--- cmdcon45 (Ray 2026-07-07): canonical A2 LHD assembly is setDir FIRST, then plain setPos
	//--- (AGLS z=0 over water) so the engine seats each section at its model-defined height. The old
	//--- setPosASL [x,y,0] crushed EVERY part (island + elevators included) to the waterline - that
	//--- was the live "one big pancake stack" carrier + props/SCUD sunk into the hull. Pattern
	//--- verified against the A2-engine DayZ LHD creator and Domination (same-point parts,
	//--- dir-then-pos, flight deck ~15.9 m over the sea).
	_obj setDir _dir;
	_obj setPos [_pos select 0, _pos select 1, 0];
	_obj enableSimulation false;
	_obj allowDamage false;
	_obj
};

//------------------------------------------------------------------------------------
//--- fable/naval-cap-variety (owner 2026-07-08): SKIRMISH outcome helper - spawns a single WEST/EAST
//--- intruder jet near a carrier for the rare additive "duel" spectacle, self-cleans on a lifetime
//--- ceiling or intruder death. Called `[_loc, _pos] spawn WFBE_NavalCap_FNC_SpawnSkirmish` from the
//--- CAP arm block below; the caller increments WFBE_NAVAL_SKIRMISH_ACTIVE BEFORE spawning (no yield
//--- point between that read and write, so it is race-safe against the other 2 carrier threads under
//--- A2's cooperative SQF scheduler); this function decrements it on EVERY exit path so a create
//--- failure can never leak the concurrency slot. Mirrors Server_AmbientSkirmish.sqf's spawn/duel/
//--- self-clean shape (own group, own registry - no coupling to WFBE_AMBIENT_SKIRMISH_RUNNING, which
//--- gates a separate, ground-only feature). A2 OA 1.64 safe: no selectRandom/pushBack/findIf/params;
//--- select floor(random count), isNull/alive guards throughout.
//------------------------------------------------------------------------------------
WFBE_NavalCap_FNC_SpawnSkirmish = {
	private ["_loc","_pos","_side","_sideStr","_classes","_cls","_ang","_spawnPos","_intruderGrp","_intruder","_pilotClass","_pilot","_lifetime","_maxWait","_reason"];
	_loc = _this select 0;
	_pos = _this select 1;

	_side    = if ((random 1) < 0.5) then {west} else {east};
	_sideStr = if (_side == west) then {"WEST"} else {"EAST"};
	_classes = if (_side == west)
		then {missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_WEST_CLASSES", ["A10","A10_US_EP1","L159_ACR"]]}
		else {missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_EAST_CLASSES", ["Su25_TK_EP1","Su25_Ins","ibrPRACS_MiG21mol"]]};
	_lifetime = missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_LIFETIME", 240];

	if ((count _classes) < 1) exitWith {
		missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", ((missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]) - 1) max 0];
		diag_log Format ["NAVALCAP|SKIRMISH|RESOLVE|carrier=%1|reason=no_classes|elapsed=0", _loc getVariable "name"];
	};

	_ang      = random 360;
	_spawnPos = [(_pos select 0) + 1200 * (sin _ang), (_pos select 1) + 1200 * (cos _ang), 650];
	_cls      = _classes select (floor (random (count _classes)));

	_intruderGrp = [_side, "naval-cap-skirmish"] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _intruderGrp) exitWith {
		missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", ((missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]) - 1) max 0];
		diag_log Format ["NAVALCAP|SKIRMISH|RESOLVE|carrier=%1|reason=no_group|elapsed=0", _loc getVariable "name"];
	};

	//--- Naval CAP's own idiom (Init_NavalHVT.sqf L39 arm block above), NOT AmbientSkirmish's ground
	//--- _spawnGroup: airborne FLY special with an explicit direction so the wrapper's own anti-stall-dive
	//--- setVelocity applies (Common_CreateVehicle.sqf: the "FLY" branch sets forward velocity from _direction).
	_intruder = [_cls, _spawnPos, _side, _ang, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
	if (isNull _intruder) exitWith {
		deleteGroup _intruderGrp;
		missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", ((missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]) - 1) max 0];
		diag_log Format ["NAVALCAP|SKIRMISH|RESOLVE|carrier=%1|reason=create_failed|elapsed=0", _loc getVariable "name"];
	};
	_intruder flyInHeight 550;

	_pilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideStr], "USMC_Soldier_Pilot"];
	_pilot = [_pilotClass, _intruderGrp, _spawnPos, _side] Call WFBE_CO_FNC_CreateUnit;
	if (isNull _pilot) exitWith {
		if (!isNull _intruder && {({isPlayer _x} count (crew _intruder)) == 0}) then {deleteVehicle _intruder};
		deleteGroup _intruderGrp;
		missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", ((missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]) - 1) max 0];
		diag_log Format ["NAVALCAP|SKIRMISH|RESOLVE|carrier=%1|reason=no_pilot|elapsed=0", _loc getVariable "name"];
	};
	_pilot moveInDriver _intruder;

	_intruderGrp setVariable ["wfbe_naval_cap_skirmish", true, true];
	_intruder setVariable ["wfbe_naval_cap_skirmish", true, true];
	_intruderGrp setBehaviour "COMBAT";
	_intruderGrp setCombatMode "RED";
	_intruderGrp setSpeedMode "FULL";
	_pilot doMove [_pos select 0, _pos select 1, 0];

	["INFORMATION", Format ["Init_NavalHVT.sqf : NAVALCAP SKIRMISH intruder armed at %1 (%2 %3).", _loc getVariable "name", _sideStr, _cls]] Call WFBE_CO_FNC_LogContent;
	diag_log Format ["NAVALCAP|SKIRMISH|SPAWN|carrier=%1|side=%2|class=%3|baseMode=%4|activeCount=%5", _loc getVariable "name", _sideStr, _cls, missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_BASE_MODE", "MI24"], missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]];

	//--- Self-clean: mirrors Server_AmbientSkirmish.sqf's lifetime sub-thread (its spawn block ~L229-248).
	//--- Hard ceiling regardless of duel outcome; resolves early once the intruder is dead. Player-safe
	//--- teardown (B66 rule, Server_GuerAirDef.sqf:220-227) even though an AI intruder is never expected
	//--- to be boarded here.
	_maxWait = 0;
	waitUntil {
		sleep 1;
		_maxWait = _maxWait + 1;
		(isNull _intruder) || {!(alive _intruder)} || {_maxWait >= _lifetime}
	};

	_reason = if (_maxWait >= _lifetime) then {"lifetime"} else {"intruder_killed"};
	if (!isNull _intruder && {({isPlayer _x} count (crew _intruder)) == 0}) then { {deleteVehicle _x} forEach (crew _intruder); deleteVehicle _intruder; };
	if (!isNull _intruderGrp) then { {if (!(isPlayer _x)) then {deleteVehicle _x}} forEach (units _intruderGrp); deleteGroup _intruderGrp; };
	missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", ((missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 1]) - 1) max 0];

	diag_log Format ["NAVALCAP|SKIRMISH|RESOLVE|carrier=%1|reason=%2|elapsed=%3", _loc getVariable "name", _reason, _maxWait];
	["INFORMATION", Format ["Init_NavalHVT.sqf : NAVALCAP SKIRMISH resolved at %1 (reason=%2, elapsed=%3s).", _loc getVariable "name", _reason, _maxWait]] Call WFBE_CO_FNC_LogContent;
};

//------------------------------------------------------------------------------------
//--- A2's LHD is a set of part-objects placed at the SAME world point; each model holds the FULL
//--- ~250 m carrier geometry internally (rendering only its own section). Git-confirmed: the old code
//--- SPREAD them fore-to-aft (22 m apart) and that showed SEVERAL STACKED CARRIERS - so [0,0,0] is
//--- correct and offsets must NOT be re-added (1595a461f). cmdcon28 (Ray 2026-06-30): RESTORED
//--- Land_LHD_elev_L (port elevator) + Land_LHD_house_2_CP (island bridge), which 1595a461f dropped on
//--- an UNVERIFIED "not standard" hunch - their removal left the port superstructure missing (the
//--- half-carrier + camp-under-deck + scud-in-water bug). The SpawnProp null-guard below logs any part
//--- whose class is genuinely absent, so an invalid class shows in the RPT instead of silently breaking.
WFBE_C_NAVAL_LHD_OFFSETS = [
	["Land_LHD_1",          [0, 0, 0]],
	["Land_LHD_2",          [0, 0, 0]],
	["Land_LHD_3",          [0, 0, 0]],
	["Land_LHD_4",          [0, 0, 0]],
	["Land_LHD_5",          [0, 0, 0]],
	["Land_LHD_6",          [0, 0, 0]],
	["Land_LHD_house_1",    [0, 0, 0]],
	["Land_LHD_house_2",    [0, 0, 0]],
	["Land_LHD_house_2_CP", [0, 0, 0]],
	["Land_LHD_elev_L",     [0, 0, 0]],
	["Land_LHD_elev_R",     [0, 0, 0]]
];

//------------------------------------------------------------------------------------
//--- SPAWN FUNCTION: build a carrier at the given anchor position + heading.
//------------------------------------------------------------------------------------
WFBE_NavalHVT_SpawnLHD = {
	private ["_anchor","_dir","_parts","_p","_cls","_off","_px","_py","_obj","_dx","_dy"];
	_anchor = _this select 0;
	_dir    = _this select 1;	//--- ship heading (degrees)
	_parts  = [];

	{
		_cls = _x select 0;
		_off = _x select 1;

		//--- Rotate offset by ship heading.
		_dx = (_off select 0) * cos _dir - (_off select 1) * sin _dir;
		_dy = (_off select 0) * sin _dir + (_off select 1) * cos _dir;
		_px = (_anchor select 0) + _dx;
		_py = (_anchor select 1) + _dy;

		_obj = [_cls, [_px, _py, 0], _dir] Call WFBE_NavalHVT_SpawnProp;
		_parts set [count _parts, _obj];
	} forEach WFBE_C_NAVAL_LHD_OFFSETS;

	_parts	//--- return list of spawned objects for cleanup/reference
};

WFBE_NavalHVT_Off = { [((_this select 0) select 0) + (_this select 1), ((_this select 0) select 1) + (_this select 2), 0] };

//------------------------------------------------------------------------------------
//--- FIND PRE-PLACED TOWN LOGICS
//--- The 2 naval logics are pre-placed in mission.sqm and already registered in
//--- towns[] by Init_Town.sqf. Locate them by their name variable.
//------------------------------------------------------------------------------------
private ["_lhdAlphaLogic","_lhdBravoLogic","_lhdCharlieLogic","_x","_tName"];
_lhdAlphaLogic   = objNull;
_lhdBravoLogic   = objNull;
_lhdCharlieLogic = objNull;

{
	_tName = _x getVariable ["name", ""];
	switch (_tName) do {
		case "Khe Sanh Alpha":   { _lhdAlphaLogic   = _x; };
		case "Khe Sanh Bravo":   { _lhdBravoLogic   = _x; };
		case "Khe Sanh Charlie": { _lhdCharlieLogic = _x; };
	};
} forEach towns;

if (isNull _lhdAlphaLogic || isNull _lhdBravoLogic || isNull _lhdCharlieLogic) exitWith {
	["WARNING", "Init_NavalHVT.sqf : pre-placed naval town logic(s) not found in towns[] — check mission.sqm."] Call WFBE_CO_FNC_LogContent;
};

//--- Force sea level (z=0 ASL) on each logic for accurate capture-radius detection.
_lhdAlphaLogic   setPosASL [(getPos _lhdAlphaLogic)   select 0, (getPos _lhdAlphaLogic)   select 1, 0];
_lhdBravoLogic   setPosASL [(getPos _lhdBravoLogic)   select 0, (getPos _lhdBravoLogic)   select 1, 0];
_lhdCharlieLogic setPosASL [(getPos _lhdCharlieLogic) select 0, (getPos _lhdCharlieLogic) select 1, 0];

//--- Sanity: diag_log (always hits the RPT) a WARN if any town logic is NOT over water,
//--- so a bad mission.sqm coord (on land) is caught server-side without a visual check.
{
	if (!(surfaceIsWater (getPos _x))) then {
		diag_log Format ["NAVALHVT-WARN: town [%1] is NOT over water at %2 - fix mission.sqm coord.", _x getVariable ["name","?"], getPos _x];
	};
} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];

//--- Derive 2-element [x,y] anchors from logic positions (downstream structure code uses these
//--- with WFBE_NavalHVT_Off, which reads select 0 / select 1, so must remain [x,y]).
private ["_aAlpha","_aBravo","_aCharlie"];
_aAlpha   = [(getPos _lhdAlphaLogic)   select 0, (getPos _lhdAlphaLogic)   select 1];
_aBravo   = [(getPos _lhdBravoLogic)   select 0, (getPos _lhdBravoLogic)   select 1];
_aCharlie = [(getPos _lhdCharlieLogic) select 0, (getPos _lhdCharlieLogic) select 1];

//------------------------------------------------------------------------------------
//--- cmdcon41-w3 (Ray 2026-07-02) TWIN-HULL SUPER-CARRIERS — MIDDLE detection.
//--- The MIDDLE of the three carriers keeps a SINGLE hull and MUST be the SCUD carrier; the two
//--- OUTER carriers each get a second parallel hull (built lower down, guarded by
//--- WFBE_C_NAVAL_TWIN_HULLS). "Middle" = geometry, computed at RUNTIME so it stays correct if the
//--- mission.sqm anchors ever move: the OUTER pair is the pair with the LARGEST separation, so the
//--- remaining (third) carrier is the middle. Distances use straight XY (A2-OA `distance` on
//--- 2-element points is 1.64-safe). No perf cost — three one-time distance compares.
private ["_dAB","_dAC","_dBC","_midAnchor","_midLogic","_midName","_outer"];
_dAB = _aAlpha   distance _aBravo;
_dAC = _aAlpha   distance _aCharlie;
_dBC = _aBravo   distance _aCharlie;
//--- Pick the largest-separation pair; the carrier NOT in that pair is the middle. == on Numbers is
//--- 1.64-safe; nested if/else avoids any Bool-in-== pitfalls.
if (_dAB >= _dAC && _dAB >= _dBC) then {
	//--- Alpha & Bravo are the outer pair -> Charlie is the middle.
	_midAnchor = _aCharlie; _midLogic = _lhdCharlieLogic; _midName = "Khe Sanh Charlie";
	_outer = [["Khe Sanh Alpha", _aAlpha], ["Khe Sanh Bravo", _aBravo]];
} else {
	if (_dAC >= _dAB && _dAC >= _dBC) then {
		//--- Alpha & Charlie are the outer pair -> Bravo is the middle.
		_midAnchor = _aBravo; _midLogic = _lhdBravoLogic; _midName = "Khe Sanh Bravo";
		_outer = [["Khe Sanh Alpha", _aAlpha], ["Khe Sanh Charlie", _aCharlie]];
	} else {
		//--- Bravo & Charlie are the outer pair -> Alpha is the middle.
		_midAnchor = _aAlpha; _midLogic = _lhdAlphaLogic; _midName = "Khe Sanh Alpha";
		_outer = [["Khe Sanh Bravo", _aBravo], ["Khe Sanh Charlie", _aCharlie]];
	};
};
missionNamespace setVariable ["WFBE_NAVAL_MIDDLE_ANCHOR", _midAnchor];
missionNamespace setVariable ["WFBE_NAVAL_MIDDLE_LOGIC",  _midLogic];
missionNamespace setVariable ["WFBE_NAVAL_MIDDLE_NAME",   _midName];
missionNamespace setVariable ["WFBE_NAVAL_OUTER_PAIR",    _outer];
diag_log Format ["NAVALHVT-TWIN: middle carrier = %1 (dAB=%2 dAC=%3 dBC=%4); outer pair = %5,%6. SCUD stays on the middle.", _midName, _dAB, _dAC, _dBC, (_outer select 0) select 0, (_outer select 1) select 0];

//------------------------------------------------------------------------------------
//--- SPAWN BOTH LHD ASSETS
//------------------------------------------------------------------------------------
private ["_lhdAlphaParts","_lhdBravoParts","_lhdCharlieParts","_pad","_deckPart","_deckZ","_bb","_scudPad"];

//---
//--- [A] KHE SANH ALPHA (LHD) — NE
//---
_lhdAlphaParts = [[_aAlpha select 0, _aAlpha select 1, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

//--- Heli spawn pad on the deck.
_pad = createVehicle ["HeliHCivil", ([_aAlpha, 10, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_pad setPosASL [((_aAlpha select 0) + 10), (_aAlpha select 1), 15.9]; //--- cmdcon45: ON the deck (was z=0 = sea level INSIDE the hull).
_pad enableSimulation false;
_pad allowDamage false;

//--- Deck-Z query: find the top-of-hull Z for spawn/teleport callers.
_deckPart = _lhdAlphaParts select 3;
_bb = boundingBox _deckPart; //--- B754 (Ray 2026-06-25): measure the REAL deck height (was a hardcoded 16 guess) so deck-respawned players land on the flight deck, not clipping the hull / falling into the sea. boundingBox is A2-OA 1.64-safe.
_deckZ = 15.9; //--- cmdcon45 (Ray 2026-07-07): flight deck is the engine-verified 15.9 m over the sea (DayZ LHD creator / Domination "spawn at 15.9 to be ON deck"). The B754 boundingBox read gave 22.42 (symmetrized model-box TOP, not the deck) so every deck respawn materialised ~8.5 m up and fell. _bb stays in the diag line for forensics.
_lhdAlphaLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
_lhdAlphaLogic setVariable ["wfbe_naval_deckpart", _lhdAlphaParts select 3, true]; //--- fable/naval-deck-fixes: reference hull part for model-space deck placement
_lhdAlphaLogic setVariable ["wfbe_is_naval_hvt", true, true];
//--- cmdcon41-w2 (Ray 2026-07-02) TOWN-CENTER HEIGHT: raise the town logic from sea level (z=0, set at
//--- line ~140) to the flight-deck height so the player-facing town CENTER/marker sits ON the deck, not
//--- WAY UNDER it in the water. The capture scan in server_town.sqf is UNAFFECTED: _capH = deckZ+12 is
//--- measured ATL from the sea surface below each unit (unitsBelowHeight is surface-relative, NOT
//--- caller-Z-relative), and nearEntities uses the caller XY with a large capture radius, so a ~deckZ Z
//--- shift on the logic does not change which deck/under-deck units count. deckZ is the SAME value the
//--- scan already reads. Keeps the scan consistent: deck units still count, under-deck/water units do not.
_lhdAlphaLogic setPosASL [(getPos _lhdAlphaLogic) select 0, (getPos _lhdAlphaLogic) select 1, _deckZ];
diag_log Format ["NAVALHVT-DECK: Khe Sanh Alpha partpos=%1 bbMin=%2 bbMax=%3 deckZ=%4", getPosASL _deckPart, _bb select 0, _bb select 1, _deckZ];

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [A] Khe Sanh Alpha (LHD) spawned at %1.", _aAlpha]] Call WFBE_CO_FNC_LogContent;

//---
//--- [B] KHE SANH BRAVO (LHD) — SE
//---
_lhdBravoParts = [[_aBravo select 0, _aBravo select 1, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

_pad = createVehicle ["HeliHCivil", ([_aBravo, 10, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_pad setPosASL [((_aBravo select 0) + 10), (_aBravo select 1), 15.9]; //--- cmdcon45: ON the deck (was z=0 = sea level INSIDE the hull).
_pad enableSimulation false;
_pad allowDamage false;

//--- Deck-Z query: find the top-of-hull Z for spawn/teleport callers.
_deckPart = _lhdBravoParts select 3;
_bb = boundingBox _deckPart; //--- B754 (Ray 2026-06-25): measure the REAL deck height (was a hardcoded 16 guess) so deck-respawned players land on the flight deck, not clipping the hull / falling into the sea. boundingBox is A2-OA 1.64-safe.
_deckZ = 15.9; //--- cmdcon45 (Ray 2026-07-07): flight deck is the engine-verified 15.9 m over the sea (DayZ LHD creator / Domination "spawn at 15.9 to be ON deck"). The B754 boundingBox read gave 22.42 (symmetrized model-box TOP, not the deck) so every deck respawn materialised ~8.5 m up and fell. _bb stays in the diag line for forensics.
_lhdBravoLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
_lhdBravoLogic setVariable ["wfbe_naval_deckpart", _lhdBravoParts select 3, true]; //--- fable/naval-deck-fixes: reference hull part for model-space deck placement
_lhdBravoLogic setVariable ["wfbe_is_naval_hvt", true, true];
//--- cmdcon41-w2 (Ray 2026-07-02) TOWN-CENTER HEIGHT: raise Bravo's logic to deck height (see Alpha note above).
_lhdBravoLogic setPosASL [(getPos _lhdBravoLogic) select 0, (getPos _lhdBravoLogic) select 1, _deckZ];
diag_log Format ["NAVALHVT-DECK: Khe Sanh Bravo partpos=%1 bbMin=%2 bbMax=%3 deckZ=%4", getPosASL _deckPart, _bb select 0, _bb select 1, _deckZ];

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [B] Khe Sanh Bravo (LHD) spawned at %1.", _aBravo]] Call WFBE_CO_FNC_LogContent;

//---
//--- [C] KHE SANH CHARLIE (LHD) — Skalisty Island sea
//---
_lhdCharlieParts = [[_aCharlie select 0, _aCharlie select 1, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

//--- Deck-Z query: find the top-of-hull Z for spawn/teleport callers.
_deckPart = _lhdCharlieParts select 3;
_bb = boundingBox _deckPart; //--- B754 (Ray 2026-06-25): measure the REAL deck height (was a hardcoded 16 guess) so deck-respawned players land on the flight deck, not clipping the hull / falling into the sea. boundingBox is A2-OA 1.64-safe.
_deckZ = 15.9; //--- cmdcon45 (Ray 2026-07-07): flight deck is the engine-verified 15.9 m over the sea (DayZ LHD creator / Domination "spawn at 15.9 to be ON deck"). The B754 boundingBox read gave 22.42 (symmetrized model-box TOP, not the deck) so every deck respawn materialised ~8.5 m up and fell. _bb stays in the diag line for forensics.
_lhdCharlieLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
_lhdCharlieLogic setVariable ["wfbe_naval_deckpart", _lhdCharlieParts select 3, true]; //--- fable/naval-deck-fixes: reference hull part for model-space deck placement
_lhdCharlieLogic setVariable ["wfbe_is_naval_hvt", true, true];
//--- cmdcon41-w2 (Ray 2026-07-02) TOWN-CENTER HEIGHT: raise Charlie's logic to deck height (see Alpha note above).
_lhdCharlieLogic setPosASL [(getPos _lhdCharlieLogic) select 0, (getPos _lhdCharlieLogic) select 1, _deckZ];
diag_log Format ["NAVALHVT-DECK: Khe Sanh Charlie partpos=%1 bbMin=%2 bbMax=%3 deckZ=%4", getPosASL _deckPart, _bb select 0, _bb select 1, _deckZ];

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [C] Khe Sanh Charlie (LHD) spawned at %1.", _aCharlie]] Call WFBE_CO_FNC_LogContent;

//--- cmdcon41-w3 (Ray 2026-07-02) TWIN-HULL: the SCUD pad + visual SCUD must live on the MIDDLE carrier
//--- (computed above), not a hardcoded Charlie. Resolve the middle carrier's anchor/parts/deckZ/logic here
//--- so the whole SCUD setup (pad + addAction + visual launcher + attachTo target) follows the middle even
//--- if the mission.sqm anchors move and a different carrier becomes the middle. In the current layout the
//--- middle IS Charlie, so this is behaviour-identical; the indirection satisfies the "MOVE the SCUD to the
//--- middle" requirement generically. deckZ is read back from the middle logic's wfbe_naval_deckz (set per
//--- carrier above) so the pad sits on the correct deck; parts are picked to match the middle logic.
private ["_scudAnchor","_scudLogic","_scudParts","_scudDeckZ"];
_scudLogic  = missionNamespace getVariable ["WFBE_NAVAL_MIDDLE_LOGIC", _lhdCharlieLogic];
_scudAnchor = missionNamespace getVariable ["WFBE_NAVAL_MIDDLE_ANCHOR", _aCharlie];
_scudDeckZ  = _scudLogic getVariable ["wfbe_naval_deckz", _deckZ];
//--- Match the parts list to whichever carrier is the middle (deck part = index 3, per the boundingBox above).
_scudParts = _lhdCharlieParts;
if (_scudLogic == _lhdAlphaLogic) then { _scudParts = _lhdAlphaParts };
if (_scudLogic == _lhdBravoLogic) then { _scudParts = _lhdBravoParts };

//--- SCUD pad on the MIDDLE carrier's deck (addAction proximity reference).
_scudPad = createVehicle ["HeliHCivil", [_scudAnchor select 0, _scudAnchor select 1, 0], [], 0, "NONE"];
_scudPad setPosASL [_scudAnchor select 0, _scudAnchor select 1, _scudDeckZ];	//--- cmdcon45: deckZ=15.9 (the "~22m deck" here was the bbMax artefact, see deckZ note above).
_scudPad enableSimulation false;
_scudPad allowDamage false;
_scudPad setVariable ["wfbe_is_scud_pad", true, true];
_scudLogic setVariable ["wfbe_scud_pad_ref", _scudPad, true];
missionNamespace setVariable ["WFBE_NAVAL_HVT_PLATFORMS", [_scudLogic]];

//--- SCUD ADDACTION on the middle carrier's deck. Only team-leaders of the owning side near the pad see it.
[_scudLogic, _scudPad] spawn {
	private ["_loc","_pad","_sideID","_ownerSide","_actionID","_team","_isLeader","_x"];
	_loc = _this select 0;
	_pad = _this select 1;
	while { !WFBE_GameOver } do {
		sleep 15;
		_sideID    = _loc getVariable ["sideID", WFBE_C_GUER_ID];
		_ownerSide = _sideID Call WFBE_CO_FNC_GetSideFromID;
		{
			//--- fable/naval-camps-on-deck (Ray 2026-07-07): gate on distance to the VISUAL SCUD model
//--- (wfbe_scud_model_ref, stored above). The pad anchor is 50m from the launcher so players
//--- standing at the SCUD were right at the boundary and the action never triggered. Fallback
//--- to _pad preserves safe behaviour if the ref is absent.
private ["_scudRef"];
_scudRef = _loc getVariable ["wfbe_scud_model_ref", _pad];
if (isPlayer _x && {alive _x} && {(side _x) == _ownerSide} && {(_x distance _scudRef) < 50}) then {
				_team = group _x;
				_isLeader = (_x == leader _team);
				if (_isLeader) then {
					if (isNil {_x getVariable "wfbe_scud_action_armed"}) then {
						_x setVariable ["wfbe_scud_action_armed", true];
						//--- task46 (claude) N-FEAT-1: the addAction must be created on the CLIENT, not here.
						//--- On a dedicated server _x is a remote player unit, so a server-side addAction is
						//--- invisible to the actual client. Dispatch a signal to this player's UID; the client
						//--- (HandleSpecial.sqf case "scud-action-add") adds the action to its local player.
						//--- The proximity/leader/owner-side gate above stays SERVER-side; the wfbe_scud_action_armed
						//--- latch (set just above) makes the server send this only once per player.
						[getPlayerUID _x, "HandleSpecial", ["scud-action-add"]] Call WFBE_CO_FNC_SendToClients;
					};
				};
			};
		} forEach playableUnits;
	};
};

//------------------------------------------------------------------------------------
//--- VISUAL SCUD: an erect 9P117 SCUD-B launcher standing on Charlie's deck (thematic payoff for
//--- owning her). Placed ~50m along the deck from the spawn/pad point; raise the missile via the
//--- scudLaunch action, re-seat it, then freeze it static so it can't drive/fall/explode.
//------------------------------------------------------------------------------------
//--- cmdcon41-w2 (Ray 2026-07-02) SCUD FALLOFF FIX: the visual SCUD used a hardcoded z=16 (below the real
//--- deck, which sits at deckZ ~22) and only enableSimulation-false AFTER a 6s free-physics erect, so during
//--- those 6s it drifted and slid off one carrier. Fix (least invasive): (a) spawn/re-seat at the TRUE deckZ,
//--- not 16, so it starts ON the deck surface; (b) after the erect, attachTo the carrier deck hull part —
//--- attachTo rigidly pins a child to its (static) parent, so no residual physics can ever slide it off.
//--- attachTo + worldToModel are A2-OA 1.64-safe (worldToModel used elsewhere for statics). The deck part is
//--- the MIDDLE carrier's parts select 3 (cmdcon41-w3: middle carrier, resolved above — same part used for
//--- the deckZ boundingBox on that carrier).
private ["_scudModel","_scudDeckPart"];
_scudDeckPart = _scudParts select 3;
private ["_scudXY"];
_scudXY = _scudDeckPart modelToWorld [8, -14, 0]; //--- fable/naval-deck-fixes: anchor+50 put the launcher 41m past the bow (anchor sits ~21m east of hull center, half-length ~30m; live RPT showed [14750,2000] vs deck edge ~14709). Deck-part model space is heading-proof.
_scudModel = createVehicle ["MAZ_543_SCUD_TK_EP1", [_scudXY select 0, _scudXY select 1, 0], [], 0, "NONE"];
//--- fable/naval-camps-on-deck (Ray 2026-07-07) SCUD CLEARANCE: the MAZ_543_SCUD_TK_EP1 vehicle origin
//--- is mid-body (~1.6 m above the ground plane), so placing the origin at exactly deckZ sinks the
//--- lower half of the vehicle into the deck. Add WFBE_C_NAVAL_SCUD_CLEARANCE (default 1.6) so the
//--- hull clears the deck surface. Owner will eyeball and adjust the constant in-engine.
private ["_scudSpawnZ"];
_scudSpawnZ = _scudDeckZ + (missionNamespace getVariable ["WFBE_C_NAVAL_SCUD_CLEARANCE", 1.6]);
_scudModel setPosASL [_scudXY select 0, _scudXY select 1, _scudSpawnZ];
_scudModel setDir 90;
_scudModel allowDamage false;
//--- cmdcon41 SCUD THEATRICS (feature 1, Ray 2026-07-02): store the deck SCUD launcher on the platform logic so
//--- Support_ScudStrike.sqf can find the firing carrier's launcher and play the erect/backblast at launch. The
//--- platform logic == the single entry stored in WFBE_NAVAL_HVT_PLATFORMS above (the object ScudStrike validates
//--- ownership on), so a strike resolves its launcher with one getVariable. Broadcast so any locality can read it.
//--- fable/naval-camps-on-deck: also store wfbe_scud_model_ref so the addAction proximity gate (below)
//--- can test distance to the VISUAL launcher, not the invisible pad anchor (50m apart).
_scudLogic setVariable ["wfbe_hvt_scud", _scudModel, true];
_scudLogic setVariable ["wfbe_scud_model_ref", _scudModel, true];
diag_log Format ["NAVALHVT-SCUD: visual SCUD spawned at [%1,%2,%3] (deckZ=%4 + clearance=%5); model ref stored.", _scudXY select 0, _scudXY select 1, _scudSpawnZ, _scudDeckZ, missionNamespace getVariable ["WFBE_C_NAVAL_SCUD_CLEARANCE", 1.6]];
[_scudModel, _scudXY select 0, _scudXY select 1, _scudSpawnZ, _scudDeckPart] spawn {
	private ["_s","_px","_py","_dz","_deckPart","_off"];
	_s        = _this select 0;
	_px       = _this select 1;
	_py       = _this select 2;
	_dz       = _this select 3;
	_deckPart = _this select 4;
	_s action ["scudLaunch", _s];		//--- raise the missile to vertical
	sleep 6;							//--- let the erect animation finish
	_s setPosASL [_px, _py, _dz];		//--- correct any physics drift during the erect (TRUE deck height)
	_s setVectorUp [0,0,1];				//--- re-level the launcher
	//--- Pin it to the carrier so no residual physics can slide it off the deck. attachTo keeps the child at
	//--- a fixed model-space offset from the (static) parent; worldToModel converts the corrected world pos.
	if (!isNull _deckPart) then {
		_off = _deckPart worldToModel (getPosASL _s);
		_s attachTo [_deckPart, _off];
		_s setVectorUp [0,0,1];			//--- re-level after the attach re-orients relative to parent
	};
	_s enableSimulation false;			//--- freeze it static (erect)
};

//--- fable/scud-showpiece (owner 2026-07-07): the SCUD deck is a SHOWPIECE - a second erect launcher
//--- abeam the first + light deck dressing. All prop classes verified in-mission (Core_RU camo net,
//--- Core_CIV bagfence, Construction/Oilfields Barrels). Flag WFBE_C_NAVAL_SCUD_SHOWPIECE default 0.
if ((missionNamespace getVariable ["WFBE_C_NAVAL_SCUD_SHOWPIECE", 0]) > 0) then {
	private ["_scudXY2","_scudModel2","_propSpec","_propXY","_prop"];
	_scudXY2 = _scudDeckPart modelToWorld [1, -14, 0]; //--- ~7 m abeam of the primary launcher (deck model space, heading-proof)
	_scudModel2 = createVehicle ["MAZ_543_SCUD_TK_EP1", [_scudXY2 select 0, _scudXY2 select 1, 0], [], 0, "NONE"];
	if (!isNull _scudModel2) then {
		_scudModel2 setPosASL [_scudXY2 select 0, _scudXY2 select 1, _scudSpawnZ];
		_scudModel2 setDir 90;
		_scudModel2 allowDamage false;
		//--- Same erect / re-seat / attachTo / freeze drill as the primary launcher above.
		[_scudModel2, _scudXY2 select 0, _scudXY2 select 1, _scudSpawnZ, _scudDeckPart] spawn {
			private ["_s","_px","_py","_dz","_deckPart","_off"];
			_s        = _this select 0;
			_px       = _this select 1;
			_py       = _this select 2;
			_dz       = _this select 3;
			_deckPart = _this select 4;
			_s action ["scudLaunch", _s];
			sleep 6;
			_s setPosASL [_px, _py, _dz];
			_s setVectorUp [0,0,1];
			if (!isNull _deckPart) then {
				_off = _deckPart worldToModel (getPosASL _s);
				_s attachTo [_deckPart, _off];
				_s setVectorUp [0,0,1];
			};
			_s enableSimulation false;
		};
		diag_log Format ["NAVALHVT-SHOWPIECE: second SCUD spawned at [%1,%2,%3].", _scudXY2 select 0, _scudXY2 select 1, _scudSpawnZ];
	};
	//--- Deck dressing: [class, modelX, modelY, dir] in deck-part model space around the launchers.
	//--- SpawnProp makes each static/indestructible and logs+skips absent classes; re-seat to deck
	//--- height afterwards (pier idiom above).
	{
		_propSpec = _x;
		_propXY = _scudDeckPart modelToWorld [(_propSpec select 1), (_propSpec select 2), 0];
		_prop = [(_propSpec select 0), [_propXY select 0, _propXY select 1, 0], (_propSpec select 3)] Call WFBE_NavalHVT_SpawnProp;
		if (!isNull _prop) then {
			_prop setPosASL [_propXY select 0, _propXY select 1, _scudDeckZ];
			_prop setVectorUp [0,0,1];
		};
	} forEach [
		["Land_CamoNetB_EAST",      4.5, -19.5, 90],
		["Land_fort_bagfence_long", 12,  -9,    0],
		["Land_fort_bagfence_long", -3,  -9,    0],
		["Barrels",                 12,  -19,   0]
	];
};

//------------------------------------------------------------------------------------
//--- cmdcon41-w3 (Ray 2026-07-02) TWIN-HULL SUPER-CARRIERS — build the second hull on each OUTER carrier
//--- and bridge the gap with walkable pier statics. The MIDDLE carrier (SCUD carrier, resolved above) is
//--- untouched — single hull. Guarded by WFBE_C_NAVAL_TWIN_HULLS (default 1).
//---
//--- Geometry: all three carriers spawn with heading _dir = 90 (see the SpawnLHD calls above). The twin
//--- hull is offset LATERALLY (perpendicular to the ship heading) by ~42m so the two decks run parallel:
//---   perp offset = [x + 42*cos(dir), y - 42*sin(dir)].
//--- SIGN CHECK vs this file's conventions: A2 forward for setDir _dir is [sin dir, cos dir]; the right-hand
//--- perpendicular is [cos dir, -sin dir]. At dir=90 that is [cos90, -sin90] = [0,-1], i.e. a pure -Y shift,
//--- which is genuinely perpendicular to heading-90 (which points +X). This is a rotation-correct perpendicular
//--- (NOT the same as the WFBE_NavalHVT_Off helper, which is a raw un-rotated XY add used only for the pad at
//--- dir=90); here we need the true perpendicular for arbitrary headings, so we spell out cos/sin. The twin
//--- hull is spawned with the SAME heading via WFBE_NavalHVT_SpawnLHD, so its deck is parallel and level.
//---
//--- Bridge: 3 walkable pier segments (Land_nav_pier_m_1 — CONFIRMED present in this mission, see
//--- Client\Module\Nuke\damage.sqf's pier-preserve list; the prompt's suggested Land_nav_pier_m_2 is NOT in
//--- that confirmed list, so we use the verified _m_1) set at the deck height, spaced across the 42m gap so
//--- players can cross between the two hulls. SpawnProp null-guards each (logs to RPT if a class is absent).
//---
//--- Perf: purely static, one-time (11 LHD parts + 3 piers per outer carrier). No loops, no per-frame scans.
if ((missionNamespace getVariable ["WFBE_C_NAVAL_TWIN_HULLS", 1]) == 1) then {
	private ["_twinDir","_twinGap","_bridgeClass","_bridgeCount"];
	_twinDir     = 90;			//--- same heading as the original hulls (SpawnLHD dir above)
	_twinGap     = 42;			//--- lateral (perpendicular) offset to the twin hull, metres
	_bridgeClass = "Land_nav_pier_m_1";	//--- confirmed A2 Chernarus flat walkable pier (damage.sqf preserve list)
	_bridgeCount = 3;			//--- pier segments spanning the gap

	{
		private ["_ocName","_ocAnchor","_ocLogic","_ocDeckZ","_perpX","_perpY","_twinAnchor","_twinParts","_bx","_by","_frac","_j","_pier"];
		_ocName   = _x select 0;
		_ocAnchor = _x select 1;

		//--- Resolve this outer carrier's logic + deck height (deckZ was stored per carrier above).
		_ocLogic = objNull;
		if (_ocName == "Khe Sanh Alpha")   then { _ocLogic = _lhdAlphaLogic };
		if (_ocName == "Khe Sanh Bravo")   then { _ocLogic = _lhdBravoLogic };
		if (_ocName == "Khe Sanh Charlie") then { _ocLogic = _lhdCharlieLogic };
		_ocDeckZ = 16;
		if (!isNull _ocLogic) then { _ocDeckZ = _ocLogic getVariable ["wfbe_naval_deckz", 16] };

		//--- fable/naval-inline-hulls (Ray 2026-07-06): A/B switch on WFBE_C_NAVAL_INLINE_HULLS.
		//--- When > 0: place Hull B INLINE (bow-to-stern, aft of Hull A) instead of laterally.
		//--- When = 0: verbatim HEAD lateral behaviour (unchanged).
		if ((missionNamespace getVariable ["WFBE_C_NAVAL_INLINE_HULLS", 0]) > 0) then {
			//=============================================================================
			//--- INLINE PATH: bow-to-stern super-carrier axis.
			//---
			//--- Sign-convention proof (must match SpawnLHD's rotation in this file):
			//---   SpawnLHD rotates offsets as:
			//---     _dx = off_x*cos(_dir) - off_y*sin(_dir)
			//---     _dy = off_x*sin(_dir) + off_y*cos(_dir)
			//---   So body-space +Y maps to world [sin dir, cos dir] (the "forward" vector).
			//---   Aft = opposite = body-space -Y = world [-sin dir, -cos dir].
			//---
			//---   Hull B anchor (aft of Hull A by |gap| metres):
			//---     world_x = anchorX + gap * (-sin dir)  = anchorX - |gap|*sin(dir)
			//---     world_y = anchorY + gap * (-cos dir)  = anchorY - |gap|*cos(dir)
			//---   where gap = WFBE_C_NAVAL_INLINE_GAP (negative number, e.g. -265),
			//---   so -gap (a positive number) gives the aft displacement:
			//---     world_x = anchorX - (-265)*sin(dir)  [minus a negative = plus]
			//---     world_y = anchorY - (-265)*cos(dir)
			//---   Simplifying with _inlineGap = abs(WFBE_C_NAVAL_INLINE_GAP):
			//---     world_x = anchorX - _inlineGap * sin(dir)
			//---     world_y = anchorY - _inlineGap * cos(dir)
			//---   Verified at dir=90 (east-facing, current layout):
			//---     world_x = anchorX - 265*sin(90) = anchorX - 265*1 = anchorX - 265
			//---     world_y = anchorY - 265*cos(90) = anchorY - 265*0 = anchorY
			//---   i.e. Hull B is 265m to the WEST of Hull A when the ship faces east.
			//---   That is aft (stern) of a heading-90 ship — correct.
			//---
			//---   Compare the lateral formula above:
			//---     _perpX = cos(dir);  _perpY = -(sin dir)
			//---     twinX  = anchorX + 42*cos(dir)
			//---     twinY  = anchorY - 42*sin(dir)
			//---   At dir=90: twinX = anchorX + 42*0 = anchorX
			//---              twinY = anchorY - 42*1 = anchorY - 42  (pure -Y shift = south)
			//---   That is perpendicular to heading-90 — correct for lateral.
			//---   Same rotation identity (cos/sin of the same _dir); only the axis changes.
			//=============================================================================
			private ["_inlineGap","_inlineAnchor","_inlineParts","_deckZB","_bridgeZ","_seam_Y_offsets","_bY","_bwX","_bwY","_seamPier"];
			_inlineGap = abs (missionNamespace getVariable ["WFBE_C_NAVAL_INLINE_GAP", -265]);
			//--- Tuner guard: a gap of 0 would place Hull B exactly on Hull A (silent overlap). Self-heal to the
			//--- design default and warn in RPT so a bad lobby/constants value is diagnosable, not invisible.
			if (_inlineGap < 1) then {_inlineGap = 265; diag_log "NAVALHVT-INLINE: WFBE_C_NAVAL_INLINE_GAP resolved to 0 - self-healed to 265 (hulls would overlap)."};
			_inlineAnchor = [
				(_ocAnchor select 0) - _inlineGap * sin(_twinDir),
				(_ocAnchor select 1) - _inlineGap * cos(_twinDir),
				0
			];

			//--- Hull B: same heading, same SpawnLHD call — no game logic attached.
			//--- Hull B carries ZERO town logic / camp / SCUD (all game-logic stays on Hull A).
			_inlineParts = [_inlineAnchor, _twinDir] Call WFBE_NavalHVT_SpawnLHD;

			//--- Seam-bridge piers (only when WFBE_C_NAVAL_SEAM_BRIDGE > 0).
			//--- 4x Land_nav_pier_m_1 across the Hull A stern / Hull B bow join.
			//--- Z = average of Hull A and Hull B deck heights (conservative floor to avoid float).
			//--- Body-space Y offsets from Hull A anchor: nominally -131,-134,-137,-140
			//--- (i.e. 131-140m aft of the Hull A anchor, inside the seam zone).
			//--- VERIFY in-editor: adjust these Y values until piers land in the gap centre.
			if ((missionNamespace getVariable ["WFBE_C_NAVAL_SEAM_BRIDGE", 0]) > 0) then {
				//--- Probe Hull B deckZ from part[3] (same pattern as Hull A above).
				_deckZB = _ocDeckZ;
				if (count _inlineParts > 3) then {
					private ["_bbB","_partB"];
					_partB = _inlineParts select 3;
					if (!isNull _partB) then {
						_bbB   = boundingBox _partB;
						_deckZB = (getPosASL _partB select 2) + ((_bbB select 1) select 2);
					};
				};
				_bridgeZ = (_ocDeckZ + _deckZB) / 2;
				_seam_Y_offsets = [-131, -134, -137, -140];
				{
					_bY  = _x;
					//--- Convert body-space Y offset to world coords using the ship heading.
					//--- Body +Y = world [sin dir, cos dir]; aft offset _bY is negative.
					_bwX = (_ocAnchor select 0) + _bY * sin(_twinDir);
					_bwY = (_ocAnchor select 1) + _bY * cos(_twinDir);
					//--- Facing _twinDir (fore-aft), NOT +90 like the lateral bridge: the inline seam is a surface
					//--- PATCH under the runway centreline (piers lie along the roll direction so a wheel crosses
					//--- pier ends, not pier sides). The lateral path bridges a port-starboard GAP, hence its +90.
					//--- If in-editor the pier long-axis proves perpendicular to placement dir, switch to (_twinDir + 90).
					_seamPier = [_bridgeClass, [_bwX, _bwY, 0], _twinDir] Call WFBE_NavalHVT_SpawnProp;
					if (!isNull _seamPier) then {
						_seamPier setPosASL [_bwX, _bwY, _bridgeZ];
					};
				} forEach _seam_Y_offsets;
				diag_log Format ["NAVALHVT-INLINE: [%1] seam bridge spawned (%2 piers at bridgeZ=%3).", _ocName, count _seam_Y_offsets, _bridgeZ];
			};

			["INITIALIZATION", Format ["Init_NavalHVT.sqf : fable/naval-inline-hulls — inline Hull B built for OUTER carrier [%1] at %2 (gap %3m).", _ocName, _inlineAnchor, _inlineGap]] Call WFBE_CO_FNC_LogContent;
			diag_log Format ["NAVALHVT-INLINE: [%1] inlineAnchor=%2 deckZ=%3 gap=%4", _ocName, _inlineAnchor, _ocDeckZ, _inlineGap];

		} else {
			//=============================================================================
			//--- LATERAL PATH (HEAD behaviour, verbatim — active when WFBE_C_NAVAL_INLINE_HULLS=0).
			//=============================================================================
			//--- Perpendicular unit vector for heading _twinDir: [cos dir, -sin dir] (right-hand side of forward).
			_perpX = cos _twinDir;
			_perpY = -(sin _twinDir);
			_twinAnchor = [(_ocAnchor select 0) + _twinGap * _perpX, (_ocAnchor select 1) + _twinGap * _perpY];

			//--- Second full LHD hull, same heading -> deck runs parallel to the original.
			_twinParts = [[_twinAnchor select 0, _twinAnchor select 1, 0], _twinDir] Call WFBE_NavalHVT_SpawnLHD;

			//--- Bridge the gap with walkable piers, spaced across the 42m span at deck height. The piers sit at
			//--- fractional steps between the original hull anchor and the twin anchor (excluding the very ends so
			//--- they land in the gap, not inside a hull).
			for [{_j = 1}, {_j <= _bridgeCount}, {_j = _j + 1}] do {
				_frac = _j / (_bridgeCount + 1);
				_bx = (_ocAnchor select 0) + ((_twinAnchor select 0) - (_ocAnchor select 0)) * _frac;
				_by = (_ocAnchor select 1) + ((_twinAnchor select 1) - (_ocAnchor select 1)) * _frac;
				//--- SpawnProp sets it static/indestructible + logs to RPT if the class is missing. Face it along
				//--- the gap (perpendicular to ship heading) so the pier's long axis bridges hull-to-hull.
				_pier = [_bridgeClass, [_bx, _by, 0], (_twinDir + 90)] Call WFBE_NavalHVT_SpawnProp;
				//--- SpawnProp forces z=0 (sea level, correct for the shared hull parts); the pier must sit ON the
				//--- deck, so re-seat the returned object at deck height here (helper left untouched). Guard isNull
				//--- so a missing pier class (already logged by SpawnProp) does not error on setPosASL.
				if (!isNull _pier) then {
					_pier setPosASL [_bx, _by, _ocDeckZ];
				};
			};

			["INITIALIZATION", Format ["Init_NavalHVT.sqf : cmdcon41-w3 twin hull built for OUTER carrier [%1] at %2 (gap %3m, %4 piers).", _ocName, _twinAnchor, _twinGap, _bridgeCount]] Call WFBE_CO_FNC_LogContent;
			diag_log Format ["NAVALHVT-TWIN: [%1] twinAnchor=%2 deckZ=%3 perp=[%4,%5]", _ocName, _twinAnchor, _ocDeckZ, _perpX, _perpY];
		};
	} forEach _outer;
} else {
	["INFORMATION", "Init_NavalHVT.sqf : WFBE_C_NAVAL_TWIN_HULLS=0 — twin-hull super-carriers OFF (single hulls only)."] Call WFBE_CO_FNC_LogContent;
};

//------------------------------------------------------------------------------------
//--- STORE NAVAL HVT LOGICS for server_town.sqf capture-block lookup.
//------------------------------------------------------------------------------------
missionNamespace setVariable ["WFBE_NAVAL_HVT_LOGICS", [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic]];

//------------------------------------------------------------------------------------
//--- B74.2: CARRIER AIR-SHOP. Make each captured carrier act like an airfield air-buy point by
//--- reusing the existing airfield-hangar mechanism (no new shop UI):
//---   • spawn the same WFBE_C_HANGAR hangar on the deck, flagged wfbe_is_airfield_hangar so
//---     GUI_Menu_BuyUnits shows the airfield air-roster (WFBE_AIRFIELD_UNITS / WFBE_GUERAIRPORTUNITS —
//---     B74.2: var name verified correct, GUE roster setter uses _side="GUER", no typo);
//---   • set wfbe_hangar + wfbe_airfield_side on the naval logic so Client_GetClosestAirport (extended
//---     in B74.2 to scan naval-HVT depot logics) returns the deck as an "airport";
//---   • set wfbe_is_carrier_hvt + wfbe_airfield_logic_ref + wfbe_airfield_hangar_obj so the EXISTING
//---     carrier-capture block in server_town.sqf (~line 300) respawns the hangar for the new owner.
//--- The logic IS its own airfield ref (the capture block respawns the hangar at getPosASL of the ref).
//--- Initial owner side derived from the logic's current sideID (GUER at round start).
{
	private ["_navLoc","_navDeckZ","_navSide","_navHangar","_navPos"];
	_navLoc   = _x;
	_navDeckZ = _navLoc getVariable ["wfbe_naval_deckz", 16];
	_navSide  = (_navLoc getVariable ["sideID", WFBE_C_GUER_ID]) Call WFBE_CO_FNC_GetSideFromID;
	_navPos   = getPosASL _navLoc;

	//--- Hangar on the deck (ASL deck height). Static + indestructible like the carrier props.
	_navHangar = "HeliHEmpty" createVehicle [_navPos select 0, _navPos select 1, 0]; //--- B754b (Ray 2026-06-25): invisible-but-alive HeliHEmpty instead of the WFBE_C_HANGAR building (A2-OA has NO hideObjectGlobal - A3-only). Carries the wfbe_hangar/airfield vars so every air-buy gate works (Client_GetClosestAirport needs !isNull && alive), with NO visible hangar on the deck.
	_navHangar setPosASL [_navPos select 0, _navPos select 1, _navDeckZ];
	_navHangar setDir ((getDir _navLoc) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
	_navHangar enableSimulation false;
	_navHangar allowDamage false; //--- B754b: hangar suppressed by using the invisible HeliHEmpty above (no hideObjectGlobal in A2-OA).
	_navHangar setVariable ["wfbe_is_airfield_hangar", true, true];

	//--- Wire the logic as an airfield + carrier-capture ref.
	_navLoc setVariable ["wfbe_hangar", _navHangar, true];
	_navLoc setVariable ["wfbe_airfield_side", _navSide, true];
	_navLoc setVariable ["wfbe_is_carrier_hvt", true, true];
	_navLoc setVariable ["wfbe_airfield_logic_ref", _navLoc, true];
	_navLoc setVariable ["wfbe_airfield_hangar_obj", _navHangar, true];

	["INITIALIZATION", Format ["Init_NavalHVT.sqf : carrier air-shop wired on [%1] (side %2, deckZ %3).", _navLoc getVariable ["name","?"], str _navSide, _navDeckZ]] Call WFBE_CO_FNC_LogContent;
} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];

//------------------------------------------------------------------------------------
//--- GUER CAP: proximity-gated Mi24_P + An2 patrol for each naval HVT.
//--- Arms at ~1500-2000m player proximity; despawns on inactivity timeout.
//--- One loop per asset, each spawned as a lightweight thread.
//------------------------------------------------------------------------------------
{
	private "_hvtLoc";
	_hvtLoc = _x;
	[_hvtLoc] spawn {
		private ["_loc","_pos","_sideID","_capGrp","_hind","_biplane","_hindPilot","_biplPilot","_armed",
		         "_inactiveTime","_now","_detected","_players","_anyNear","_orbitAng","_dummy","_x",
		         "_threeHinds","_hind2","_hind3","_hindPilot2","_hindPilot3","_capL39","_jet1","_jet2","_jetPilot1","_jetPilot2",
		         "_routeI","_route","_lap","_circuitTimeout","_circuitPts","_cMid","_cOuter","_airfieldPts","_legPt",
		         "_navMode","_wMi24","_wL39","_wSux","_wSkr","_wTotal","_navRoll","_capMode",
		         "_navSkirmishBase","_navSkirmishMax","_navSkirmishActive"];
		_loc  = _this select 0;
		_armed = false;
		_inactiveTime = 0;
		_jet1 = objNull; _jet2 = objNull; _jetPilot1 = objNull; _jetPilot2 = objNull; //--- fable/naval-deck-fixes: were block-scoped in the arming branch, orbit/despawn ticks read them undefined (live RPT :767/:794)

		_orbitAng = random 360;
		_threeHinds = (missionNamespace getVariable ["WFBE_C_NAVAL_CAP_THREE_HINDS", 0]) > 0;
		_capL39 = (missionNamespace getVariable ["WFBE_C_NAVAL_CAP_L39", 0]) > 0; //--- naval-air-spawn-easa: supersedes THREE_HINDS + Mi24/An2 when >0.

		//--- fable/l39-circuit (owner 2026-07-07): L39 sea patrol flies a CIRCUIT over all 3 carriers,
		//--- with ONE inland-airfield visit (NEAF/NWAF alternating) every 3rd lap. Z is ALWAYS explicit:
		//--- a Z=0 doMove is a commanded descent into the sea for fixed-wing AI (the post-#837 nosedive).
		_routeI = 0; _route = []; _lap = 0; _circuitTimeout = 0;
		_cMid   = missionNamespace getVariable ["WFBE_NAVAL_MIDDLE_ANCHOR", [(getPos _loc) select 0, (getPos _loc) select 1]];
		_cOuter = missionNamespace getVariable ["WFBE_NAVAL_OUTER_PAIR", []];
		_circuitPts = [[(getPos _loc) select 0, (getPos _loc) select 1, 550]];
		if (count _cOuter >= 2) then {
			_circuitPts = [
				[((_cOuter select 0) select 1) select 0, ((_cOuter select 0) select 1) select 1, 550],
				[_cMid select 0, _cMid select 1, 550],
				[((_cOuter select 1) select 1) select 0, ((_cOuter select 1) select 1) select 1, 550]
			];
		};
		_airfieldPts = [];
		{
			if ((_x getVariable ["name",""]) in ["NEAF","NWAF"]) then {
				_airfieldPts = _airfieldPts + [[(getPos _x) select 0, (getPos _x) select 1, 550]];
			};
		} forEach towns;

		while { !WFBE_GameOver } do {
			sleep 10;

			_sideID = _loc getVariable ["sideID", WFBE_C_GUER_ID];
			_pos    = getPosASL _loc;

			//--- Check for any player within arming radius (1800m).
			_anyNear = false;
			{
				if (isPlayer _x && {alive _x} && {(_x distance [_pos select 0, _pos select 1, 0]) < 1800}) then {
					_anyNear = true;
				};
			} forEach playableUnits;

			if (_anyNear) then {
				_inactiveTime = 0;

				if (!_armed) then {
					//--- Only arm CAP while GUER still owns this HVT (they may have been captured).
					if (_sideID == WFBE_C_GUER_ID) then {
						_armed = true;
						_capGrp = createGroup resistance;

						_navMode = missionNamespace getVariable ["WFBE_C_NAVAL_CAP_MODE", 1]; //--- fable/naval-cap-variety: 0=legacy CAP_L39/THREE_HINDS chain, >0=weighted roll (default).
						if (_navMode > 0) then {
							_wMi24 = missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_MI24", 45];
							_wL39  = missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_L39", 40];
							_wSux  = missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_SUX", 8];
							_wSkr  = missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_SKIRMISH", 7];
							_wTotal = _wMi24 + _wL39 + _wSux + _wSkr;
							if (_wTotal <= 0) then {_wTotal = 1; _wMi24 = 1; _wL39 = 0; _wSux = 0; _wSkr = 0}; //--- degenerate-config guard: never divide by zero, self-heal to Mi24-only.
							_navRoll = random _wTotal;
							_capMode = "MI24";
							if (_navRoll >= _wMi24)                 then {_capMode = "L39"};
							if (_navRoll >= _wMi24 + _wL39)         then {_capMode = "SUX"};
							if (_navRoll >= _wMi24 + _wL39 + _wSux) then {_capMode = "SKIRMISH"};
						} else {
							//--- MODE=0: byte-identical legacy precedence (CAP_L39 wins over THREE_HINDS; both read once
							//--- at thread start, line 680-681 - unchanged, never re-rolled, matching today's live behaviour).
							_capMode = "LEGACY";
							if (_threeHinds) then {_capMode = "MI24"};
							if (_capL39) then {_capMode = "L39"};
						};

						//--- SKIRMISH is additive spectacle, not a CAP replacement (owner: never leave the carrier bare for
						//--- a rare event) - resolve to the tunable base composition, then launch the intruder as its OWN
						//--- self-clean sub-thread (own group, own registry, own cooldown - WFBE_C_NAVAL_SKIRMISH_MAX_ACTIVE)
						//--- only while a mission-wide slot is free, so a saturated cap falls back to the base CAP silently
						//--- instead of dropping the arm event.
						if (_capMode == "SKIRMISH") then {
							_navSkirmishBase = missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_BASE_MODE", "MI24"];
							if !(_navSkirmishBase in ["MI24","L39","SUX"]) then {_navSkirmishBase = "MI24"};
							_navSkirmishMax = missionNamespace getVariable ["WFBE_C_NAVAL_SKIRMISH_MAX_ACTIVE", 1];
							_navSkirmishActive = missionNamespace getVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", 0];
							if (_navSkirmishActive < _navSkirmishMax) then {
								missionNamespace setVariable ["WFBE_NAVAL_SKIRMISH_ACTIVE", _navSkirmishActive + 1];
								[_loc, _pos] spawn WFBE_NavalCap_FNC_SpawnSkirmish;
								diag_log Format ["NAVALCAP|SKIRMISH|SPAWN|carrier=%1|baseMode=%2|activeCount=%3", _loc getVariable "name", _navSkirmishBase, _navSkirmishActive + 1];
							} else {
								diag_log Format ["NAVALCAP|SKIRMISH|SKIP|carrier=%1|reason=cap_saturated|activeCount=%2", _loc getVariable "name", _navSkirmishActive];
							};
							_capMode = _navSkirmishBase;
						};

						diag_log Format ["NAVALCAP|ROLL|carrier=%1|navMode=%2|weights=mi24:%3,l39:%4,sux:%5,skirmish:%6|picked=%7", _loc getVariable "name", _navMode, missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_MI24", 45], missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_L39", 40], missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_SUX", 8], missionNamespace getVariable ["WFBE_C_NAVAL_CAP_WEIGHT_SKIRMISH", 7], _capMode];
						["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP roll at %1 (mode=%2, picked=%3).", _loc getVariable "name", _navMode, _capMode]] Call WFBE_CO_FNC_LogContent;

						if (_capMode == "L39") then {
							//--- L39 CAP path (WFBE_C_NAVAL_CAP_L39 > 0): 2x L39_TK_EP1 jets.
							//--- Supersedes THREE_HINDS and Mi24/An2 when both flags are >0.
							//--- Fixed-wing MUST have setVelocity set at spawn - zero velocity
							//---   causes immediate stall-dive on A2 OA (no lift at t=0).
							//--- Config proof: arma2-co-config-reference/Config/CfgVehicles.txt
							//---   line 185835  class L39_TK_EP1 : L39_base
							_jetDir = random 360;

							_jet1 = createVehicle ["L39_TK_EP1", [(_pos select 0) + 300 * (sin _jetDir), (_pos select 1) + 300 * (cos _jetDir), 600], [], 0, "FLY"];
							_jet1 setPosASL [(_pos select 0) + 300 * (sin _jetDir), (_pos select 1) + 300 * (cos _jetDir), 600];
							_jet1 setDir _jetDir;
							_jet1 setVelocity [(sin _jetDir) * 90, (cos _jetDir) * 90, 0];
							_jet1 flyInHeight 550;
							_jetPilot1 = _capGrp createUnit [(missionNamespace getVariable ["WFBE_GUER_PILOT_CLASS", "GUE_Soldier"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
							if (isNil "_jetPilot1") then {_jetPilot1 = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"]};
							_jetPilot1 moveInDriver _jet1;
							_jetPilot1 doMove [(_pos select 0) + 800, (_pos select 1), 550]; //--- fable/l39-circuit: immediate order - waypointless fixed-wing AI pitches into the sea within seconds

							_jet2 = createVehicle ["L39_TK_EP1", [(_pos select 0) - 300 * (sin _jetDir), (_pos select 1) - 300 * (cos _jetDir), 650], [], 0, "FLY"];
							_jet2 setPosASL [(_pos select 0) - 300 * (sin _jetDir), (_pos select 1) - 300 * (cos _jetDir), 650];
							_jet2 setDir _jetDir;
							_jet2 setVelocity [(sin _jetDir) * 90, (cos _jetDir) * 90, 0];
							_jet2 flyInHeight 600;
							_jetPilot2 = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
							_jetPilot2 moveInDriver _jet2;
							_jetPilot2 doMove [(_pos select 0) - 800, (_pos select 1), 600];

							_capGrp setBehaviour "AWARE";
							_capGrp setCombatMode "RED";
							_capGrp setSpeedMode "FULL";

							//--- EASA randomisation: stamp wfbe_naval_easa_pending on hull.
							//--- Clients read it on EH_Init and call EASA_Equip themselves.
							if ((missionNamespace getVariable ["WFBE_C_NAVAL_EASA_RANDOM", 0]) > 0) then {
								_easaVehi = missionNamespace getVariable ["WFBE_EASA_Vehicles", []];
								_easaIdx = _easaVehi find "L39_TK_EP1";
								if (_easaIdx >= 0) then {
									_easaLoadouts = (missionNamespace getVariable ["WFBE_EASA_Loadouts", []]) select _easaIdx;
									_easaRandIdx = floor (random (count _easaLoadouts));
									_jet1 setVariable ["wfbe_naval_easa_pending", _easaRandIdx, true];
									_jet2 setVariable ["wfbe_naval_easa_pending", _easaRandIdx, true];
								};
							};

							//--- Tag both as CAP so GC/groupsGC don't reap them.
							_capGrp setVariable ["wfbe_naval_cap", true, true];
							_jet1 setVariable ["wfbe_naval_cap", true, true];
							_jet2 setVariable ["wfbe_naval_cap", true, true];

							["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP armed at %1 (2x L39_TK_EP1, easa_random=%2).", _loc getVariable "name", (missionNamespace getVariable ["WFBE_C_NAVAL_EASA_RANDOM", 0])]] Call WFBE_CO_FNC_LogContent;
						} else {
							if (_capMode == "MI24") then {
								//--- THREE-HIND path (WFBE_C_NAVAL_CAP_THREE_HINDS > 0): no An2.
								_hind = createVehicle ["Mi24_P", [(_pos select 0) + 200, (_pos select 1) + 200, 400], [], 0, "FLY"];
								_hind setPosASL [(_pos select 0) + 200, (_pos select 1) + 200, 400];
								_hindPilot = _capGrp createUnit [(missionNamespace getVariable ["WFBE_GUER_PILOT_CLASS", "GUE_Soldier"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
								if (isNil "_hindPilot") then {_hindPilot = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"]};
								_hindPilot moveInDriver _hind;
								_hind flyInHeight 350;

								_hind2 = createVehicle ["Mi24_P", [(_pos select 0) - 200, (_pos select 1) + 200, 400], [], 0, "FLY"];
								_hind2 setPosASL [(_pos select 0) - 200, (_pos select 1) + 200, 400];
								_hindPilot2 = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
								_hindPilot2 moveInDriver _hind2;
								_hind2 flyInHeight 350;

								_hind3 = createVehicle ["Mi24_P", [(_pos select 0) + 0, (_pos select 1) - 300, 400], [], 0, "FLY"];
								_hind3 setPosASL [(_pos select 0) + 0, (_pos select 1) - 300, 400];
								_hindPilot3 = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
								_hindPilot3 moveInDriver _hind3;
								_hind3 flyInHeight 350;

								_capGrp setBehaviour "AWARE";
								_capGrp setCombatMode "RED";
								_capGrp setSpeedMode "FULL";

								//--- Tag all three as CAP so GC/groupsGC don't reap them.
								_capGrp setVariable ["wfbe_naval_cap", true, true];
								_hind  setVariable ["wfbe_naval_cap", true, true];
								_hind2 setVariable ["wfbe_naval_cap", true, true];
								_hind3 setVariable ["wfbe_naval_cap", true, true];

								["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP armed at %1 (3x Mi-24).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
							} else {
								if (_capMode == "SUX") then {
									//--- SUX path (weighted-roll rare outcome, ~8%): 1x Su34, single pilot. No verified 2-seat/WSO
									//--- crew handling exists in-repo for Su34 (it sits in the single-pilot tier-5 class list
									//--- alongside A10/AV8B/L39_TK_EP1, never paired with gunner-seat logic) - mirrors the L39
									//--- single-pilot idiom exactly. Su35 does NOT exist in this A2:OA install (zero repo
									//--- matches) - Su34 is the only verified rare-heavyweight jet; never substitute Su35.
									//--- Aliased into _jet1/_jetPilot1 so it rides the EXISTING L39 circuit orbit/despawn code
									//--- verbatim (see the orbit/despawn dispatch below); _jet2/_jetPilot2 stay objNull (already
									//--- the thread-start default, line 677) - the circuit code is already null-safe on _jet2,
									//--- so a single-ship SUX composition needs no new guards there.
									//--- Fixed-wing MUST have setVelocity set at spawn - zero velocity causes an immediate
									//--- stall-dive on A2 OA (no lift at t=0), same as the L39/An2 spawns above.
									_jetDir = random 360;

									_jet1 = createVehicle ["Su34", [(_pos select 0) + 300 * (sin _jetDir), (_pos select 1) + 300 * (cos _jetDir), 700], [], 0, "FLY"];
									_jet1 setPosASL [(_pos select 0) + 300 * (sin _jetDir), (_pos select 1) + 300 * (cos _jetDir), 700];
									_jet1 setDir _jetDir;
									_jet1 setVelocity [(sin _jetDir) * 90, (cos _jetDir) * 90, 0];
									_jet1 flyInHeight 600;
									_jetPilot1 = _capGrp createUnit [(missionNamespace getVariable ["WFBE_GUER_PILOT_CLASS", "GUE_Soldier"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
									if (isNil "_jetPilot1") then {_jetPilot1 = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"]};
									_jetPilot1 moveInDriver _jet1;
									_jetPilot1 doMove [(_pos select 0) + 800, (_pos select 1), 600]; //--- fable/l39-circuit idiom: immediate order - waypointless fixed-wing AI pitches into the sea within seconds

									_capGrp setBehaviour "AWARE";
									_capGrp setCombatMode "RED";
									_capGrp setSpeedMode "FULL";

									//--- EASA randomisation: stamp wfbe_naval_easa_pending on hull (same opt-in as L39; silently
									//--- no-ops if Su34 is not in WFBE_EASA_Vehicles).
									if ((missionNamespace getVariable ["WFBE_C_NAVAL_EASA_RANDOM", 0]) > 0) then {
										_easaVehi = missionNamespace getVariable ["WFBE_EASA_Vehicles", []];
										_easaIdx = _easaVehi find "Su34";
										if (_easaIdx >= 0) then {
											_easaLoadouts = (missionNamespace getVariable ["WFBE_EASA_Loadouts", []]) select _easaIdx;
											_easaRandIdx = floor (random (count _easaLoadouts));
											_jet1 setVariable ["wfbe_naval_easa_pending", _easaRandIdx, true];
										};
									};

									//--- Tag as CAP so GC/groupsGC don't reap it.
									_capGrp setVariable ["wfbe_naval_cap", true, true];
									_jet1 setVariable ["wfbe_naval_cap", true, true];

									["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP armed at %1 (1x Su34, rare).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
								} else {
								//--- STANDARD path (WFBE_C_NAVAL_CAP_L39=0, THREE_HINDS=0): Hind + An2.
								//--- naval-air-spawn-easa FIX: An2 is fixed-wing. createVehicle ["FLY"]
								//---   gives zero velocity at t=0 -> stall-dive. Set forward speed.
								_hind = createVehicle ["Mi24_P", [(_pos select 0) + 200, (_pos select 1) + 200, 400], [], 0, "FLY"];
								_hind setPosASL [(_pos select 0) + 200, (_pos select 1) + 200, 400];
								_hindPilot = _capGrp createUnit [(missionNamespace getVariable ["WFBE_GUER_PILOT_CLASS", "GUE_Soldier"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
								if (isNil "_hindPilot") then {_hindPilot = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"]};
								_hindPilot moveInDriver _hind;
								_capGrp setBehaviour "AWARE";
								_capGrp setCombatMode "RED";
								_hind flyInHeight 350;
								_capGrp setSpeedMode "FULL";

								//--- Spawn An2 biplane at 600m altitude with forward velocity.
								_jetDir = random 360;
								_biplane = createVehicle ["An2_1_TK_CIV_EP1", [(_pos select 0) - 300, (_pos select 1) - 300, 600], [], 0, "FLY"];
								_biplane setPosASL [(_pos select 0) - 300, (_pos select 1) - 300, 600];
								_biplane setDir _jetDir;
								_biplane setVelocity [(sin _jetDir) * 60, (cos _jetDir) * 60, 0];
								_biplane flyInHeight 550;
								_biplPilot = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
								_biplPilot moveInDriver _biplane;

								//--- Tag both as CAP so GC/groupsGC don't reap them.
								_capGrp setVariable ["wfbe_naval_cap", true, true];
								_hind   setVariable ["wfbe_naval_cap", true, true];
								_biplane setVariable ["wfbe_naval_cap", true, true];

								["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP armed at %1 (Hind + An2, velocity-fixed).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
								}; //--- closes the SUX-vs-legacy else (fable/naval-cap-variety)
							};
						};
					};
				} else {
					//--- CAP is active — orbit the asset.
					_orbitAng = _orbitAng + 8;
					if (_capMode == "L39" || _capMode == "SUX") then {
						//--- fable/l39-circuit: carrier-circuit sea patrol (+ airfield leg every 3rd lap). Explicit Z.
						if (_routeI >= count _route) then {
							_lap = _lap + 1;
							_route = +_circuitPts;
							if (((_lap mod 3) == 0) && {count _airfieldPts > 0}) then {
								_route = _route + [_airfieldPts select ((floor (_lap / 3)) mod (count _airfieldPts))];
							};
							_routeI = 0;
						};
						_legPt = _route select _routeI;
						_circuitTimeout = _circuitTimeout + 10;
						if ((!isNull _jet1 && {alive _jet1} && {((getPosASL _jet1) distance _legPt) < 500}) || _circuitTimeout > 120) then {
							_routeI = _routeI + 1;
							_circuitTimeout = 0;
							if (_routeI < count _route) then {_legPt = _route select _routeI};
						};
						if (alive _jet1) then {_jetPilot1 doMove _legPt};
						if (alive _jet2) then {_jetPilot2 doMove [(_legPt select 0) + 300, (_legPt select 1) + 300, _legPt select 2]};
					} else {
						if (_capMode == "MI24") then {
							if (alive _hind)  then {_hindPilot  doMove [(_pos select 0) + 400 * sin _orbitAng,         (_pos select 1) + 400 * cos _orbitAng, 0]};
							if (alive _hind2) then {_hindPilot2 doMove [(_pos select 0) + 400 * sin (_orbitAng + 120), (_pos select 1) + 400 * cos (_orbitAng + 120), 0]};
							if (alive _hind3) then {_hindPilot3 doMove [(_pos select 0) + 400 * sin (_orbitAng + 240), (_pos select 1) + 400 * cos (_orbitAng + 240), 0]};
						} else {
							if (alive _hind) then {
								_hindPilot doMove [(_pos select 0) + 400 * sin _orbitAng, (_pos select 1) + 400 * cos _orbitAng, 0];
							};
							if (alive _biplane) then {
								_biplPilot doMove [(_pos select 0) + 700 * sin (_orbitAng + 180), (_pos select 1) + 700 * cos (_orbitAng + 180), 550]; //--- fable/l39-circuit: Z=0 = commanded descent for fixed-wing
							};
						};
					};
				};

			} else {
				//--- No player nearby: count down inactivity.
				if (_armed) then {
					_inactiveTime = _inactiveTime + 10;
					if (_inactiveTime >= 120) then {
						//--- Despawn CAP.
						_armed = false;
						_inactiveTime = 0;
						if (_capMode == "L39" || _capMode == "SUX") then {
							if (!isNull _jet1 && alive _jet1) then { {deleteVehicle _x} forEach (crew _jet1); deleteVehicle _jet1 };
							if (!isNull _jet2 && alive _jet2) then { {deleteVehicle _x} forEach (crew _jet2); deleteVehicle _jet2 };
						} else {
							if (_capMode == "MI24") then {
								if (!isNull _hind  && alive _hind)  then { {deleteVehicle _x} forEach (crew _hind);  deleteVehicle _hind };
								if (!isNull _hind2 && alive _hind2) then { {deleteVehicle _x} forEach (crew _hind2); deleteVehicle _hind2 };
								if (!isNull _hind3 && alive _hind3) then { {deleteVehicle _x} forEach (crew _hind3); deleteVehicle _hind3 };
							} else {
								if (!isNull _hind   && alive _hind)   then { {deleteVehicle _x} forEach (crew _hind);   deleteVehicle _hind };
								if (!isNull _biplane && alive _biplane) then { {deleteVehicle _x} forEach (crew _biplane); deleteVehicle _biplane };
							};
						};
						if (!isNull _capGrp) then { deleteGroup _capGrp };
						["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP despawned at %1 (inactivity).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		};
	};
} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];

//------------------------------------------------------------------------------------
//--- fable/naval-camps-on-deck (Ray 2026-07-07) CAMP + DEPOT DECK RESEAT.
//---
//--- Root cause: camp logics (LocationLogicCamp, synchronized to the town logic in
//---   mission.sqm) sit at sea level. Init_Town.sqf's Spawn block reads getPos on
//---   each camp logic and createVehicle/setPos the tent model + flag at that ATL
//---   position — on open water that resolves to z=0 (sea surface inside the hull).
//---   The naval town LOGIC is raised to deckZ (cmdcon41-w2) but the camp LOGICS
//---   are separate synchronized objects that stay at sea level.
//---
//--- Fix: for each naval town, spawn a bounded poll that waits until Init_Town has
//---   stored wfbe_camp_bunker on each camp logic (set ~line 129 of Init_Town, inside
//---   the serverInitComplete waitUntil block). Once the model ref exists re-seat the
//---   camp logic + model + flag to the deck. Depot model has no stored ref; find it
//---   via nearestObjects at the town logic's new deck position.
//---
//--- Body-space camp offsets (heading 90, ship faces east):
//---   Rotation: dx = bx*cos(dir)-by*sin(dir), dy = bx*sin(dir)+by*cos(dir)
//---   Camp 1 body [0, +42] -> world anchor + [-42,  0]  (42 m west, on deck)
//---   Camp 2 body [0, -72] -> world anchor + [+72,  0]  (72 m east, clear of SCUD@+50)
//---   Both within the ~250 m hull extent, clear of heli pad (body [0,-10]).
//---
//--- WFBE_C_NAVAL_CAMPS_DECK default 1 (owner-reported correctness fix, always-on).
//------------------------------------------------------------------------------------
if ((missionNamespace getVariable ["WFBE_C_NAVAL_CAMPS_DECK", 1]) > 0) then {
	private ["_campDeckOffsets"];
	//--- Body-space [bx, by] offsets for each camp slot on the flight deck.
	//--- Rotation: dx = bx*cos(dir)-by*sin(dir), dy = bx*sin(dir)+by*cos(dir).
	_campDeckOffsets = [[0, 42], [0, -72]];

	{
		private ["_navLogic","_navDeckZ","_navDir","_navAnchorX","_navAnchorY"];
		_navLogic   = _x;
		_navDeckZ   = _navLogic getVariable ["wfbe_naval_deckz", 15.9];
		_navDir     = getDir (_navLogic getVariable ["wfbe_naval_deckpart", _navLogic]); //--- fable/naval-deck-fixes: town logics carry azimut=0 in mission.sqm; the hull part carries the true heading (90) - rotation math was silently wrong for the (currently dead) synced-camps path
		_navAnchorX = (getPosASL _navLogic) select 0;
		_navAnchorY = (getPosASL _navLogic) select 1;

		[_navLogic, _navDeckZ, _navDir, _navAnchorX, _navAnchorY, _campDeckOffsets] spawn {
			private ["_loc","_deckZ","_dir","_ancX","_ancY","_offsets","_camps","_elapsed"];
			private ["_i","_off","_slotIdx","_bx","_by","_dx","_dy","_cx","_cy"];
			private ["_model","_flag","_flagPos","_depotCls","_depots","_depot","_elapsed2"];
			_loc     = _this select 0;
			_deckZ   = _this select 1;
			_dir     = _this select 2;
			_ancX    = _this select 3;
			_ancY    = _this select 4;
			_offsets = _this select 5;

			//--- Wait for Init_Town to publish the camps variable (line ~72 of Init_Town,
			//--- set before the Spawn block; camp models spawn later inside the Spawn block).
			_elapsed = 0;
			waitUntil {
				_elapsed = _elapsed + 2;
				sleep 2;
				(!isNil {_loc getVariable "camps"}) || (_elapsed >= 60)
			};
			_camps = _loc getVariable ["camps", []];

			if (count _camps == 0) exitWith {
				//--- fable/naval-deck-fixes: runtime carrier towns can NEVER receive camps from Init_Town -
				//--- camps come only from mission.sqm-synchronized LocationLogicCamp entities (Init_Town.sqf:59-72),
				//--- so the wait above always ends empty and every carrier shipped uncapturable (live RPT: "no camps
				//--- found after wait" x3). Build the full camp contract here instead: invisible-but-alive HeliHEmpty
				//--- stand-ins (the B754b hangar pattern above - consumers key on wfbe_camp_bunker/sideID variables,
				//--- not typeOf: see GUI_RespawnMenu.sqf:213), bunker model + flag + vars per Init_Town.sqf:105-136,
				//--- then start THIS town's server_town_camp FSM (Init_Town launched it with an empty array here).
				//--- Placement = deck-part MODEL space (heading-proof), port side, clear of the SCUD ([8,-14]).
				private ["_deckPart","_newCamps","_newFlags","_cOff","_cXY","_cLogic","_cModel","_cFlag","_cFlagPos","_campHealth","_townSideID","_townSV","_depotCls2","_depots2","_depot2"];
				_deckPart = _loc getVariable ["wfbe_naval_deckpart", objNull];
				if (isNull _deckPart) exitWith {
					diag_log Format ["NAVALHVT-CAMP: %1 no camps AND no deckpart ref; cannot build deck camps.", _loc getVariable ["name","?"]];
				};
				_townSideID = _loc getVariable ["sideID", WFBE_C_GUER_ID];
				_townSV = _loc getVariable ["supplyValue", 0];
				_newCamps = []; _newFlags = [];
				{
					_cOff = _x;
					_cXY = _deckPart modelToWorld _cOff;
					_cLogic = "HeliHEmpty" createVehicle [_cXY select 0, _cXY select 1, 0];
					_cLogic setDir (getDir _deckPart);
					_cLogic setPosASL [_cXY select 0, _cXY select 1, _deckZ];
					_cLogic allowDamage false;
					_cLogic setVariable ["town", _loc];
					_cLogic setVariable ["sideID", _townSideID, true];
					_cLogic setVariable ["supplyValue", _townSV, true];
					_cModel = createVehicle [missionNamespace getVariable "WFBE_C_CAMP", [_cXY select 0, _cXY select 1, 0], [], 0, "NONE"];
					_cModel setDir ((getDir _cLogic) + (missionNamespace getVariable "WFBE_C_CAMP_RDIR"));
					_cModel setPosASL [_cXY select 0, _cXY select 1, _deckZ];
					_campHealth = missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF";
					if !(isNil '_campHealth') then {
						_cModel addEventHandler ["handleDamage",{getDammage (_this select 0)+((_this select 2)/(missionNamespace getVariable "WFBE_C_CAMP_HEALTH_COEF"))}];
					};
					_cFlag = createVehicle [missionNamespace getVariable "WFBE_C_CAMP_FLAG", [_cXY select 0, _cXY select 1, 0], [], 0, "NONE"];
					_cFlagPos = _cLogic modelToWorld (missionNamespace getVariable ["WFBE_C_CAMP_FLAG_POS", [-5, 5]]);
					_cFlag setPosASL [_cFlagPos select 0, _cFlagPos select 1, _deckZ];
					_cLogic setVariable ["wfbe_flag", _cFlag];
					_cLogic setVariable ["wfbe_camp_bunker", _cModel, true];
					_newCamps = _newCamps + [_cLogic];
					_newFlags = _newFlags + [_cFlag];
				} forEach [[-10, 18, 0], [-10, -18, 0]];
				_loc setVariable ["camps", _newCamps, true];
				[_newCamps, _loc, _newFlags] execVM "Server\FSM\server_town_camp.sqf";
				diag_log Format ["NAVALHVT-CAMP: %1 built %2 deck camps at deckZ=%3 (runtime town, no sqm camps); camp FSM started.", _loc getVariable ["name","?"], count _newCamps, _deckZ];
				//--- Depot reseat (duplicated from the synced-camps path below, which this exitWith skips).
				_depotCls2 = missionNamespace getVariable ["WFBE_C_DEPOT", ""];
				if (_depotCls2 != "") then {
					_depots2 = nearestObjects [getPosASL _loc, [_depotCls2], 50];
					if (count _depots2 == 1) then {
						_depot2 = _depots2 select 0;
						_depot2 setPosASL [_ancX, _ancY, _deckZ];
						diag_log Format ["NAVALHVT-CAMP: %1 depot reseated to [%2,%3,%4]", _loc getVariable ["name","?"], _ancX, _ancY, _deckZ];
					};
				};
			};

			//--- Re-seat each camp logic, then wait for the tent model (wfbe_camp_bunker)
			//--- to be spawned by Init_Town before moving the model + flag.
			_i = 0;
			{
				private ["_campLogic","_slotIdx","_off","_bx","_by","_dx","_dy","_cx","_cy"];
				private ["_model","_flag","_flagPos","_elapsed2"];
				_campLogic = _x;

				//--- Compute deck-space world position for this camp slot.
				_slotIdx = _i;
				if (_slotIdx >= count _offsets) then { _slotIdx = (count _offsets) - 1 };
				_off = _offsets select _slotIdx;
				_bx  = _off select 0;
				_by  = _off select 1;
				_dx  = _bx * (cos _dir) - _by * (sin _dir);
				_dy  = _bx * (sin _dir) + _by * (cos _dir);
				_cx  = _ancX + _dx;
				_cy  = _ancY + _dy;

				//--- Re-seat the LOGIC first (models that spawn AFTER will use getPos of the logic).
				_campLogic setPosASL [_cx, _cy, _deckZ];

				//--- Wait for tent model (wfbe_camp_bunker) to be spawned by Init_Town.
				_elapsed2 = 0;
				waitUntil {
					_elapsed2 = _elapsed2 + 2;
					sleep 2;
					(!isNil {_campLogic getVariable "wfbe_camp_bunker"}) || (_elapsed2 >= 60)
				};

				_model = _campLogic getVariable ["wfbe_camp_bunker", objNull];
				if (!isNull _model) then {
					_model setPosASL [_cx, _cy, _deckZ];
					//--- Re-seat flag (wfbe_flag stored on camp logic by Init_Town).
					_flag = _campLogic getVariable ["wfbe_flag", objNull];
					if (!isNull _flag) then {
						//--- Replicate Init_Town's modelToWorld flag offset from the now-reseated logic.
						_flagPos = _campLogic modelToWorld (missionNamespace getVariable ["WFBE_C_CAMP_FLAG_POS", [-5, 5]]);
						_flag setPosASL [_flagPos select 0, _flagPos select 1, _deckZ];
					};
					diag_log Format ["NAVALHVT-CAMP: %1 camp %2 reseated to [%3,%4,%5] deckZ=%6", _loc getVariable ["name","?"], _i, _cx, _cy, _deckZ, _deckZ];
				} else {
					diag_log Format ["NAVALHVT-CAMP: %1 camp %2 tent model nil after 60s; logic reseated, model skipped.", _loc getVariable ["name","?"], _i];
				};
				_i = _i + 1;
			} forEach _camps;

			//--- DEPOT reseat: no stored ref; find via nearestObjects at the logic's deck position.
			//--- Guard: only act if exactly one depot-class object within 50 m (prevents touching
			//--- land-town depots if the search ever reaches them — it won't, but defensive).
			_depotCls = missionNamespace getVariable ["WFBE_C_DEPOT", ""];
			if (_depotCls != "") then {
				_depots = nearestObjects [getPosASL _loc, [_depotCls], 50];
				if (count _depots == 1) then {
					_depot = _depots select 0;
					_depot setPosASL [_ancX, _ancY, _deckZ];
					diag_log Format ["NAVALHVT-CAMP: %1 depot reseated to [%2,%3,%4] deckZ=%5", _loc getVariable ["name","?"], _ancX, _ancY, _deckZ, _deckZ];
				};
			};
		};
	} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];
};

["INITIALIZATION", "Init_NavalHVT.sqf : All naval HVT assets spawned + CAP loops started."] Call WFBE_CO_FNC_LogContent;
