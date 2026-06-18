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
	  technicals always; BRDM @tier1 (30m); T-55 @tier2 (1.5h); T-72/T-55 @tier3 (3h, map-dependent).
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
missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", ["GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper","Offroad_DSHKM_Gue","V3S_Gue","hilux1_civil_2_covered","Ka137_MG_PMC"]]; //--- first-tick synchronous seed (tier loop below re-sets on tier change)
[] spawn {
	private ["_lastTier","_tier","_pool"];
	_lastTier = -99;
	while {!WFBE_GameOver && (local player) && {side group player == resistance}} do {
		_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
		if (_tier != _lastTier) then {
			_lastTier = _tier;

#ifdef IS_CHERNARUS_MAP_DEPENDENT
			//--- Chernarus GUER roster (GUE_* classnames).
			_pool = [
				"GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper",
				"Offroad_DSHKM_Gue","V3S_Gue",
				"hilux1_civil_2_covered",   //--- VBIED: driver-detonated suicide truck. "Detonate VBIED" action + cash-for-kills (mirrors AI wildcard W21). Always available (tier 0).
				"Ka137_MG_PMC"   //--- armed recon heli, pilot-fired; EASA AG/AA loadouts at a service point (see 8AM note)
			];
			if (_tier >= 1) then {_pool = _pool + ["BRDM2_Gue","T34_TK_GUE_EP1"]};
			if (_tier >= 2) then {_pool = _pool + ["T55_TK_GUE_EP1","BTR40_TK_GUE_EP1"]};
			if (_tier >= 3) then {_pool = _pool + ["T72_Gue","BMP2_Gue"]};
#else
			//--- Takistan GUER roster (TK_GUE_*_EP1 classnames; no T72/BMP2 GUE on TK).
			//--- TK VBIED uses the datsun covered civilian pickup; repoint WFBE_C_GUER_VBIED_TYPE so the
			//--- client detonate-action gate + server blast guard both match the TK truck (Chernarus keeps the hilux).
			WFBE_C_GUER_VBIED_TYPE = "datsun1_civil_2_covered";
			_pool = [
				"TK_GUE_Soldier_EP1","TK_GUE_Bonesetter_EP1","TK_GUE_Soldier_MG_EP1","TK_GUE_Soldier_AT_EP1","TK_GUE_Soldier_AA_EP1","TK_GUE_Soldier_Sniper_EP1",
				"Offroad_DSHKM_TK_GUE_EP1","Pickup_PK_TK_GUE_EP1","V3S_TK_GUE_EP1",
				"datsun1_civil_2_covered",   //--- VBIED: driver-detonated suicide truck (TK covered civilian pickup). Mirrors the Chernarus hilux. Always available (tier 0).
				"Ka137_MG_PMC"
			];
			if (_tier >= 1) then {_pool = _pool + ["BRDM2_TK_GUE_EP1","T34_TK_GUE_EP1"]};
			if (_tier >= 2) then {_pool = _pool + ["T55_TK_GUE_EP1","BTR40_MG_TK_GUE_EP1"]};
			if (_tier >= 3) then {_pool = _pool + ["Ural_ZU23_TK_GUE_EP1"]};
#endif
			missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _pool];
		};
		sleep 10;
	};
};
