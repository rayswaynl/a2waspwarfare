/*
	Start an upgrade.
	 Parameters:
		- Side
		- Upgrade ID
		- Upgrade Level
		- Player's call
*/

Private ["_artilleryIndex","_artilleryTypes","_artilleryTypesByIndex","_logic","_ownedBySide","_refreshedArtillery","_side","_sideText","_stime","_upgrades","_upgrade_id","_upgrade_isplayer","_upgrade_level","_upgrade_time","_vehicle","_patrolNewLevel","_patrolCashPool","_patrolPlayers","_patrolShare","_patrolSupply"];

_side = _this select 0;
_upgrade_id = _this select 1;
_upgrade_level = _this select 2;
_upgrade_isplayer = _this select 3;

_upgrade_time = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES",str _side]) select _upgrade_id) select _upgrade_level;
_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
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
_upgrades set [_upgrade_id, (_upgrades select _upgrade_id) + 1];

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

//--- Patrol upgrade economy rewards (Ray 2026-07-01): reward reaching the top patrol tiers.
//--- Runs exactly once when a level completes (this file is the completion hook), on the server.
//---   T3 (new level 3) = one-time CASH grant to the side, split among alive owning-side players
//---     (mirrors Server_BankIncome / convoy-pay BankPayout pattern).
//---   T4 (new level 4) = one-time small SUPPLY grant to the side pool (mirrors the
//---     GuerFobCleared / bank-destruction ChangeSideSupply pattern; ChangeSideSupply clamps
//---     at the supply ceiling server-side).
//--- One-time-on-completion (NOT a passive per-tick drip) keeps it a clean research incentive
//--- with zero extra loops. Amounts are tunable via missionNamespace getVariable [NAME,default].
if (_upgrade_id == WFBE_UP_PATROLS) then {
	_patrolNewLevel = _upgrades select _upgrade_id;
	if (_patrolNewLevel == 3) then {
		_patrolCashPool = missionNamespace getVariable ["WFBE_C_PATROL_T3_CASH", 8000];
		if (_patrolCashPool > 0) then {
			_patrolPlayers = 0;
			{if ((isPlayer _x) && (alive _x) && (side _x == _side)) then {_patrolPlayers = _patrolPlayers + 1}} forEach playableUnits;
			_patrolShare = round (_patrolCashPool / (_patrolPlayers max 1));
			[_side, "BankPayout", [_patrolShare]] Call WFBE_CO_FNC_SendToClients;
			["INFORMATION", Format ["Server_ProcessUpgrade.sqf: [%1] Patrol T3 cash reward $%2 x %3 players (pool %4).", str _side, _patrolShare, _patrolPlayers, _patrolCashPool]] Call WFBE_CO_FNC_LogContent;
		};
	};
	if (_patrolNewLevel == 4) then {
		_patrolSupply = missionNamespace getVariable ["WFBE_C_PATROL_T4_SUPPLY", 1500];
		if (_patrolSupply > 0) then {
			[_side, _patrolSupply, "Patrol upgrade T4 reward.", false] Call ChangeSideSupply;
			["INFORMATION", Format ["Server_ProcessUpgrade.sqf: [%1] Patrol T4 supply reward +%2.", str _side, _patrolSupply]] Call WFBE_CO_FNC_LogContent;
		};
	};
};

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
