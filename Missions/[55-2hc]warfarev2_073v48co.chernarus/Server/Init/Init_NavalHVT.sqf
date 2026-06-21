//--- Init_NavalHVT.sqf — Naval HVT Objectives orchestrator.
//--- Called once from Init_Server.sqf, guarded by WFBE_C_NAVAL_HVT.
//--- Creates 4 offshore capturable HVTs on Chernarus east coast, defaulting to GUER ownership.
//---
//--- Assets:
//---   [A] Khe Sanh Alpha (LHD)  — NE sea        — carrier, aircraft sell
//---   [B] Pier / FOB            — E sea (upper)  — forward base, fast respawn
//---   [C] Oil Platform (SCUD)   — E sea (mid)    — SCUD strike unlock
//---   [D] Khe Sanh Bravo (LHD)  — SE sea         — carrier, aircraft sell
//--- (exact anchors below; all surfaceIsWater-validated, spread along the east coast)
//---
//--- IMPORTANT NOTES:
//---   • setPosASL is used throughout for sea objects (NOT setPos/setPosATL which snap to seabed).
//---   • All createVehicle calls are GLOBAL (server-authoritative, so AI/collision sees them).
//---   • Town logics are PRE-PLACED in mission.sqm and registered by Init_Town.sqf before this runs.
//---   • The GUER CAP (Mi24_P + An2) is PROXIMITY-GATED: only arms at ~1500-2000m player range
//---     and despawns on the inactivity timeout — never burns FPS over empty ocean.
//---   • The SCUD addAction is added to the oil platform helipad for any team-leader of the
//---     owning side; the server validates ownership + cooldown before firing.
//---
//--- NEEDS REVIEW (see agent report):
//---   • LHD multi-part hull relative offsets are BEST-GUESS linear fore-to-aft — must be
//---     verified and adjusted in-engine.
//---   • Candidate coordinates must be confirmed with surfaceIsWater in-engine.
//---   • Air-sell integration requires WFBE_GUERAIRPORTUNITS vs WFBE_GUEAIRPORTUNITS typo fix
//---     (noted in SPEC; not fixed here to stay in scope).

if (!isServer) exitWith {};
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
//--- LHD Hull: multi-part ship. Parts are laid linearly fore-to-aft.
//--- !! TODO / NEEDS-REVIEW: these offsets are BEST-GUESS fore-to-aft linear layout —
//--- the exact relative offsets require in-engine fitting (no on-disk reference found).
//--- Flag this in your review before deploying. Each section is ~20-25m long.
WFBE_C_NAVAL_LHD_OFFSETS = [
	["Land_LHD_1",  [  0,   0, 0]],	//--- bow section
	["Land_LHD_2",  [  0,  22, 0]],	//--- forward hull
	["Land_LHD_3",  [  0,  44, 0]],	//--- mid-forward hull
	["Land_LHD_4",  [  0,  66, 0]],	//--- mid-aft hull
	["Land_LHD_5",  [  0,  88, 0]],	//--- aft hull
	["Land_LHD_6",  [  0, 110, 0]],	//--- stern
	["Land_LHD_elev_L",  [-12,  44, 0]],	//--- port elevator
	["Land_LHD_elev_R",  [ 12,  44, 0]],	//--- starboard elevator
	["Land_LHD_house_1",   [  8,  80, 0]],	//--- island base
	["Land_LHD_house_2",   [  8,  88, 0]],	//--- island mid
	["Land_LHD_house_2_CP",[ 8,  96, 0]]	//--- island bridge/CP
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
//--- The 4 naval logics are pre-placed in mission.sqm and already registered in
//--- towns[] by Init_Town.sqf. Locate them by their name variable.
//------------------------------------------------------------------------------------
private ["_lhdAlphaLogic","_pierFOBLogic","_oilLogic","_lhdBravoLogic","_x","_tName"];
_lhdAlphaLogic = objNull;
_pierFOBLogic  = objNull;
_oilLogic      = objNull;
_lhdBravoLogic = objNull;

{
	_tName = _x getVariable ["name", ""];
	switch (_tName) do {
		case "Khe Sanh Alpha": { _lhdAlphaLogic = _x; };
		case "Naval FOB":      { _pierFOBLogic  = _x; };
		case "Oil Platform":   { _oilLogic      = _x; };
		case "Khe Sanh Bravo": { _lhdBravoLogic = _x; };
	};
} forEach towns;

if (isNull _lhdAlphaLogic || isNull _pierFOBLogic || isNull _oilLogic || isNull _lhdBravoLogic) exitWith {
	["WARNING", "Init_NavalHVT.sqf : pre-placed naval town logic(s) not found in towns[] — check mission.sqm."] Call WFBE_CO_FNC_LogContent;
};

//--- Force sea level (z=0 ASL) on each logic for accurate capture-radius detection.
_lhdAlphaLogic setPosASL [(getPos _lhdAlphaLogic) select 0, (getPos _lhdAlphaLogic) select 1, 0];
_pierFOBLogic  setPosASL [(getPos _pierFOBLogic)  select 0, (getPos _pierFOBLogic)  select 1, 0];
_oilLogic      setPosASL [(getPos _oilLogic)       select 0, (getPos _oilLogic)       select 1, 0];
_lhdBravoLogic setPosASL [(getPos _lhdBravoLogic) select 0, (getPos _lhdBravoLogic) select 1, 0];

//--- Sanity: diag_log (always hits the RPT) a WARN if any town logic is NOT over water,
//--- so a bad mission.sqm coord (on land) is caught server-side without a visual check.
{
	if (!(surfaceIsWater (getPos _x))) then {
		diag_log Format ["NAVALHVT-WARN: town [%1] is NOT over water at %2 - fix mission.sqm coord.", _x getVariable ["name","?"], getPos _x];
	};
} forEach [_lhdAlphaLogic, _pierFOBLogic, _oilLogic, _lhdBravoLogic];

//--- Derive 2-element [x,y] anchors from logic positions (downstream structure code uses these
//--- with WFBE_NavalHVT_Off, which reads select 0 / select 1, so must remain [x,y]).
private ["_aAlpha","_aFOB","_aOil","_aBravo"];
_aAlpha = [(getPos _lhdAlphaLogic) select 0, (getPos _lhdAlphaLogic) select 1];
_aFOB   = [(getPos _pierFOBLogic)  select 0, (getPos _pierFOBLogic)  select 1];
_aOil   = [(getPos _oilLogic)       select 0, (getPos _oilLogic)       select 1];
_aBravo = [(getPos _lhdBravoLogic) select 0, (getPos _lhdBravoLogic) select 1];

//------------------------------------------------------------------------------------
//--- NAME LABELS — sea towns have no built-in map label, so add a global text marker per
//--- town (the SV text comes from updatetownmarkers.sqf on the CityMarker). Offset N so the
//--- name does not sit on top of the SV readout.
//------------------------------------------------------------------------------------
private ["_nmI","_nmLoc","_nmName","_nmP","_nmMkr"];
_nmI = 0;
{
	_nmLoc  = _x select 0;
	_nmName = _x select 1;
	_nmP    = getPos _nmLoc;
	_nmMkr  = createMarker [Format ["WFBE_NavalName_%1", _nmI], [(_nmP select 0), (_nmP select 1) + 160, 0]];
	_nmMkr setMarkerType "Empty";
	_nmMkr setMarkerColor "ColorBlack";
	_nmMkr setMarkerText _nmName;
	_nmI = _nmI + 1;
} forEach [[_lhdAlphaLogic, "Khe Sanh Alpha"], [_pierFOBLogic, "Naval FOB"], [_oilLogic, "Oil Platform"], [_lhdBravoLogic, "Khe Sanh Bravo"]];

//------------------------------------------------------------------------------------
//--- SPAWN ALL 4 ASSETS
//------------------------------------------------------------------------------------
private ["_lhdAlpha","_lhdAlphaParts","_lhdBravoParts",
         "_pierObj","_oilDeck1","_oilDeck2","_oilPump","_oilTower","_oilPad",
         "_i","_pad","_pierClasses","_pierI","_pierCls"];

//---
//--- [A] KHE SANH ALPHA (LHD) — NE
//---
_lhdAlphaParts = [[_aAlpha select 0, _aAlpha select 1, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

//--- Heli spawn pad on the deck.
_pad = createVehicle ["HeliHCivil", ([_aAlpha, 10, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_pad setPosASL ([_aAlpha, 10, 0] Call WFBE_NavalHVT_Off);
_pad enableSimulation false;
_pad allowDamage false;

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [A] Khe Sanh Alpha (LHD) spawned at %1.", _aAlpha]] Call WFBE_CO_FNC_LogContent;

//---
//--- [B] PIER / FOB
//--- A2-safe: no _forEachIndex; use for-loop with index counter.
//---
_pierClasses = ["Land_Nav_Boathouse", "Land_Nav_Boathouse_Pier", "Land_Nav_Boathouse_PierL", "Land_Nav_Boathouse_PierR", "Land_Nav_Boathouse_PierT"];
for "_pierI" from 0 to (count _pierClasses - 1) do {
	_pierCls = _pierClasses select _pierI;
	_pierObj = createVehicle [_pierCls, ([_aFOB, (_pierI * 8), 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
	_pierObj setPosASL ([_aFOB, (_pierI * 8), 0] Call WFBE_NavalHVT_Off);
	_pierObj setDir 90;
	_pierObj enableSimulation false;
	_pierObj allowDamage false;
};

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [B] Naval FOB (Pier) spawned at %1.", _aFOB]] Call WFBE_CO_FNC_LogContent;

//---
//--- [C] OIL PLATFORM — SCUD unlock
//---
_oilDeck1 = createVehicle ["Land_Ind_BoardsPack1", ([_aOil, 0, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_oilDeck1 setPosASL ([_aOil, 0, 0] Call WFBE_NavalHVT_Off);
_oilDeck1 enableSimulation false;
_oilDeck1 allowDamage false;

_oilDeck2 = createVehicle ["Land_Ind_BoardsPack2", ([_aOil, 5, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_oilDeck2 setPosASL ([_aOil, 5, 0] Call WFBE_NavalHVT_Off);
_oilDeck2 enableSimulation false;
_oilDeck2 allowDamage false;

_oilPump = createVehicle ["Land_Ind_Oil_Pump_EP1", ([_aOil, 8, 5] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_oilPump setPosASL ([_aOil, 8, 5] Call WFBE_NavalHVT_Off);
_oilPump enableSimulation false;
_oilPump allowDamage false;

_oilTower = createVehicle ["Land_Ind_Oil_Tower_EP1", ([_aOil, -5, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_oilTower setPosASL ([_aOil, -5, 0] Call WFBE_NavalHVT_Off);
_oilTower enableSimulation false;
_oilTower allowDamage false;

//--- Helipad on the oil platform — SCUD addAction goes here.
_oilPad = createVehicle ["HeliHCivil", ([_aOil, 0, -5] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_oilPad setPosASL ([_aOil, 0, -5] Call WFBE_NavalHVT_Off);
_oilPad enableSimulation false;
_oilPad allowDamage false;
_oilPad setVariable ["wfbe_is_scud_pad", true, true];
_oilLogic setVariable ["wfbe_scud_pad_ref", _oilPad, true];

//--- Register oil platform in global SCUD-platform list (validated in Support_ScudStrike.sqf).
missionNamespace setVariable ["WFBE_NAVAL_HVT_PLATFORMS", [_oilLogic]];

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [C] Oil Platform (SCUD) spawned at %1.", _aOil]] Call WFBE_CO_FNC_LogContent;

//---
//--- [D] KHE SANH BRAVO (LHD) — SE
//---
_lhdBravoParts = [[_aBravo select 0, _aBravo select 1, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

_pad = createVehicle ["HeliHCivil", ([_aBravo, 10, 0] Call WFBE_NavalHVT_Off), [], 0, "NONE"];
_pad setPosASL ([_aBravo, 10, 0] Call WFBE_NavalHVT_Off);
_pad enableSimulation false;
_pad allowDamage false;

["INITIALIZATION", Format ["Init_NavalHVT.sqf : [D] Khe Sanh Bravo (LHD) spawned at %1.", _aBravo]] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- STORE ALL NAVAL HVT LOGICS for server_town.sqf capture-block lookup.
//------------------------------------------------------------------------------------
missionNamespace setVariable ["WFBE_NAVAL_HVT_LOGICS", [_lhdAlphaLogic, _pierFOBLogic, _oilLogic, _lhdBravoLogic]];

//------------------------------------------------------------------------------------
//--- SCUD ADDACTION on oil platform helipad.
//--- Only team-leaders of the OWNING side see it; server validates everything.
//--- NEEDS REVIEW: addAction on a simulation-off object may be invisible in some client
//--- configurations — if so, add action to the oilLogic entity or use a trigger instead.
//------------------------------------------------------------------------------------
[_oilLogic, _oilPad] spawn {
	private ["_loc","_pad","_sideID","_ownerSide","_actionID","_playerSide","_team","_isLeader","_pSideID","_x"];
	_loc = _this select 0;
	_pad = _this select 1;

	//--- Re-check every 15s and refresh the addAction if ownership changed.
	while { !WFBE_GameOver } do {
		sleep 15;

		_sideID    = _loc getVariable ["sideID", WFBE_C_GUER_ID];
		_ownerSide = _sideID Call WFBE_CO_FNC_GetSideFromID;

		//--- Add SCUD action for all team-leaders of the owning side who are near the pad.
		{
			_x = _x;
			if (isPlayer _x && {alive _x} && {(side _x) == _ownerSide} && {(_x distance _pad) < 50}) then {
				_team = group _x;
				_isLeader = (_x == leader _team);
				if (_isLeader) then {
					//--- Check if they already have the action (by tag variable).
					if (isNil {_x getVariable "wfbe_scud_action_armed"}) then {
						_x setVariable ["wfbe_scud_action_armed", true];
						_actionID = _x addAction [
							localize "STR_WF_SCUD_ACTION",
							{
								//--- Action code: open map-click for target select, then send to server.
								private ["_caller","_cost","_funds"];
								_caller = _this select 1;
								_cost   = WFBE_C_SCUD_COST;
								_funds  = (group _caller) getVariable ["wfbe_funds", 0];
								if (_funds < _cost) exitWith {
									[localize "STR_WF_SCUD_NO_FUNDS"] call WFBE_CL_FNC_Hint;
								};
												//--- Map-click target select; the SERVER deducts funds + re-validates ownership/cooldown.
									[localize "STR_WF_SCUD_SELECT_TARGET"] call WFBE_CL_FNC_Hint;
									openMap true;
									onMapSingleClick {
										onMapSingleClick {};
										openMap false;
										["RequestSpecial", ["ScudStrike", playerSide, _pos, group player]] Call WFBE_CO_FNC_SendToServer;
										[localize "STR_WF_SCUD_LAUNCHED"] call WFBE_CL_FNC_Hint;
										false
									};
							},
							[], 6, true, true, "", "alive _target && isPlayer _this"
						];
					};
				};
			};
		} forEach playableUnits;
	};
};

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
} forEach [_lhdAlphaLogic, _pierFOBLogic, _oilLogic, _lhdBravoLogic];

["INITIALIZATION", "Init_NavalHVT.sqf : All naval HVT assets spawned + CAP loops started."] Call WFBE_CO_FNC_LogContent;
