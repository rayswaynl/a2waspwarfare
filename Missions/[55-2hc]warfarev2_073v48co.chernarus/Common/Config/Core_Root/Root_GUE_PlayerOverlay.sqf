/*
	Root_GUE_PlayerOverlay.sqf — player-facing overrides for the GUER "Insurgents" faction.
	Loaded from Root_GUE.sqf when WFBE_C_GUER_PLAYERSIDE > 0 and the local player is GUER. CLIENT-side.

	- Repoints WFBE_GUERDEPOTUNITS (buy-menu depot pool) from the AI-faction pool (civ cars + 1 soldier)
	  to the GUER player arsenal, time-gated by WFBE_GUER_VEHICLE_TIER (broadcast by Server_GuerStipend.sqf):
	  technicals always; BRDM @tier1 (30m); T-55 @tier2 (1.5h); T-72 @tier3 (3h).
	- Defines per-role default respawn gear (Engineer/Sniper/Medic).

	A2 OA 1.62/1.63 safe: array-form private only (no inline `private _x =`), `_arr + [x]` (no pushBack),
	no params/isEqualType.
*/
if !((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) exitWith {};
if !(local player) exitWith {};
if !(side group player == resistance) exitWith {};

//--- Per-role default respawn gear: [weapons[], magazines[], [primary, sidearm]].
missionNamespace setVariable ["WFBE_GUER_DefaultGearEngineer", [
	["AKS_74_kobra","Makarov","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","HandGrenade_East","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["AKS_74_kobra","Makarov"]
]];
missionNamespace setVariable ["WFBE_GUER_DefaultGearSpot", [
	["SVD","Makarov","Binocular","NVGoggles","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","10Rnd_762x54_SVD","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["SVD","Makarov"]
]];
missionNamespace setVariable ["WFBE_GUER_DefaultGearMedic", [
	["AKS_74_kobra","Makarov","ItemCompass","ItemMap","ItemRadio","ItemWatch"],
	["30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","30Rnd_545x39_AK","HandGrenade_East","SmokeShellRed","8Rnd_9x18_Makarov","8Rnd_9x18_Makarov"],
	["AKS_74_kobra","Makarov"]
]];

//--- Dynamic buy pool: rebuild WFBE_GUERDEPOTUNITS whenever the server vehicle tier changes.
//--- (The buy menu reads WFBE_GUERDEPOTUNITS at open time, so updating it dynamically time-gates vehicles.)
[] spawn {
	private ["_lastTier","_tier","_pool"];
	_lastTier = -99;
	while {!WFBE_GameOver && (local player) && {side group player == resistance}} do {
		_tier = missionNamespace getVariable ["WFBE_GUER_VEHICLE_TIER", 0];
		if (_tier != _lastTier) then {
			_lastTier = _tier;
			_pool = [
				"GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper",
				"Offroad_DSHKM_Gue","V3S_Gue",
				"Ka137_MG_PMC"   //--- armed recon heli, pilot-fired; EASA AG/AA loadouts at a service point (see 8AM note)
			];
			if (_tier >= 1) then {_pool = _pool + ["BRDM2_Gue","T34_TK_GUE_EP1"]};
			if (_tier >= 2) then {_pool = _pool + ["T55_TK_GUE_EP1","BTR40_TK_GUE_EP1"]};
			if (_tier >= 3) then {_pool = _pool + ["T72_Gue","BMP2_Gue"]};
			missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _pool];
		};
		sleep 10;
	};
};
