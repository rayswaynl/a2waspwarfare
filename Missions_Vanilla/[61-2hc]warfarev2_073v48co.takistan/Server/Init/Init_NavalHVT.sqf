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
//---   • setPosASL is used throughout for sea objects (NOT setPos/setPosATL which snap to seabed).
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
	_obj setPosASL [_pos select 0, _pos select 1, 0];	//--- ASL = sea surface, not seabed
	_obj setDir _dir;
	_obj enableSimulation false;
	_obj allowDamage false;
	_obj
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

		_obj = [_cls, [_px, _py, 0]] Call WFBE_NavalHVT_SpawnProp;
		_obj setDir _dir;
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
_pad setPosASL ([_aAlpha, 10, 0] Call WFBE_NavalHVT_Off);
_pad enableSimulation false;
_pad allowDamage false;

//--- Deck-Z query: find the top-of-hull Z for spawn/teleport callers.
_deckPart = _lhdAlphaParts select 3;
_bb = boundingBox _deckPart; //--- B754 (Ray 2026-06-25): measure the REAL deck height (was a hardcoded 16 guess) so deck-respawned players land on the flight deck, not clipping the hull / falling into the sea. boundingBox is A2-OA 1.64-safe.
_deckZ = (getPosASL _deckPart select 2) + ((_bb select 1) select 2);
_lhdAlphaLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
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
_pad setPosASL ([_aBravo, 10, 0] Call WFBE_NavalHVT_Off);
_pad enableSimulation false;
_pad allowDamage false;

//--- Deck-Z query: find the top-of-hull Z for spawn/teleport callers.
_deckPart = _lhdBravoParts select 3;
_bb = boundingBox _deckPart; //--- B754 (Ray 2026-06-25): measure the REAL deck height (was a hardcoded 16 guess) so deck-respawned players land on the flight deck, not clipping the hull / falling into the sea. boundingBox is A2-OA 1.64-safe.
_deckZ = (getPosASL _deckPart select 2) + ((_bb select 1) select 2);
_lhdBravoLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
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
_deckZ = (getPosASL _deckPart select 2) + ((_bb select 1) select 2);
_lhdCharlieLogic setVariable ["wfbe_naval_deckz", _deckZ, true];
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
_scudPad setPosASL [_scudAnchor select 0, _scudAnchor select 1, _scudDeckZ];	//--- cmdcon41-w2 (Ray 2026-07-02): true deck height (was hardcoded 16, below the ~22m deck).
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
			if (isPlayer _x && {alive _x} && {(side _x) == _ownerSide} && {(_x distance _pad) < 50}) then {
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
_scudModel = createVehicle ["MAZ_543_SCUD_TK_EP1", [(_scudAnchor select 0) + 50, _scudAnchor select 1, 0], [], 0, "NONE"];
_scudModel setPosASL [(_scudAnchor select 0) + 50, _scudAnchor select 1, _scudDeckZ];
_scudModel setDir 90;
_scudModel allowDamage false;
//--- cmdcon41 SCUD THEATRICS (feature 1, Ray 2026-07-02): store the deck SCUD launcher on the platform logic so
//--- Support_ScudStrike.sqf can find the firing carrier's launcher and play the erect/backblast at launch. The
//--- platform logic == the single entry stored in WFBE_NAVAL_HVT_PLATFORMS above (the object ScudStrike validates
//--- ownership on), so a strike resolves its launcher with one getVariable. Broadcast so any locality can read it.
_scudLogic setVariable ["wfbe_hvt_scud", _scudModel, true];
[_scudModel, (_scudAnchor select 0) + 50, (_scudAnchor select 1), _scudDeckZ, _scudDeckPart] spawn {
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
		         "_threeHinds","_hind2","_hind3","_hindPilot2","_hindPilot3"];
		_loc  = _this select 0;
		_armed = false;
		_inactiveTime = 0;
		_orbitAng = random 360;
		_threeHinds = (missionNamespace getVariable ["WFBE_C_NAVAL_CAP_THREE_HINDS", 0]) > 0;

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

						if (_threeHinds) then {
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
							//--- STANDARD path (flag 0): Hind + An2 pair (default).
							_hind = createVehicle ["Mi24_P", [(_pos select 0) + 200, (_pos select 1) + 200, 400], [], 0, "FLY"];
							_hind setPosASL [(_pos select 0) + 200, (_pos select 1) + 200, 400];
							_hindPilot = _capGrp createUnit [(missionNamespace getVariable ["WFBE_GUER_PILOT_CLASS", "GUE_Soldier"]), [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
							if (isNil "_hindPilot") then {_hindPilot = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"]};
							_hindPilot moveInDriver _hind;
							_capGrp setBehaviour "AWARE";
							_capGrp setCombatMode "RED";
							_hind flyInHeight 350;
							_capGrp setSpeedMode "FULL";

							//--- Spawn An2 biplane at 600m altitude.
							_biplane = createVehicle ["An2_1_TK_CIV_EP1", [(_pos select 0) - 300, (_pos select 1) - 300, 600], [], 0, "FLY"];
							_biplane setPosASL [(_pos select 0) - 300, (_pos select 1) - 300, 600];
							_biplPilot = _capGrp createUnit ["GUE_Soldier", [_pos select 0, _pos select 1, 0], [], 0, "NONE"];
							_biplPilot moveInDriver _biplane;
							_biplane flyInHeight 550;

							//--- Tag both as CAP so GC/groupsGC don't reap them.
							_capGrp setVariable ["wfbe_naval_cap", true, true];
							_hind   setVariable ["wfbe_naval_cap", true, true];
							_biplane setVariable ["wfbe_naval_cap", true, true];

							["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP armed at %1 (Hind + An2).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
						};
					};
				} else {
					//--- CAP is active — orbit the asset.
					_orbitAng = _orbitAng + 8;
					if (_threeHinds) then {
						if (alive _hind)  then {_hindPilot  doMove [(_pos select 0) + 400 * sin _orbitAng,         (_pos select 1) + 400 * cos _orbitAng, 0]};
						if (alive _hind2) then {_hindPilot2 doMove [(_pos select 0) + 400 * sin (_orbitAng + 120), (_pos select 1) + 400 * cos (_orbitAng + 120), 0]};
						if (alive _hind3) then {_hindPilot3 doMove [(_pos select 0) + 400 * sin (_orbitAng + 240), (_pos select 1) + 400 * cos (_orbitAng + 240), 0]};
					} else {
						if (alive _hind) then {
							_hindPilot doMove [(_pos select 0) + 400 * sin _orbitAng, (_pos select 1) + 400 * cos _orbitAng, 0];
						};
						if (alive _biplane) then {
							_biplPilot doMove [(_pos select 0) + 700 * sin (_orbitAng + 180), (_pos select 1) + 700 * cos (_orbitAng + 180), 0];
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
						if (_threeHinds) then {
							if (!isNull _hind  && alive _hind)  then { {deleteVehicle _x} forEach (crew _hind);  deleteVehicle _hind };
							if (!isNull _hind2 && alive _hind2) then { {deleteVehicle _x} forEach (crew _hind2); deleteVehicle _hind2 };
							if (!isNull _hind3 && alive _hind3) then { {deleteVehicle _x} forEach (crew _hind3); deleteVehicle _hind3 };
						} else {
							if (!isNull _hind   && alive _hind)   then { {deleteVehicle _x} forEach (crew _hind);   deleteVehicle _hind };
							if (!isNull _biplane && alive _biplane) then { {deleteVehicle _x} forEach (crew _biplane); deleteVehicle _biplane };
						};
						if (!isNull _capGrp) then { deleteGroup _capGrp };
						["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP despawned at %1 (inactivity).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		};
	};
} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];

["INITIALIZATION", "Init_NavalHVT.sqf : All naval HVT assets spawned + CAP loops started."] Call WFBE_CO_FNC_LogContent;
