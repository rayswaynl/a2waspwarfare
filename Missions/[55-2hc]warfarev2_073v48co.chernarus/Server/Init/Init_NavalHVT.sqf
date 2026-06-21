//--- Init_NavalHVT.sqf — Naval HVT Objectives orchestrator.
//--- Called once from Init_Server.sqf, guarded by WFBE_C_NAVAL_HVT.
//--- Creates 4 offshore capturable HVTs on Chernarus south coast, defaulting to GUER ownership.
//---
//--- Assets:
//---   [A] Khe Sanh Alpha (LHD)  — ~[3000, 600]  — carrier, aircraft sell
//---   [B] Pier / FOB            — ~[5400, 800]   — forward base, fast respawn
//---   [C] Oil Platform (SCUD)   — ~[8000, 700]   — SCUD strike unlock
//---   [D] Khe Sanh Bravo (LHD)  — ~[11500, 700]  — carrier, aircraft sell
//---
//--- IMPORTANT NOTES:
//---   • setPosASL is used throughout for sea objects (NOT setPos/setPosATL which snap to seabed).
//---   • All createVehicle calls are GLOBAL (server-authoritative, so AI/collision sees them).
//---   • This file registers towns via the same pattern as Init_Town.sqf.
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
//--- WAIT: town init must be complete before we register new towns.
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
//--- HELPER: register a LocationLogicDepot as a capturable town.
//--- Pattern mirrors Init_Town.sqf / how existing towns are registered.
//------------------------------------------------------------------------------------
WFBE_NavalHVT_RegisterTown = {
	private ["_loc","_name","_sv","_maxSV","_townType","_sideID","_extra"];
	_loc      = _this select 0;
	_name     = _this select 1;
	_sv       = _this select 2;
	_maxSV    = _this select 3;
	_townType = _this select 4;
	_sideID   = _this select 5;
	_extra    = if (count _this > 6) then {_this select 6} else {[]};

	//--- Standard town variables (mirror Init_Town.sqf).
	_loc setVariable ["name",               _name,     true];
	_loc setVariable ["range",              600,       true];
	_loc setVariable ["startingSupplyValue",_sv,       true];
	_loc setVariable ["maxSupplyValue",     _maxSV,    true];
	_loc setVariable ["supplyValue",        _sv,       true];
	_loc setVariable ["wfbe_town_type",     _townType, true];
	_loc setVariable ["sideID",             _sideID,   true];
	_loc setVariable ["camps",              [],        true];
	_loc setVariable ["wfbe_town_defenses", [],        true];
	_loc setVariable ["LastSupplyMissionRun", 0];
	_loc setVariable ["supplyMissionCoolDownEnabled", false];
	_loc setVariable ["wfbe_active",        false,     true];
	_loc setVariable ["wfbe_active_air",    false,     true];
	_loc setVariable ["wfbe_episode_spawned", false,   true];
	_loc setVariable ["wfbe_inactivity",    0];
	_loc setVariable ["wfbe_active_override", false];
	_loc setVariable ["wfbe_town_teams",    []];
	_loc setVariable ["wfbe_is_naval_hvt",  true,      true];

	//--- Apply any extra tagged variables [varName, value] pairs.
	{
		_loc setVariable [_x select 0, _x select 1, true];
	} forEach _extra;

	//--- Register in global towns array.
	towns = towns + [_loc];

	["INITIALIZATION", Format ["Init_NavalHVT.sqf : registered town [%1] sideID=%2 sv=%3.", _name, _sideID, _sv]] Call WFBE_CO_FNC_LogContent;
};

//------------------------------------------------------------------------------------
//--- DEFINE ASSET POSITIONS
//--- NEEDS REVIEW: verify each with surfaceIsWater in-engine before final deployment.
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

//------------------------------------------------------------------------------------
//--- SPAWN ALL 4 ASSETS
//------------------------------------------------------------------------------------
private ["_lhdAlpha","_lhdAlphaParts","_lhdAlphaLogic","_lhdAlphaAirLogic",
         "_pierObj","_pierFOBLogic",
         "_oilDeck1","_oilDeck2","_oilPump","_oilTower","_oilPad","_oilLogic",
         "_lhdBravo","_lhdBravoParts","_lhdBravoLogic","_lhdBravoAirLogic",
         "_allPlatformLogics","_loc","_i","_pad","_padPos","_x"];

//---
//--- [A] KHE SANH ALPHA (LHD) — SW position
//--- NEEDS REVIEW: verify surfaceIsWater [3000,600] before use.
//---
_lhdAlphaParts = [[3000, 600, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

//--- Deck logic: LocationLogicDepot for capture + LocationLogicAirport for aircraft sell.
_lhdAlphaLogic = (createGroup sideLogic) createUnit ["LocationLogicDepot", [3000, 600, 0], [], 0, "NONE"];
_lhdAlphaLogic setPosASL [3000, 600, 0];
_lhdAlphaLogic setVariable ["wfbe_is_airfield", true, true];	//--- enables airfield-sell block in server_town.sqf

_lhdAlphaAirLogic = (createGroup sideLogic) createUnit ["LocationLogicAirport", [3000, 630, 0], [], 0, "NONE"];
_lhdAlphaAirLogic setPosASL [3000, 630, 0];
_lhdAlphaAirLogic setVariable ["wfbe_airfield_side", resistance, true];

//--- Heli spawn pads on the deck (2 pads).
"HeliHCivil" Call WFBE_NavalHVT_SpawnProp;	//--- deck spawn pad 1
_pad = createVehicle ["HeliHCivil", [3010, 600, 0], [], 0, "NONE"];
_pad setPosASL [3010, 600, 0];
_pad enableSimulation false;
_pad allowDamage false;

[_lhdAlphaLogic, "Khe Sanh Alpha", 120, 240, "HugeTown1", WFBE_C_GUER_ID,
 [["wfbe_is_carrier_hvt", true], ["wfbe_airfield_logic_ref", _lhdAlphaAirLogic]]] Call WFBE_NavalHVT_RegisterTown;

["INITIALIZATION", "Init_NavalHVT.sqf : [A] Khe Sanh Alpha (LHD) spawned at [3000,600]."] Call WFBE_CO_FNC_LogContent;

//---
//--- [B] PIER / FOB — south-coast dock
//--- NEEDS REVIEW: verify surfaceIsWater [5400,800].
//--- A2-safe: no _forEachIndex; use for-loop with index counter.
//---
private ["_pierClasses","_pierI","_pierCls","_pierObj"];
_pierClasses = ["Land_Nav_Boathouse", "Land_Nav_Boathouse_Pier", "Land_Nav_Boathouse_PierL", "Land_Nav_Boathouse_PierR", "Land_Nav_Boathouse_PierT"];
for "_pierI" from 0 to (count _pierClasses - 1) do {
	_pierCls = _pierClasses select _pierI;
	_pierObj = createVehicle [_pierCls, [5400 + (_pierI * 8), 800, 0], [], 0, "NONE"];
	_pierObj setPosASL [5400 + (_pierI * 8), 800, 0];
	_pierObj setDir 90;
	_pierObj enableSimulation false;
	_pierObj allowDamage false;
};

_pierFOBLogic = (createGroup sideLogic) createUnit ["LocationLogicDepot", [5400, 800, 0], [], 0, "NONE"];
_pierFOBLogic setPosASL [5400, 800, 0];

[_pierFOBLogic, "Naval FOB", 80, 160, "LargeTown1", WFBE_C_GUER_ID,
 [["wfbe_is_naval_fob", true]]] Call WFBE_NavalHVT_RegisterTown;

["INITIALIZATION", "Init_NavalHVT.sqf : [B] Naval FOB (Pier) spawned at [5400,800]."] Call WFBE_CO_FNC_LogContent;

//---
//--- [C] OIL PLATFORM — SCUD unlock
//--- NEEDS REVIEW: verify surfaceIsWater [8000,700].
//---
_oilDeck1 = createVehicle ["Land_Ind_BoardsPack1", [8000, 700, 0], [], 0, "NONE"];
_oilDeck1 setPosASL [8000, 700, 0];
_oilDeck1 enableSimulation false;
_oilDeck1 allowDamage false;

_oilDeck2 = createVehicle ["Land_Ind_BoardsPack2", [8005, 700, 0], [], 0, "NONE"];
_oilDeck2 setPosASL [8005, 700, 0];
_oilDeck2 enableSimulation false;
_oilDeck2 allowDamage false;

_oilPump = createVehicle ["Land_Ind_Oil_Pump_EP1", [8008, 705, 0], [], 0, "NONE"];
_oilPump setPosASL [8008, 705, 0];
_oilPump enableSimulation false;
_oilPump allowDamage false;

_oilTower = createVehicle ["Land_Ind_Oil_Tower_EP1", [7995, 700, 0], [], 0, "NONE"];
_oilTower setPosASL [7995, 700, 0];
_oilTower enableSimulation false;
_oilTower allowDamage false;

//--- Helipad on the oil platform — SCUD addAction goes here.
_oilPad = createVehicle ["HeliHCivil", [8000, 695, 0], [], 0, "NONE"];
_oilPad setPosASL [8000, 695, 0];
_oilPad enableSimulation false;
_oilPad allowDamage false;
_oilPad setVariable ["wfbe_is_scud_pad", true, true];

_oilLogic = (createGroup sideLogic) createUnit ["LocationLogicDepot", [8000, 700, 0], [], 0, "NONE"];
_oilLogic setPosASL [8000, 700, 0];

[_oilLogic, "Oil Platform", 100, 200, "LargeTown1", WFBE_C_GUER_ID,
 [["wfbe_is_oil_platform_hvt", true], ["wfbe_scud_pad_ref", _oilPad]]] Call WFBE_NavalHVT_RegisterTown;

//--- Register oil platform in global SCUD-platform list (validated in Support_ScudStrike.sqf).
missionNamespace setVariable ["WFBE_NAVAL_HVT_PLATFORMS", [_oilLogic]];

["INITIALIZATION", "Init_NavalHVT.sqf : [C] Oil Platform (SCUD) spawned at [8000,700]."] Call WFBE_CO_FNC_LogContent;

//---
//--- [D] KHE SANH BRAVO (LHD) — SE position
//--- NEEDS REVIEW: verify surfaceIsWater [11500,700].
//---
_lhdBravoParts = [[11500, 700, 0], 90] Call WFBE_NavalHVT_SpawnLHD;

_lhdBravoLogic = (createGroup sideLogic) createUnit ["LocationLogicDepot", [11500, 700, 0], [], 0, "NONE"];
_lhdBravoLogic setPosASL [11500, 700, 0];
_lhdBravoLogic setVariable ["wfbe_is_airfield", true, true];

_lhdBravoAirLogic = (createGroup sideLogic) createUnit ["LocationLogicAirport", [11500, 730, 0], [], 0, "NONE"];
_lhdBravoAirLogic setPosASL [11500, 730, 0];
_lhdBravoAirLogic setVariable ["wfbe_airfield_side", resistance, true];

_pad = createVehicle ["HeliHCivil", [11510, 700, 0], [], 0, "NONE"];
_pad setPosASL [11510, 700, 0];
_pad enableSimulation false;
_pad allowDamage false;

[_lhdBravoLogic, "Khe Sanh Bravo", 120, 240, "HugeTown1", WFBE_C_GUER_ID,
 [["wfbe_is_carrier_hvt", true], ["wfbe_airfield_logic_ref", _lhdBravoAirLogic]]] Call WFBE_NavalHVT_RegisterTown;

["INITIALIZATION", "Init_NavalHVT.sqf : [D] Khe Sanh Bravo (LHD) spawned at [11500,700]."] Call WFBE_CO_FNC_LogContent;

//------------------------------------------------------------------------------------
//--- STORE ALL NAVAL HVT LOGICS for server_town.sqf capture-block lookup.
//------------------------------------------------------------------------------------
missionNamespace setVariable ["WFBE_NAVAL_HVT_LOGICS", [_lhdAlphaLogic, _pierFOBLogic, _oilLogic, _lhdBravoLogic], true];

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
										["RequestSpecial", ["ScudStrike", sideJoined, _pos, group player]] Call WFBE_CO_FNC_SendToServer;
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
