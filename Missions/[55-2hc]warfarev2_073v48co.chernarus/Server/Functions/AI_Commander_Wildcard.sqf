/*
	AI Commander Wildcard Events - one free random event per AI-commanded side per interval.
	feat/ai-commander v0.6.  Server-side; one instance spawned per side from Init_Server.
	Parameter: _this = side.

	Runs UNATTENDED in AI-vs-AI eval rounds.  Design constraints:
	  - First event fires after one full interval (not at minute 0).
	  - One failed event must never kill this loop.  Isolation = the apply body
	    runs inside [_side] spawn {...} so a runtime error kills only that spawn.
	  - Re-checks liveness (wfbe_aicom_running) each cycle; a human taking command
	    suppresses wildcards until the AI is back in full command.
	  - All external reads use getVariable with defaults so nil never throws.

	Event pool v2 (six events; W4/W5 omitted from v1 remain omitted - see below):
	  W1  WAR CHEST        — AI funds += 25% of FUNDS_START (always eligible; fallback).
	  W2  SUPPLY DROP      — side supply += 1500, capped at WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT.
	  W3  BONUS PATROL     — one extra patrol at the side's current tier, cap bypass.
	                         Ineligible when: Patrols upgrade = 0, no owned towns, pool empty.
	  W4  ARTILLERY VOUCHER— one-shot fire mission at the highest-weight enemy town via the
	                         base gun machinery (AI_Commander_Strategy section 4).
	                         Requires WFBE_C_AI_COMMANDER_ARTILLERY > 0 AND a ready base gun;
	                         falls back to W1 when gated/no gun available.
	  W5  RECON SWEEP      — bonus scout patrol toward the nearest contested town using the
	                         existing tier-0 / LIGHT patrol pool; same HC-dispatch path as W3.
	                         Ineligible when no owned towns, no enemy/neutral towns, pool empty.
	  W6  DEFENSE DROP     — spawn / refresh one defense slot at the side's weakest owned town
	                         (lowest supplyValue).  Uses Server_ManageTownDefenses path: calls
	                         WFBE_SE_FNC_SpawnTownDefense on a defense_logic with an empty slot.
	                         Ineligible when no owned towns with any wfbe_town_defenses slots.

	W4 RESEARCH SURGE omitted: ProcessUpgrade sleeps the full research timer and sets
	wfbe_upgrading exclusively - there is no safe instant-complete path without
	hand-rolling upgrade state mutation.  Flagged as v3.

	W5 GUNSHIP GIFT omitted (v1 tag): no existing produce/team path that avoids new machinery.

	WEIGHTED DRAW (v2):
	  Base weight table: private array of [type, weight] pairs.
	  Weights are scaled by an ESCALATION BIAS when losing (myTowns < enemyTowns * threshold):
	  aggressive events (W1 WAR CHEST, W4 ARTILLERY VOUCHER) get their weight multiplied by
	  WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_MULT (default 2.0).
	  Weighted selection = single random roll over cumulative sum (no reject loop needed).
	  Ineligible events fall back to W1 after the roll.

	Tunables (missionNamespace getVariable with defaults):
	  WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL          default 1800  (seconds)
	  WFBE_C_AI_COMMANDER_WILDCARD                   default 1     (0=disable)
	  WFBE_C_AI_COMMANDER_WILDCARD_W1_WEIGHT         default 10
	  WFBE_C_AI_COMMANDER_WILDCARD_W2_WEIGHT         default 10
	  WFBE_C_AI_COMMANDER_WILDCARD_W3_WEIGHT         default 10
	  WFBE_C_AI_COMMANDER_WILDCARD_W4_WEIGHT         default 8
	  WFBE_C_AI_COMMANDER_WILDCARD_W5_WEIGHT         default 7
	  WFBE_C_AI_COMMANDER_WILDCARD_W6_WEIGHT         default 7
	  WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_MULT   default 2.0
	  WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_RATIO  default 0.75  (myTowns/enemyTowns threshold)
*/

private ["_side","_logik","_sideID","_interval","_enabled","_humanCmd","_cmdTeam",
         "_fundsStart","_bonus","_curFunds","_pool","_draw","_eligible",
         "_upgrades","_lvl","_owned","_hq","_hcs","_live","_tier","_template","_home",
         "_active","_supply","_maxSupply","_supplyGrant","_detail","_result"];

_side    = _this;
_logik   = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {
	["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - %2", str _side, "side logic is nil at startup"]] Call WFBE_CO_FNC_AICOMLog;
};
_sideID  = (_side) Call WFBE_CO_FNC_GetSideID;

_interval = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL", 1800];
_enabled  = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD", 1];

["INITIALIZATION", Format ["AI_Commander_Wildcard.sqf: worker started for %1 (interval=%2s, enabled=%3).", str _side, _interval, _enabled]] Call WFBE_CO_FNC_AICOMLog;

if (_enabled == 0) exitWith {
	["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - %2", str _side, "WFBE_C_AI_COMMANDER_WILDCARD disabled at startup"]] Call WFBE_CO_FNC_AICOMLog;
};

//--- First event fires after one full interval.
sleep _interval;

while {!gameOver} do {

	//--- Liveness gate: only fire during full AI command (same gate as economy workers in AI_Commander.sqf).
	_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
	_humanCmd = false;
	if (!isNull _cmdTeam) then {
		if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
	};

	if (_humanCmd) then {
		["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - %2", str _side, "human commander active on this side"]] Call WFBE_CO_FNC_AICOMLog;
	} else {
		_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
		if (isNull _hq || {!alive _hq}) then {
			["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - %2", str _side, "HQ null or dead"]] Call WFBE_CO_FNC_AICOMLog;
		} else {
			if (!(_logik getVariable ["wfbe_aicom_running", false])) then {
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - %2", str _side, "wfbe_aicom_running is false"]] Call WFBE_CO_FNC_AICOMLog;
			} else {

				//--- Isolate the draw+apply body: a throw kills only this spawn, not the loop.
				[_side] spawn {
					private ["_side","_logik","_sideID","_sideText","_fundsStart","_bonus","_curFunds",
					         "_upgrades","_lvl","_owned","_hq","_tier","_pool","_template",
					         "_home","_active","_hcs","_live","_supply","_maxSupply",
					         "_supplyGrant","_draw","_eligible","_w3Eligible","_w4Eligible",
					         "_w5Eligible","_w6Eligible","_detail","_result",
					         "_enemySide","_enemyID","_myTowns","_enemyTowns","_losing",
					         "_wW1","_wW2","_wW3","_wW4","_wW5","_wW6","_eMult",
					         "_weights","_cumSum","_roll","_i","_chosen",
					         "_cTown","_artyTgt","_targets","_cands","_bestScore","_bestTown","_score","_dNear","_d",
					         "_pieces","_p","_idx","_maxR","_fired","_sideText",
					         "_w5Pool","_w5Tier","_contestedTowns","_nearTown","_nearD","_dd",
					         "_weakTown","_weakSV","_sv","_defSlots","_defLogic","_defSlot",
					         "_ownNear","_upASel","_cd","_artyEnabled","_freeSlot","_defSpawned"];

					_side   = _this select 0;
					_logik  = (_side) Call WFBE_CO_FNC_GetSideLogic;
					_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
					_sideText = str _side;

					if (isNil "_logik") exitWith {};

					//--- ---------------------------------------------------------------
					//--- WAR STATE: compute town counts for escalation bias.
					//--- ---------------------------------------------------------------
					_enemySide = if (_side == west) then {east} else {west};
					_enemyID   = (_enemySide) Call WFBE_CO_FNC_GetSideID;
					_myTowns   = 0; _enemyTowns = 0;
					{
						if ((_x getVariable ["sideID","?"]) == _sideID)   then {_myTowns   = _myTowns   + 1};
						if ((_x getVariable ["sideID","?"]) == _enemyID)  then {_enemyTowns = _enemyTowns + 1};
					} forEach towns;

					//--- Losing = our fraction below threshold (default 0.75).
					_losing = false;
					if (_enemyTowns > 0) then {
						_losing = (_myTowns / (_myTowns + _enemyTowns)) < (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_RATIO", 0.75]);
					};

					//--- ---------------------------------------------------------------
					//--- ELIGIBILITY FLAGS
					//--- ---------------------------------------------------------------
					_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
					_lvl      = if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_PATROLS}) then {_upgrades select WFBE_UP_PATROLS} else {0};

					_owned = [];
					{if ((_x getVariable ["sideID","?"]) == _sideID) then {_owned = _owned + [_x]}} forEach towns;
					_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;

					_tier    = switch (_lvl) do {case 1: {"LIGHT"}; case 2: {"MEDIUM"}; default {"HEAVY"}};
					_pool    = missionNamespace getVariable [Format ["WFBE_%1_PATROL_%2", _side, _tier], []];

					//--- W3: bonus patrol — patrol upgrade >= 1, owned towns, non-empty pool, HQ alive.
					_w3Eligible = (_lvl >= 1 && {count _owned > 0} && {count _pool > 0} && {!isNull _hq} && {alive _hq});

					//--- W4: artillery voucher — requires WFBE_C_AI_COMMANDER_ARTILLERY > 0,
					//--- global artillery enabled, and at least one ready base gun in range of an enemy town.
					_artyEnabled = ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0) && {(missionNamespace getVariable ["WFBE_C_ARTILLERY", 0]) > 0};
					_w4Eligible  = false;
					if (_artyEnabled && {!isNull _hq} && {alive _hq}) then {
						//--- Quick check: does any live base gun with ammo exist?
						_pieces = (getPos _hq) nearEntities [["StaticWeapon","Tank","Car"], 250];
						{
							if (!_w4Eligible && {alive _x} && {(_x getVariable ["WFBE_CommanderArtillery", false])} && {(_x getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {someAmmo _x}) then {
								if (!isNull (gunner _x) && {alive (gunner _x)}) then {_w4Eligible = true};
							};
						} forEach _pieces;
					};

					//--- W5: recon sweep — LIGHT pool (tier 0 always used regardless of upgrade),
					//--- need at least one owned town and one contested/enemy town as destination.
					_w5Pool = missionNamespace getVariable [Format ["WFBE_%1_PATROL_LIGHT", _side], []];
					_contestedTowns = [];
					{if ((_x getVariable ["sideID","?"]) != _sideID) then {_contestedTowns = _contestedTowns + [_x]}} forEach towns;
					_w5Eligible = (count _owned > 0 && {count _w5Pool > 0} && {count _contestedTowns > 0} && {!isNull _hq} && {alive _hq});

					//--- W6: defense drop — need at least one owned town that has defense slots
					//--- and at least one slot whose current defense is null/dead.
					_w6Eligible = false;
					_weakTown   = objNull;
					_weakSV     = 1e9;
					{
						_sv = _x getVariable ["supplyValue", 0];
						_defSlots = _x getVariable ["wfbe_town_defenses", []];
						if (count _defSlots > 0 && {_sv < _weakSV}) then {
							//--- Check for a free (null or dead) slot.
							_freeSlot = false;
							{
								_defLogic = _x;
								_defSlot  = _defLogic getVariable ["wfbe_defense", objNull];
								if (isNil "_defSlot" || {isNull _defSlot} || {!alive _defSlot}) then {_freeSlot = true};
							} forEach _defSlots;
							if (_freeSlot) then {
								_w6Eligible = true;
								_weakSV     = _sv;
								_weakTown   = _x;
							};
						};
					} forEach _owned;

					//--- ---------------------------------------------------------------
					//--- BASE WEIGHTS (tunables) + ESCALATION BIAS
					//--- ---------------------------------------------------------------
					_eMult = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_MULT", 2.0];

					_wW1 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W1_WEIGHT", 10];
					_wW2 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W2_WEIGHT", 10];
					_wW3 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W3_WEIGHT", 10];
					_wW4 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W4_WEIGHT", 8];
					_wW5 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W5_WEIGHT", 7];
					_wW6 = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_W6_WEIGHT", 7];

					//--- Escalation: boost aggressive events when losing.
					if (_losing) then {
						_wW1 = _wW1 * _eMult;
						_wW4 = _wW4 * _eMult;
					};

					//--- Zero out ineligible events (they fall back to W1 via the chosen==0 guard).
					if (!_w3Eligible) then {_wW3 = 0};
					if (!_w4Eligible) then {_wW4 = 0};
					if (!_w5Eligible) then {_wW5 = 0};
					if (!_w6Eligible) then {_wW6 = 0};

					//--- Build weight array [type, cumulative_sum] and do a single random roll.
					//--- Types: 1=W1 2=W2 3=W3 4=W4 5=W5 6=W6.
					_weights = [[1,_wW1],[2,_wW2],[3,_wW3],[4,_wW4],[5,_wW5],[6,_wW6]];

					//--- Compute cumulative sums (inline; no helper needed).
					_cumSum = 0;
					{_cumSum = _cumSum + (_x select 1)} forEach _weights;

					_draw = 1; //--- default fallback = W1
					if (_cumSum > 0) then {
						_roll = random _cumSum;
						_i = 0;
						_chosen = 0;
						_cumSum = 0;
						while {_i < count _weights && {_chosen == 0}} do {
							_cumSum = _cumSum + ((_weights select _i) select 1);
							if (_roll < _cumSum) then {_chosen = (_weights select _i) select 0};
							_i = _i + 1;
						};
						if (_chosen > 0) then {_draw = _chosen};
					};

					_eligible = true;
					_result   = "applied";
					_detail   = Format ["losing=%1 myTowns=%2 enemyTowns=%3", _losing, _myTowns, _enemyTowns];

					//--- ---------------------------------------------------------------
					//--- APPLY
					//--- ---------------------------------------------------------------
					switch (_draw) do {

						//--- W1: WAR CHEST — funds += 25% of this side's configured FUNDS_START.
						case 1: {
							_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
							_bonus      = round(_fundsStart * 0.25);
							_curFunds   = (_side) Call GetAICommanderFunds;
							[_side, _bonus] Call ChangeAICommanderFunds;
							_detail = Format ["funds_before=%1 bonus=%2 funds_after=%3 losing=%4", _curFunds, _bonus, (_side) Call GetAICommanderFunds, _losing];
						};

						//--- W2: SUPPLY DROP — side supply += 1500 (ChangeSideSupply caps at WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT).
						case 2: {
							_supply    = (_side) Call WFBE_CO_FNC_GetSideSupply;
							_maxSupply = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 99999];
							_supplyGrant = 1500 min (_maxSupply - (if (isNil "_supply") then {0} else {_supply}));
							if (_supplyGrant > 0) then {
								[_side, _supplyGrant, "AI Commander Wildcard: supply drop.", false] Call ChangeSideSupply;
								_detail = Format ["supply_before=%1 grant=%2 max=%3", _supply, _supplyGrant, _maxSupply];
							} else {
								_result = "ineligible";
								_detail = Format ["supply already at cap %1", _maxSupply];
							};
						};

						//--- W3: BONUS PATROL — one extra patrol ignoring the cap for this spawn.
						case 3: {
							_template = _pool select floor(random count _pool);
							_home     = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity;
							_active   = _logik getVariable ["wfbe_side_patrols", 0];
							//--- Book the slot (same pattern as server_side_patrols.sqf).
							_logik setVariable ["wfbe_side_patrols", _active + 1];
							_logik setVariable ["wfbe_side_patrol_last", time];
							//--- Dispatch to a live HC if available, else server.
							_hcs  = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
							_live = [];
							{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;
							if (count _live > 0) then {
								[leader(_live select floor(random count _live)), "HandleSpecial", ["delegate-sidepatrol", _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
							};
							_detail = Format ["tier=%1 template=%2 from_town=%3 active_after=%4 hc=%5", _tier, _template, _home getVariable ["name","?"], _active + 1, count _live > 0];
						};

						//--- W4: ARTILLERY VOUCHER — one-shot fire mission via base gun machinery.
						//--- Reuses exact same gun-scan + FireArtillery path as AI_Commander_Strategy section 4.
						//--- Friendly-fire guard applied; falls back to W1 if no shot is available.
						case 4: {
							//--- Pick target: highest-weight enemy town (mirrors Strategy spearhead scoring).
							_cands = [];
							{if ((_x getVariable ["sideID","?"]) != _sideID) then {_cands = _cands + [_x]}} forEach towns;
							//--- Review fix: capture the outer candidate town like AI_Commander_Strategy does
							//--- (_this in this spawned body is [_side]; the old line threw a distance type error).
							_bestScore = -1e9; _bestTown = objNull;
							{
								_cTown = _x;
								_dNear = 1e9;
								{if ((_x getVariable ["sideID","?"]) == _sideID) then {_d = _cTown distance _x; if (_d < _dNear) then {_dNear = _d}}} forEach towns;
								if (_dNear > 1e8) then {_dNear = _cTown distance _hq};
								_score = (_cTown getVariable ["supplyValue", 0]) - (_dNear / 150) + (_cTown getVariable ["wfbe_aicom_town_weight", 0]);
								if (_score > _bestScore) then {_bestScore = _score; _bestTown = _cTown};
							} forEach _cands;

							if (!isNull _bestTown) then {
								_artyTgt = getPos _bestTown;
								_ownNear = 0;
								{if (side _x == _side && {alive _x}) then {_ownNear = _ownNear + 1}} forEach (_artyTgt nearEntities [["Man","Car","Tank","Air"], 400]);
								if (_ownNear == 0) then {
									_pieces = (getPos _hq) nearEntities [["StaticWeapon","Tank","Car"], 250];
									_fired  = false;
									{
										_p = _x;
										if (!_fired && {alive _p} && {(_p getVariable ["WFBE_CommanderArtillery", false])} && {(_p getVariable ["WFBE_CommanderArtillerySide", ""]) == _sideText} && {!isNull (gunner _p)} && {alive (gunner _p)} && {someAmmo _p}) then {
											_idx = [typeOf _p, _side] Call IsArtillery;
											if (_idx >= 0) then {
												_maxR = ((missionNamespace getVariable Format ["WFBE_%1_ARTILLERY_RANGES_MAX", _sideText]) select _idx) / (missionNamespace getVariable "WFBE_C_ARTILLERY");
												if (_p distance _artyTgt <= _maxR) then {
													[_p, _artyTgt, _side, 60] Spawn WFBE_CO_FNC_FireArtillery;
													_logik setVariable ["wfbe_aicom_arty_last", time];
													_fired = true;
													_detail = Format ["target=%1 gun=%2 ownNear=0", _bestTown getVariable ["name","?"], typeOf _p];
												};
											};
										};
									} forEach _pieces;
									if (!_fired) then {
										//--- No gun in range — fall back to W1 war chest.
										_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
										_bonus      = round(_fundsStart * 0.25);
										_curFunds   = (_side) Call GetAICommanderFunds;
										[_side, _bonus] Call ChangeAICommanderFunds;
										_draw   = 1;
										_result = "fallback-W1";
										_detail = Format ["arty_no_gun_in_range target=%1 funds_bonus=%2", _bestTown getVariable ["name","?"], _bonus];
									};
								} else {
									//--- Friendlies near target — fall back to W1.
									_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
									_bonus      = round(_fundsStart * 0.25);
									_curFunds   = (_side) Call GetAICommanderFunds;
									[_side, _bonus] Call ChangeAICommanderFunds;
									_draw   = 1;
									_result = "fallback-W1";
									_detail = Format ["arty_friendlies_near target=%1 ownNear=%2 funds_bonus=%3", _bestTown getVariable ["name","?"], _ownNear, _bonus];
								};
							} else {
								//--- No enemy towns — fall back to W1.
								_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
								_bonus      = round(_fundsStart * 0.25);
								[_side, _bonus] Call ChangeAICommanderFunds;
								_draw   = 1;
								_result = "fallback-W1";
								_detail = Format ["arty_no_enemy_towns funds_bonus=%1", _bonus];
							};
						};

						//--- W5: RECON SWEEP — bonus LIGHT-tier patrol dispatched toward the nearest
						//--- contested/enemy town from our closest owned town.  Same HC path as W3.
						//--- Uses LIGHT pool unconditionally (cheapest patrol; recon does not need heavy kit).
						case 5: {
							//--- Find nearest contested town to our front.
							//--- Review fix: capture the outer town before the inner forEach rebinds _x
							//--- (_this in this spawned body is [_side], not the outer town).
							_nearTown = objNull; _nearD = 1e9;
							{
								_cTown = _x;
								_dd = (_owned select 0) distance _cTown;
								{ _dd = _dd min (_x distance _cTown) } forEach _owned;
								if (_dd < _nearD) then {_nearD = _dd; _nearTown = _cTown};
							} forEach _contestedTowns;

							_template = _w5Pool select floor(random count _w5Pool);
							//--- Dispatch from closest owned town to the contested town.
							_home = _owned select 0;
							{if ((_x distance _nearTown) < (_home distance _nearTown)) then {_home = _x}} forEach _owned;

							_active = _logik getVariable ["wfbe_side_patrols", 0];
							_logik setVariable ["wfbe_side_patrols", _active + 1];
							_logik setVariable ["wfbe_side_patrol_last", time];

							_hcs  = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
							_live = [];
							{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;
							if (count _live > 0) then {
								[leader(_live select floor(random count _live)), "HandleSpecial", ["delegate-sidepatrol", _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
							};
							_detail = Format ["toward=%1 from=%2 template=%3 hc=%4", _nearTown getVariable ["name","?"], _home getVariable ["name","?"], _template, count _live > 0];
						};

						//--- W6: DEFENSE DROP — refresh one dead/missing defense slot at the
						//--- weakest owned town (lowest supplyValue).
						//--- Iterates wfbe_town_defenses; picks the first null/dead logic slot and
						//--- calls WFBE_SE_FNC_SpawnTownDefense exactly as Server_ManageTownDefenses does.
						case 6: {
							_defSlots   = _weakTown getVariable ["wfbe_town_defenses", []];
							_defSpawned = false;
							{
								_defLogic = _x;
								_defSlot  = _defLogic getVariable ["wfbe_defense", objNull];
								if (!_defSpawned && {isNil "_defSlot" || {isNull _defSlot} || {!alive _defSlot}}) then {
									if !(isNull _defSlot) then {deleteVehicle _defSlot};
									[_defLogic, _side] Call WFBE_SE_FNC_SpawnTownDefense;
									_defSpawned = true;
								};
							} forEach _defSlots;
							if (_defSpawned) then {
								_detail = Format ["town=%1 sv=%2", _weakTown getVariable ["name","?"], _weakSV];
							} else {
								_result = "ineligible";
								_detail = Format ["defense_drop_no_free_slot town=%1", _weakTown getVariable ["name","?"]];
							};
						};
					};

					["INFORMATION", Format ["AI_Commander_Wildcard.sqf: [WILDCARD] side=%1 draw=W%2 result=%3 detail=(%4)", str _side, _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|WILDCARD_W" + str _draw + "|" + _result + "|" + _detail);
				};

			}; //--- end wfbe_aicom_running branch
		}; //--- end HQ alive branch
	}; //--- end humanCmd branch

	sleep _interval;
};
