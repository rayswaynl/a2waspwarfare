/*
	Start an upgrade.
	 Parameters:
		- Side
		- Upgrade ID
		- Upgrade Level
		- Player's call
*/

Private ["_artilleryIndex","_artilleryTypes","_artilleryTypesByIndex","_curLvl","_logic","_ownedBySide","_refreshedArtillery","_side","_sideText","_stime","_times","_upgrades","_upgrade_id","_upgrade_isplayer","_upgrade_level","_upgrade_time","_vehicle","_patrolNewLevel","_patrolCashPool","_patrolPlayers","_patrolShare","_patrolSupply"];

//--- Fail-clean: callers (RequestUpgrade / upgradeQueue / AI_Com_Upgrade) already latch
//--- wfbe_upgrading=true BEFORE Spawn. A throw here on short/malformed args or missing TIMES
//--- leaves the side permanently "upgrading" with money already debited and the queue dead.
if (typeName _this != "ARRAY" || {count _this < 4}) exitWith {
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected short/malformed payload type [%1] count [%2].", typeName _this, if (typeName _this == "ARRAY") then {count _this} else {-1}]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_upgrade_id = _this select 1;
_upgrade_level = _this select 2;
_upgrade_isplayer = _this select 3;

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected non-side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_id != "SCALAR" || {_upgrade_id != floor _upgrade_id}) exitWith {
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected non-integer upgrade id [%1].", _upgrade_id]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_level != "SCALAR" || {_upgrade_level != floor _upgrade_level} || {_upgrade_level < 0}) exitWith {
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected non-integer upgrade level [%1].", _upgrade_level]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_isplayer != "BOOL") then {_upgrade_isplayer = false};

_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logic) exitWith {
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected null side logic for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
};

//--- TIMES array must exist and cover [id][level] before any sleep or latch publish. On fail, CLEAR the
//--- caller-set upgrading latch so the queue worker and commander menu can recover (money already taken
//--- is logged; silent stuck flag is worse than a refund-less abort).
_times = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES", str _side];
if (typeName _times != "ARRAY" || {_upgrade_id < 0} || {_upgrade_id >= count _times} || {typeName (_times select _upgrade_id) != "ARRAY"} || {_upgrade_level >= count (_times select _upgrade_id)}) exitWith {
	_logic setVariable ["wfbe_upgrading", false, true];
	_logic setVariable ["wfbe_upgrading_id", -1, true];
	_logic setVariable ["wfbe_upgrading_end_time", -1, true];
	["WARNING", Format ["Server_ProcessUpgrade.sqf: rejected missing/OOB TIMES side %1 id %2 level %3 - cleared upgrading latch.", _side, _upgrade_id, _upgrade_level]] Call WFBE_CO_FNC_LogContent;
};
_upgrade_time = (_times select _upgrade_id) select _upgrade_level;
if (typeName _upgrade_time != "SCALAR" || {_upgrade_time < 0}) then {_upgrade_time = 0};

// Marty: Publish only the active upgrade ID from the server; the menu computes its own display countdown without touching the upgrade flow.
_logic setVariable ["wfbe_upgrading", true, true];
_logic setVariable ["wfbe_upgrading_id", _upgrade_id, true];
// Marty: Publish an AUTHORITATIVE end time replicated to ALL clients for EVERY caller
// (player, queue-auto-start AND AI commander). Player upgrades already get an exact local
// end time from the upgrade-started message; queue/AI upgrades never sent that message, so
// without this the menu/RHUD had nothing to count down from (0:00 freeze / wrong-level guess).
// The server timer below runs for _upgrade_time, so this matches the real completion moment.
_logic setVariable ["wfbe_upgrading_end_time", time + _upgrade_time, true];

if (_upgrade_isplayer) then {
	[_side, "HandleSpecial", ['upgrade-started', _upgrade_id, _upgrade_level + 1]] Call WFBE_CO_FNC_SendToClients;
	//--- Store the sync.
	missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], false];

	_stime = 0;
	while {!(missionNamespace getVariable Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level]) && _stime < _upgrade_time} do {
		_stime = _stime + 1;
		sleep 1;
	};

	//--- Release the Sync
	missionNamespace setVariable [Format["WFBE_upgrade_%1_%2_%3_sync", str _side, _upgrade_id, _upgrade_level], nil];
} else {
	sleep _upgrade_time;
};

_upgrades = +(_side Call WFBE_CO_FNC_GetSideUpgrades);
if (typeName _upgrades != "ARRAY" || {_upgrade_id < 0} || {_upgrade_id >= count _upgrades}) exitWith {
	_logic setVariable ["wfbe_upgrading", false, true];
	_logic setVariable ["wfbe_upgrading_id", -1, true];
	_logic setVariable ["wfbe_upgrading_end_time", -1, true];
	["WARNING", Format ["Server_ProcessUpgrade.sqf: abort completion - upgrades array missing/OOB side %1 id %2.", _side, _upgrade_id]] Call WFBE_CO_FNC_LogContent;
};
_curLvl = _upgrades select _upgrade_id;
if (typeName _curLvl != "SCALAR") then {_curLvl = 0};
_upgrades set [_upgrade_id, _curLvl + 1];

_logic setVariable ["wfbe_upgrades", _upgrades, true];
_logic setVariable ["wfbe_upgrading", false, true];

//--- cmdcon41 LAND ICBM TEL (feature 3, Ray 2026-07-02): the moment a side COMPLETES an ICBM/SCUD upgrade LEVEL, ensure
//--- its land TEL exists near the HQ (empty + locked = side-safe; destroyable = counterplay). The upgrade is being
//--- restructured (parallel lane) into a 2-level "SCUD" tech: level 1 = SCUD platform (TEL + SAT/RECON), level 2 = ICBM
//--- (NUKE). This hook fires at EVERY completed level of WFBE_UP_ICBM; WFBE_SE_FNC_SpawnIcbmTel is IDEMPOTENT (skips if a
//--- live TEL already exists), so the TEL is created at level 1 and the level-2 completion is a harmless no-op. Fires for
//--- BOTH the player upgrade path AND the AI-commander research path (Server_AI_Com_Upgrade -> this file) => AICOM symmetry
//--- (an AI side gets a TEL too). The per-munition LEVEL gates (NUKE>=2, SAT/RECON>=1) are enforced at fire time in
//--- WFBE_SE_FNC_IcbmTelFire. Flag-gated + fn-existence-guarded (Init_IcbmTel compiles the fn; research is long).
if (!isNil "WFBE_UP_ICBM" && {_upgrade_id == WFBE_UP_ICBM} && {(missionNamespace getVariable ["WFBE_C_ICBM_TEL", 1]) == 1} && {!isNil "WFBE_SE_FNC_SpawnIcbmTel"}) then {
	[_side] Call WFBE_SE_FNC_SpawnIcbmTel;
	["INFORMATION", Format ["Server_ProcessUpgrade.sqf: [%1] SCUD/ICBM upgrade level complete -> ensure land TEL (WFBE_C_ICBM_TEL=1).", str _side]] Call WFBE_CO_FNC_LogContent;
};
// Marty: Clear the active upgrade ID once the running upgrade has completed.
_logic setVariable ["wfbe_upgrading_id", -1, true];
// Marty: Clear the replicated authoritative end time too, so a stale value cannot drive a
// phantom countdown on clients between upgrades.
_logic setVariable ["wfbe_upgrading_end_time", -1, true];

//--- fable/patrol-reimagine (owner 2026-07-28 "Reimagine Patrol tiers, Remove money and SV
//--- rewards from them"): the T3 one-time cash grant (WFBE_C_PATROL_T3_CASH split among alive
//--- side players, side-supply fallback) and the T4 one-time supply grant (WFBE_C_PATROL_T4_SUPPLY)
//--- that lived here are REMOVED. The patrol upgrade's payoff is capability only now: L3+ unlocks
//--- the off-map air pass (Common_RunSidePatrol.sqf arrival hook -> "sidepatrol-airpass" ->
//--- Server_PatrolAirPass.sqf), L4 doubles it to a pair. The constants stay registered but
//--- orphaned (repo policy: leave constants defined). The L4 convoy truck + its per-stop pay
//--- went in the same pass (Common_RunSidePatrol.sqf / Server_HandleSpecial.sqf).

// Marty: Existing artillery, such as pre-upgrade M119 static guns, does not pass through buy/build equipment init again.
// Scan every vehicle known by the server because artillery pieces may be deployed far away from the base.
if (_upgrade_id == WFBE_UP_ARTYAMMO) then {
	_sideText = str _side;
	_refreshedArtillery = [];
	_artilleryTypesByIndex = missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_CLASSNAMES", _sideText];

	for "_artilleryIndex" from 0 to (count _artilleryTypesByIndex)-1 do {
		_artilleryTypes = _artilleryTypesByIndex select _artilleryIndex;
		{
			_vehicle = _x;
			if ((local _vehicle) && ((typeOf _vehicle) in _artilleryTypes) && !(_vehicle in _refreshedArtillery)) then {
				_ownedBySide = true;
				if !(isNil {_vehicle getVariable "side"}) then {_ownedBySide = (_vehicle getVariable "side") == _side};

				if (_ownedBySide) then {
					[_vehicle, _artilleryIndex, _side] Call EquipArtillery;
					// Marty: Mark refreshed artillery globally so client-side upgrade notifications do not add the same magazines again.
					_vehicle setVariable ["wfbe_arty_ammo_refreshed", true, true];
					_refreshedArtillery = _refreshedArtillery + [_vehicle];

					// Marty: The BIS artillery command menu is initialized from the vehicle's current magazines; rerun it after adding new ammo.
					if ((missionNamespace getVariable "WFBE_C_ARTILLERY_UI") > 0) then {
						// Marty: Clear any previous init command on this artillery piece so rerunning the BIS UI init does not stack menu actions.
						clearVehicleInit _vehicle;
						_vehicle setVehicleInit "[this] ExecVM 'Common\Common_InitArtillery.sqf'";
						processInitCommands;
						clearVehicleInit _vehicle;
					};
				};
			};
		} forEach vehicles;
	};

	["INFORMATION", Format ["Server_ProcessUpgrade.sqf: [%1] Refreshed [%2] existing artillery pieces after Artillery Ammunition upgrade.", _sideText, count _refreshedArtillery]] Call WFBE_CO_FNC_LogContent;
};

[_side, "NewIntelAvailable"] Spawn SideMessage;
// [_side, "LocalizeMessage", ['UpgradeComplete', _upgrade_id, _upgrade_level + 1]] Call WFBE_CO_FNC_SendToClients;
//--- Pass _upgrade_isplayer so clients can suppress sound/banner on AI-commander upgrades.
[_side, "HandleSpecial", ['upgrade-complete', _upgrade_id, _upgrade_level + 1, _upgrade_isplayer]] Call WFBE_CO_FNC_SendToClients;

//todo log.
