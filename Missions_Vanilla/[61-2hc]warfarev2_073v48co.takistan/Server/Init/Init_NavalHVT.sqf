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
	_obj setPosASL [_pos select 0, _pos select 1, 0];	//--- ASL = sea surface, not seabed
	_obj setDir _dir;
	_obj enableSimulation false;
	_obj allowDamage false;
	_obj
};

//------------------------------------------------------------------------------------
//--- A2's LHD is 9 part-objects placed at the SAME world point; the model geometry holds the
//--- ~250 m layout internally (confirmed via the stock BIS createLHD + community assembly
//--- scripts). Spreading them with offsets is what made it look like several carriers stacked.
//--- Land_LHD_elev_L / Land_LHD_house_2_CP are not part of the standard set -> dropped.
WFBE_C_NAVAL_LHD_OFFSETS = [
	["Land_LHD_1",       [0, 0, 0]],
	["Land_LHD_2",       [0, 0, 0]],
	["Land_LHD_3",       [0, 0, 0]],
	["Land_LHD_4",       [0, 0, 0]],
	["Land_LHD_5",       [0, 0, 0]],
	["Land_LHD_6",       [0, 0, 0]],
	["Land_LHD_house_1", [0, 0, 0]],
	["Land_LHD_house_2", [0, 0, 0]],
	["Land_LHD_elev_R",  [0, 0, 0]]
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
diag_log Format ["NAVALHVT-DECK: Khe Sanh Charlie partpos=%1 bbMin=%2 bbMax=%3 deckZ=%4", getPosASL _deckPart, _bb select 0, _bb select 1, _deckZ];

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [C] Khe Sanh Charlie (LHD) spawned at %1.", _aCharlie]] Call WFBE_CO_FNC_LogContent;

//--- SCUD pad on Charlie's deck (addAction proximity reference).
_scudPad = createVehicle ["HeliHCivil", [_aCharlie select 0, _aCharlie select 1, 0], [], 0, "NONE"];
_scudPad setPosASL [_aCharlie select 0, _aCharlie select 1, 16];
_scudPad enableSimulation false;
_scudPad allowDamage false;
_scudPad setVariable ["wfbe_is_scud_pad", true, true];
_lhdCharlieLogic setVariable ["wfbe_scud_pad_ref", _scudPad, true];
missionNamespace setVariable ["WFBE_NAVAL_HVT_PLATFORMS", [_lhdCharlieLogic]];

//--- SCUD ADDACTION on Charlie's deck. Only team-leaders of the owning side near the pad see it.
[_lhdCharlieLogic, _scudPad] spawn {
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
private ["_scudModel"];
_scudModel = createVehicle ["MAZ_543_SCUD_TK_EP1", [(_aCharlie select 0) + 50, _aCharlie select 1, 0], [], 0, "NONE"];
_scudModel setPosASL [(_aCharlie select 0) + 50, _aCharlie select 1, 16];
_scudModel setDir 90;
_scudModel allowDamage false;
[_scudModel, (_aCharlie select 0) + 50, (_aCharlie select 1)] spawn {
	private ["_s","_px","_py"];
	_s  = _this select 0;
	_px = _this select 1;
	_py = _this select 2;
	_s action ["scudLaunch", _s];	//--- raise the missile to vertical
	sleep 6;						//--- let the erect animation finish
	_s setPosASL [_px, _py, 16];	//--- correct any physics drift during the erect
	_s setVectorUp [0,0,1];			//--- re-level the launcher
	_s enableSimulation false;		//--- freeze it static (erect)
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
		         "_inactiveTime","_now","_detected","_players","_anyNear","_orbitAng","_dummy","_x"];
		_loc  = _this select 0;
		_armed = false;
		_inactiveTime = 0;
		_orbitAng = random 360;

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

						//--- Spawn Hind gunship at 400m altitude north of asset.
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
				} else {
					//--- CAP is active — orbit the asset.
					_orbitAng = _orbitAng + 8;
					if (alive _hind) then {
						_hindPilot doMove [(_pos select 0) + 400 * sin _orbitAng, (_pos select 1) + 400 * cos _orbitAng, 0];
					};
					if (alive _biplane) then {
						_biplPilot doMove [(_pos select 0) + 700 * sin (_orbitAng + 180), (_pos select 1) + 700 * cos (_orbitAng + 180), 0];
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
						if (!isNull _hind   && alive _hind)   then { {deleteVehicle _x} forEach (crew _hind);   deleteVehicle _hind };
						if (!isNull _biplane && alive _biplane) then { {deleteVehicle _x} forEach (crew _biplane); deleteVehicle _biplane };
						if (!isNull _capGrp) then { deleteGroup _capGrp };
						["INFORMATION", Format ["Init_NavalHVT.sqf : GUER CAP despawned at %1 (inactivity).", _loc getVariable "name"]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		};
	};
} forEach [_lhdAlphaLogic, _lhdBravoLogic, _lhdCharlieLogic];

["INITIALIZATION", "Init_NavalHVT.sqf : All naval HVT assets spawned + CAP loops started."] Call WFBE_CO_FNC_LogContent;
