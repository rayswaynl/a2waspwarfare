/*
	Root_GUE_PlayerOverlay.sqf — player-facing overrides for the GUER "Insurgents" faction.
	Loaded from Root_GUE.sqf (Chernarus) or Root_TKGUE.sqf (Takistan) when WFBE_C_GUER_PLAYERSIDE > 0
	and the local player is GUER. CLIENT-side.

	This file is the single source for BOTH maps:
	  - #ifdef IS_CHERNARUS_MAP_DEPENDENT  =>  Chernarus:  GUE_Soldier_* classnames, T72/BMP2 tier-3
	  - else (Takistan):                       TK_GUE_*_EP1 classnames, T55 caps at tier-3 (no T72/BMP2 GUE)

	Regen-safe: LoadoutManager copies Chernarus->Takistan, so editing this CH source is the only
	persistent change point. Do NOT create a separate Root_TKGUE_PlayerOverlay.sqf — it would be
	deleted on regen (DeleteExtraFiles removes TK-only files with no CH counterpart).

	- Repoints WFBE_GUERDEPOTUNITS (buy-menu depot pool) from the AI-faction pool (civ cars + 1 soldier)
	  to the GUER player arsenal, time-gated by WFBE_GUER_VEHICLE_TIER (broadcast by Server_GuerStipend.sqf):
	  technicals + BTR-40 always (tier 0); BRDM @tier1; T-55 @tier2; T-72/T-55 @tier3 (map-dependent). [2026-07-01: BTR-40 moved to tier-0. Kill-tiers, not time now — the (30m/1.5h/3h) hints are stale from the old time-gate.]
	  Optional WFBE_C_GUER_CIVILIAN_DEPOT appends already-registered CIV/TKCIV transport classnames to this
	  player depot pool without re-registering them in Core_GUE.
	- Defines per-role default respawn gear (Engineer/Sniper/Medic).

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack),
	no params/isEqualType.
*/
if !((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) exitWith {};
if !(local player) exitWith {};
if !(side group player == resistance) exitWith {};

//--- Per-role default respawn gear: [weapons[], magazines[], [primary, sidearm]].
//--- Gear is identical on both maps (AKS-74 family common to both GUER factions).
missionNamespace setVariable ["WFBE_GUER_DefaultGearEngineer", [
	["AKS_74_kobra","RPG7V","Makarov","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","PG7V","PG7V","PG7V","HandGrenade_East","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["AKS_74_kobra","Makarov"]
]];
missionNamespace setVariable ["WFBE_GUER_DefaultGearSpot", [
	["SVD","RPG18","Makarov","Binocular","NVGoggles","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","RPG18","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["SVD","Makarov"]
]];
missionNamespace setVariable ["WFBE_GUER_DefaultGearMedic", [
	["AKS_74_kobra","RPG7V","Makarov","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","PG7V","PG7V","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["AKS_74_kobra","Makarov"]
]];

//--- Dynamic buy pool: rebuild WFBE_GUERDEPOTUNITS whenever the server vehicle tier changes.
//--- (The buy menu reads WFBE_GUERDEPOTUNITS at open time, so updating it dynamically time-gates vehicles.)
//--- Map-branching: IS_CHERNARUS_MAP_DEPENDENT is defined in version.sqf for Chernarus; commented-out for Takistan.
private ["_seedPool"];
_seedPool = ["GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper","Offroad_DSHKM_Gue","V3S_Gue","BTR40_TK_GUE_EP1","hilux1_civil_2_covered","Ka137_MG_PMC"];
if ((missionNamespace getVariable ["WFBE_C_GUER_CIVILIAN_DEPOT", 0]) > 0) then {
	_seedPool = _seedPool + ["TT650_Civ","Tractor","SkodaRed","car_sedan","UralCivil"];
};
if ((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) then { //--- fable/guer-suicide-bike: first-tick seed (CH default type; TK/ZG corrected by the tier-loop below, same as the hilux/datsun VBIED already is).
	_seedPool = _seedPool + [missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Civ"]];
};
missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _seedPool]; //--- first-tick synchronous seed (tier loop below re-sets on tier change). BTR-40 is tier-0 (always available) as of 2026-07-01.
[] spawn {
	private ["_lastSig","_tier","_kills","_m113On","_fobAvail","_fobTrucks","_fi","_sig","_pool","_civDepotOn"];
	_lastSig = "";
	while {!WFBE_GameOver && (local player) && {side group player == resistance}} do {
		_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
		//--- B75 (guer-tech): the M113 VBIED (kill-gated) and the FOB trucks (factory-kill-gated) are gated
		//--- INDEPENDENTLY of the vehicle tier, so rebuild the pool when ANY of {tier, M113 unlock, FOB availability}
		//--- changes - a composite signature, not the old tier-only guard.
		_kills = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
		_m113On = _kills >= (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 25]);
		_fobAvail = missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]];
		_civDepotOn = (missionNamespace getVariable ["WFBE_C_GUER_CIVILIAN_DEPOT", 0]) > 0;
		_sig = Format ["%1|%2|%3|%4", _tier, _m113On, _fobAvail, _civDepotOn];
		if (_sig != _lastSig) then {
			_lastSig = _sig;

			if (worldName == "Chernarus") then {  //--- GUER-MAPFIX (2026-06-18): preprocessFileLineNumbers (Root_GUE.sqf:130 / Root_TKGUE.sqf:104) loads this file STANDALONE, so IS_CHERNARUS_MAP_DEPENDENT (version.sqf) was UNDEFINED -> the #else (Takistan) branch ran on Chernarus too (TK classnames in the CH buy-roster + WFBE_C_GUER_VBIED_TYPE wrongly = datsun). Runtime worldName is map-correct on both maps.
			//--- Chernarus GUER roster (GUE_* classnames).
			_pool = [
				"GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper",
				"Offroad_DSHKM_Gue","V3S_Gue",
				"BTR40_TK_GUE_EP1",   //--- BTR-40 light armoured car: tier-0 / always available (2026-07-01: moved out of the old tier-2 gate - fair from the start; a light transport car, not a tank; the T-55 stays tier-2).
				"hilux1_civil_2_covered",   //--- VBIED: driver-detonated suicide truck. "Detonate VBIED" action + cash-for-kills (mirrors AI wildcard W21). Always available (tier 0).
				"Ka137_MG_PMC"   //--- armed recon heli, pilot-fired; EASA AG/AA loadouts at a service point (see 8AM note)
			];
			if (_civDepotOn) then {_pool = _pool + ["TT650_Civ","Tractor","SkodaRed","car_sedan","UralCivil"]};
			if ((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Civ"]]}; //--- fable/guer-suicide-bike.
			if (_tier >= 1) then {_pool = _pool + ["BRDM2_Gue","T34_TK_GUE_EP1"]};
			if (_tier >= 2) then {_pool = _pool + ["T55_TK_GUE_EP1"]}; //--- BTR-40 moved to the tier-0 base pool (2026-07-01); T-55 stays tier-2.
			if (_tier >= 3) then {_pool = _pool + ["T72_Gue","BMP2_Gue"]};
			} else {
			//--- Takistan GUER roster (TK_GUE_*_EP1 classnames; no T72/BMP2 GUE on TK).
			//--- TK VBIED uses the datsun covered civilian pickup; repoint WFBE_C_GUER_VBIED_TYPE so the
			//--- client detonate-action gate + server blast guard both match the TK truck (Chernarus keeps the hilux).
			WFBE_C_GUER_VBIED_TYPE = "datsun1_civil_2_covered";
			WFBE_C_GUER_SUICIDE_BIKE_TYPE = "Old_moto_TK_Civ_EP1"; //--- fable/guer-suicide-bike: TK/ZG repoint (mirrors the VBIED_TYPE repoint above).
			_pool = [
				"TK_GUE_Soldier_EP1","TK_GUE_Bonesetter_EP1","TK_GUE_Soldier_MG_EP1","TK_GUE_Soldier_AT_EP1","TK_GUE_Soldier_AA_EP1","TK_GUE_Soldier_Sniper_EP1",
				"Offroad_DSHKM_TK_GUE_EP1","Pickup_PK_TK_GUE_EP1","V3S_TK_GUE_EP1",
				"BTR40_MG_TK_GUE_EP1",   //--- BTR-40 (MG) light armoured car: tier-0 / always available (2026-07-01: moved out of the old tier-2 gate - fair from the start; a light car, not a tank; the T-55 stays tier-2).
				"datsun1_civil_2_covered",   //--- VBIED: driver-detonated suicide truck (TK covered civilian pickup). Mirrors the Chernarus hilux. Always available (tier 0).
				"Ka137_MG_PMC"
			];
			if (_civDepotOn) then {_pool = _pool + ["Old_bike_TK_CIV_EP1","Old_moto_TK_Civ_EP1","Volha_1_TK_CIV_EP1","LandRover_TK_CIV_EP1","Ural_TK_CIV_EP1"]};
			if ((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "Old_moto_TK_Civ_EP1"]]}; //--- fable/guer-suicide-bike.
			if (_tier >= 1) then {_pool = _pool + ["BRDM2_TK_GUE_EP1","T34_TK_GUE_EP1"]};
			if (_tier >= 2) then {_pool = _pool + ["T55_TK_GUE_EP1"]}; //--- BTR-40 (MG) moved to the tier-0 base pool (2026-07-01); T-55 stays tier-2.
			if (_tier >= 3) then {_pool = _pool + ["Ural_ZU23_TK_GUE_EP1"]};
			};
			//--- B75 (guer-tech): kill-gated SECOND VBIED — an unarmed M113 with ~2x speed (driver-local boost loop in
			//--- Client_BuildUnit.sqf). Map-independent class (M113_UN_EP1 on both maps), appended after the map branch;
			//--- shown the same way as the hilux/datsun VBIED (red "[VBIED - APC]" tag in Client_UIFillListBuyUnits.sqf).
			if (_m113On) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"]]};
			//--- B75 (guer-tech FOB): append the FOB delivery truck for each factory type that still has a token
			//--- available (earned by destroying enemy factories, spent when a FOB is built). Depot-only - this pool IS
			//--- the GUER depot. The map-correct truck trio comes from WFBE_C_GUER_FOB_TRUCKS (worldName-branched).
			_fobTrucks = missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []];
			for "_fi" from 0 to ((count _fobTrucks) - 1) do {
				if (_fi < (count _fobAvail) && {(_fobAvail select _fi) > 0}) then {_pool = _pool + [_fobTrucks select _fi]};
			};
			missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _pool];
		};
		sleep 10;
	};
};

//--- B75 (guer-tech): UNLOCK-notification watcher. The server publicVariable's WFBE_GUER_UNLOCK_MSG = [seq, text] when a
//--- kill threshold grants the next reward (Server\PVFunctions\RequestOnUnitKilled.sqf). Show it once - titleText + a
//--- richer hint. The seen-seq is seeded to the CURRENT value so a JIP joiner never re-pops an old unlock (publicVariable
//--- is not JIP-replayed, and the seed is [0,""], so a fresh joiner starts clean and only sees unlocks earned after join).
[] spawn {
	private ["_lastSeq","_msg"];
	_msg = missionNamespace getVariable ["WFBE_GUER_UNLOCK_MSG", [0, ""]];
	_lastSeq = if (count _msg >= 1) then {_msg select 0} else {-1};
	while {!WFBE_GameOver && (local player) && {side group player == resistance}} do {
		_msg = missionNamespace getVariable ["WFBE_GUER_UNLOCK_MSG", [0, ""]];
		if (count _msg == 2 && {(_msg select 0) != _lastSeq} && {(_msg select 1) != ""}) then {
			_lastSeq = _msg select 0;
			//--- Ray order (no center-screen popups for info): the GUER tech-unlock notice already renders as a
			//--- top-right hint (hintSilent parseText below), so the old center-screen titleText [...,"PLAIN DOWN"]
			//--- was a redundant middle-of-screen duplicate. Dropped; the formatted hint remains the announcement.
			hintSilent parseText (Format ["<t color='#B6F563' size='1.3'>GUER TECH UNLOCKED</t><br/><br/><t color='#F5D363'>%1</t><br/><br/><t>at %2 cumulative GUER kills</t>", _msg select 1, _msg select 0]);
		};
		sleep 3;
	};
};
