/*
	AI Commander Wildcard Events - one free random event per side per interval.
	feat/ai-commander v2.0 (2026-06-12 final deck rebuild).
	Server-side; one instance spawned per side from Init_Server.
	Parameter: _this = side.

	GATE (v2): draws fire as long as AT LEAST ONE side is AI-commanded.
	  Disabled only when BOTH sides have a human commander.
	  AI-commanded side: normal draw, AI wallet.
	  Human-commanded side: draw fires too (PvE spice); human-side payout mapping applies.

	DECK (weights, total=123):
	  W1  War Chest         (17) Common    — AI funds +25% FUNDS_START.
	  W2  Supply Drop       (17) Common    — side supply +1500, capped.
	  W6  Air Cavalry       ( 8) Uncommon  — free ELITE air-assault squad founded as a one-off commander
	                                          team (air template) aimed at the spearhead front town; the existing
	                                          team lifecycle + Common_RunCommanderTeam air-insertion delivers it.
	                                          (REPLACED 2026-06-14: was "Fortification Grant" +2 base defenses,
	                                          removed - perf-negative, leaked a GC-exempt DefenseTeam group.)
	  W7  Veteran Company   ( 8) Uncommon  — next founded team uses premium template + skill boost.
	  W11 Field Hospital    ( 8) Uncommon  — heal all wounded AI infantry + one-shot free re-founding flag.
	  W12 Spoils of War     ( 6) Uncommon  — 10-min double kill-bounty flag; not stackable.
	  W4  Airborne Assault  ( 6) Rare      — free max-level paradrop (PARACHUTELEVEL3) on spearhead town.
	  W20 Captured Cache    ( 6) Uncommon  — raises one random SUPPORT-line upgrade tier (Paratroopers/Supply/Gear) +1;
	                                          mirrors W16 Lend-Lease but for the support tiers W16 does NOT touch.
	  W13 Gunship Strike    ( 6) Rare      — one attack aircraft, single pass on largest enemy cluster, self-despawn.
	  W14 Iron Dome         ( 7) Uncommon  — up to 2 temporary crewed AA at the most-threatened owned town.
	  W15 Black Market      ( 6) Uncommon  — 10-min 50% production discount flag.
	  W16 Lend-Lease        ( 6) Uncommon  — raise one random Light/Heavy/Air tier +1.
	  W17 Supply Convoy     ( 7) Uncommon  — crewed supply truck HQ->nearest owned town; payout on arrival.
	  W18 Bounty HVT        ( 5) Rare      — one enemy officer at the spearhead enemy town with a global bounty marker.
	  W19 Heliborne QRF     ( 5) Rare      — air-inserts a QRF squad to the friendly town most under threat.
	  W21 GUER VBIED        ( 5) Rare      - the AI commander funds a resistance driver-detonated suicide car bomb at the enemy town nearest the front; kill-bounty to whoever destroys it.

	REMOVED (Ray 2026-06-16) — three cards pulled from the deck (weights forced to 0, apply blocks left inert):
	  W3  Bonus Patrol      — REMOVED: obsolete now the patrol cap was lowered.
	  W9  Uprising          — REMOVED: too invasive.
	  W10 Lucky Salvage     — REMOVED: its salvage function moves to the new cleaner-tied Salvage Lottery.
	  (W8 Motor Pool Delivery RETIRED 2026-06-15: leaked a wfbe_persistent vehicle that never despawned.)

	Human-side payout mapping:
	  W1 -> wfbe_funds on the commander's team (instead of AI wallet).
	  W7 -> re-draw (N/A for humans).
	  W3/W4 -> assets join human side under server/HC AI control.
	  W12 -> doubles normal bounty path (flag consumed by RequestOnUnitKilled).
	  W9 -> CAN fire against human-commanded sides (pressure, not stat theft).
	  Draw announced via LocalizeMessage so players see the card.

	DE-CORRELATION: per-side jitter sleep (random 30) before each draw AND a
	second independent random call (random 1) mixed into the roll after the jitter,
	ensuring side workers diverge even on the same frame.

	ESCALATION: losing side (>=5 fewer towns than enemy) doubles W4/W7/W9 weights.

	ELIGIBILITY re-draw: up to 3 attempts; fallback W1.

	W12 expiry: flag lives on missionNamespace so it survives isolation-spawn death.

	A2 OA 1.64 compat: private string-array only; no getVariable [name,default] on groups
	(use plain getVariable then isNil check); no inline private _x=.

	Tunables (missionNamespace getVariable with defaults):
	  WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL      default 1800
	  WFBE_C_AI_COMMANDER_WILDCARD               default 1 (0=disable)
	  WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_MULT   default 2.0
	  WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_TOWNS  default 5 (gap threshold)
*/

private ["_side","_logik","_sideID","_interval","_enabled","_humanCmdWEST","_humanCmdEAST",
         "_bothHuman","_cmdTeam","_hq","_sideText","_jitter","_humanCmd","_skipAI"];

_side    = _this;
_logik   = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {
	["INFORMATION", Format ["AI_Commander_Wildcard.sqf: worker exit for %1 - side logic nil at startup", str _side]] Call WFBE_CO_FNC_AICOMLog;
};
_sideID   = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;

_interval = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_INTERVAL", 1800];
_enabled  = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD", 1];

["INITIALIZATION", Format ["AI_Commander_Wildcard.sqf: worker started for %1 (interval=%2s, enabled=%3).", _sideText, _interval, _enabled]] Call WFBE_CO_FNC_AICOMLog;

if (_enabled == 0) exitWith {
	["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - WFBE_C_AI_COMMANDER_WILDCARD disabled", _sideText]] Call WFBE_CO_FNC_AICOMLog;
};

//--- First event fires after one full interval.
sleep _interval;

while {!gameOver} do {

	//--- DE-CORRELATION: per-side jitter before computing commander state or rolling.
	_jitter = random 30;
	sleep _jitter;

	//--- GATE: disabled only when BOTH sides are human-commanded.
	_cmdTeam      = (west) Call WFBE_CO_FNC_GetCommanderTeam;
	_humanCmdWEST = false;
	if (!isNull _cmdTeam) then {
		if (isPlayer (leader _cmdTeam)) then {_humanCmdWEST = true};
	};
	_cmdTeam      = (east) Call WFBE_CO_FNC_GetCommanderTeam;
	_humanCmdEAST = false;
	if (!isNull _cmdTeam) then {
		if (isPlayer (leader _cmdTeam)) then {_humanCmdEAST = true};
	};
	_bothHuman = (_humanCmdWEST && _humanCmdEAST);

	//--- AI COMMANDER LOCK: when lock=1, treat as not-both-human so wildcard draws continue.
	if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {
		_bothHuman = false;
	};

	//--- Owner 2026-06-12: wildcards STICK AROUND even with human commanders on both sides
	//--- (human sides draw with payout remapping). WFBE_C_WILDCARD_ALWAYS=0 restores the
	//--- old both-human shutoff if ever needed.
	if ((missionNamespace getVariable ["WFBE_C_WILDCARD_ALWAYS", 1]) > 0) then {
		_bothHuman = false;
	};

	if (_bothHuman) then {
		["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - both sides human-commanded", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	} else {
		//--- AI-liveness gate ONLY when this side is AI-commanded.
		_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		_humanCmd = false;
		if (!isNull _cmdTeam) then {
			if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
		};

		//--- For AI-commanded sides: also require wfbe_aicom_running; HQ alive.
		_hq = (_side) Call WFBE_CO_FNC_GetSideHQ;
		_skipAI = false;
		if (!_humanCmd) then {
			if (isNull _hq || {!alive _hq}) then {
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - HQ null or dead", _sideText]] Call WFBE_CO_FNC_AICOMLog;
				_skipAI = true;
			};
			if (!_skipAI && {!(_logik getVariable ["wfbe_aicom_running", false])}) then {
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - wfbe_aicom_running false", _sideText]] Call WFBE_CO_FNC_AICOMLog;
				_skipAI = true;
			};
		};

		if (!_skipAI) then {
			//--- Isolate the draw+apply body so a runtime error kills only this spawn.
			[_side, _humanCmd] spawn {
				private ["_side","_logik","_sideID","_sideText","_humanCmd",
				         "_enemySide","_enemyID","_myTowns","_enemyTowns","_losing",
				         "_gapThresh","_eMult",
				         "_humanCmdWEST","_humanCmdEAST",
				         "_upgrades","_lvl","_owned","_hq","_hqPos",
				         "_tier","_pool","_w3Eligible",
				         "_w4Eligible","_w4Units","_w4Model","_w4Cargo",
				         "_w6Eligible","_defMax","_defCount","_defClass","_defData","_defPrice","_defFunds",
				         "_w6AirTemplate","_w6AirTier","_w6Tmpls","_w6TmplUps","_w6Cand","_w6Lead","_w6CandTier","_w6Idx","_w6UpArr",
				         "_w6Price","_w6PriceCN","_w6PriceUD","_w6Funds","_w6Target","_w6Targets","_w6BestTown","_w6BestScore","_w6T4","_w6DNear","_w6D","_w6Score","_w6SpawnPos","_w6Live","_w6Hcs","_w6HcUnit","_w6Order",
				         "_w7Eligible",
				         "_soldierClass",
				         "_w9Eligible","_guerTemplates","_guerUnits","_candTown",
				         "_w10Eligible","_w12Eligible","_w12Key","_w12Exp",
				         "_wW1","_wW2","_wW3","_wW4","_wW6","_wW7","_wW9","_wW10","_wW11","_wW12",
				         "_weights","_cumSum","_roll","_entropy","_i","_chosen","_draw",
				         "_eligible","_result","_detail",
				         "_fundsStart","_bonus","_curFunds",
				         "_supply","_maxSupply","_supplyGrant",
				         "_template","_home","_active","_hcs","_live",
				         "_cands","_bestScore","_bestTown","_score","_dNear","_d","_t4Town",
				         "_w4LvlText","_destination","_w4PrevParaLevel",
				         "_facDefs","_facEntry","_facListName","_facList",
				         "_unitClass","_unitUD","_unitPrice","_unitUpReq",
				         "_structures","_facObj","_facClass","_facIdx","_facNames","_v","_crew","_grp",
				         "_wrecks","_wk","_wkUD","_wkCost","_wkTotal","_wkCap",
				         "_guerTmpl","_guerGrp","_guerUnit","_guerPos","_targetTown",
				         "_nearTown","_nearD","_dd",
				         "_skillBoost","_u",
				         "_hcUnit","_sideIDEnemy",
				         "_locMsg","_tmpHumanCmdEnemy",
				         "_cmdTeam","_liveHC",
				         "_cumSum2","_reDraw","_drawn","_needRedraw","_tmpActiveUpr","_targets",
				         "_existingTeams","_sideIDLocal","_crew1","_crew2",
				         "_healed","_humanCmd","_skipAI","_w11Eligible","_w3Max",
				         "_dAng","_spawnPos","_dp","_placed","_dPos",
	         "_w13Eligible","_w13AirList","_w13AttackClasses","_w13TargetTown","_w13MaxCluster","_w13BestDist","_w13Class","_w13Ang","_w13SpawnPos","_w13Heli","_w13Pilot","_w13TargetPos","_w13Grp","_w13PilotClass","_clustTown","_nearEnemies",
	         "_w14Eligible","_w14AAClass","_w14Target","_w14Pos","_w14Placed","_w14Ang","_w14DPos","_w14AA","_w14i","_w14Grp","_w14Gunner","_w14PilotClass",
	         "_w15Eligible","_w15Exp",
	         "_w16Eligible","_maxLevels","_raisableTiers","_chosenUpID","_newUpgrades","_tierName",
	         "_w17Eligible","_w17TruckClass","_w17Truck","_w17Grp","_w17Driver","_w17Gunner","_w17Target","_w17TargetPos","_w17MarkerName","_w17SpawnPos","_w17Ang",
	         "_w18Eligible","_w18OfficerClass","_w18ParaL3","_w18Pos","_w18Grp","_w18HVT","_w18MarkerID","_w18Target","_w18Near","_w1Eligible",
		         "_w19Eligible","_w19TownObj","_w19Town","_w19BestThreat","_w19Threat","_w19TownPos","_w19SpawnPos","_w19NearD","_w19D","_w19HcUnit","_w19Price","_w19PriceCN","_w19PriceUD","_wW19","_wW20",
		         "_w20Eligible","_w20SupIDs","_w20Raisable","_w20ChosenID","_w20NewUpgrades","_w20TierName","_w20MaxLevels","_w20SupID",
				         "_w21Eligible","_wW21","_w21VbiedClass","_w21Grp","_w21Truck","_w21Drv","_w21Target","_w21TargetPos","_w21SpawnPos","_w21Ang","_w21Try","_w21Roads",
		         "_wNameMap","_wName"];

				_side     = _this select 0;
				_humanCmd = _this select 1;
				_logik    = (_side) Call WFBE_CO_FNC_GetSideLogic;
				_sideID   = (_side) Call WFBE_CO_FNC_GetSideID;
				_sideText = str _side;

				if (isNil "_logik") exitWith {};

				//--- -----------------------------------------------------------------------
				//--- WAR STATE
				//--- -----------------------------------------------------------------------
				_enemySide  = if (_side == west) then {east} else {west};
				_enemyID    = (_enemySide) Call WFBE_CO_FNC_GetSideID;
				_myTowns    = 0; _enemyTowns = 0;
				{
					if ((_x getVariable ["sideID","?"]) == _sideID)   then {_myTowns   = _myTowns   + 1};
					if ((_x getVariable ["sideID","?"]) == _enemyID)  then {_enemyTowns = _enemyTowns + 1};
				} forEach towns;

				_gapThresh = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_TOWNS", 5];
				_losing    = ((_enemyTowns - _myTowns) >= _gapThresh);
				_eMult     = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_ESCALATION_MULT", 2.0];

				//--- -----------------------------------------------------------------------
				//--- COMMON ELIGIBILITY FLAGS
				//--- -----------------------------------------------------------------------
				_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
				_lvl      = 0;
				if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_PATROLS}) then {_lvl = _upgrades select WFBE_UP_PATROLS};

				_owned = [];
				{ if ((_x getVariable ["sideID","?"]) == _sideID) then {_owned = _owned + [_x]} } forEach towns;
				//--- Enemy towns list (used by W4/W9 eligibility and W4/W9 apply).
				_cands = [];
				{ if ((_x getVariable ["sideID","?"]) == _enemyID) then {_cands = _cands + [_x]} } forEach towns;
				_hq    = (_side) Call WFBE_CO_FNC_GetSideHQ;

				_tier = switch (_lvl) do {case 1: {"LIGHT"}; case 2: {"MEDIUM"}; default {"HEAVY"}};
				_pool = missionNamespace getVariable [Format ["WFBE_%1_PATROL_%2", _side, _tier], []];

				//--- W3: bonus patrol — patrol upgrade >= 1, owned towns, pool, HQ alive.
				_w3Eligible = (_lvl >= 1 && {count _owned > 0} && {count _pool > 0} && {!isNull _hq} && {alive _hq});

				//--- W4: airborne assault — HQ alive, PARACARGO class valid, PARACHUTELEVEL3 defined.
				_w4Eligible = false;
				if (!isNull _hq && {alive _hq}) then {
					_w4Model = missionNamespace getVariable [Format ["WFBE_%1PARACARGO", _sideText], ""];
					_w4Units = missionNamespace getVariable [Format ["WFBE_%1PARACHUTELEVEL3", _sideText], []];
					if (_w4Model != "" && {isClass (configFile >> "CfgVehicles" >> _w4Model)} && {count _w4Units > 0}) then {
						_w4Eligible = (count _owned > 0 || {count _cands > 0});
					};
				};

				//--- W6: AIR CAVALRY (REPLACES Fortification Grant 2026-06-14, claude-gaming).
				//--- Eligible when: HQ alive (spawn anchor + founding path), there is a FRONT/target
				//--- town to aim at (spearhead targets or any enemy/neutral town), AND the side has at
				//--- least one AIR-ASSAULT team template - i.e. a registered WFBE_<side>AITEAMTEMPLATES
				//--- entry whose FIRST class is a troop-capable Air transport (transportSoldier>0). That
				//--- transport is what makes Common_RunCommanderTeam's air-insertion fire, so we resolve
				//--- the actual ELITE air template HERE (highest air-upgrade [3] template) and stash it for
				//--- the apply block. No funds gate (one free squad); normal team GC (no GC-exempt leak).
				_w6Eligible    = false;
				_w6AirTemplate = [];          //--- resolved elite air-assault template (class array)
				_w6AirTier     = -1;          //--- its air-upgrade requirement (higher = more elite)
				if (!isNull _hq && {alive _hq} && {(count _owned > 0) || {count _cands > 0}} && {!isNil "_upgrades"} && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0} && {(count _owned) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])}) then {  //--- B59 (Ray 2026-06-20): gate W6 Air Cavalry on air research + established towns (mirror W13/Produce) so no early/ungated Mi-24
					_w6Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
					_w6TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
					{
						_w6Cand = _x;
						if (count _w6Cand > 0) then {
							_w6Lead = _w6Cand select 0;
							//--- First class must be a troop-capable AIR transport (drives air-insertion).
							if (isClass (configFile >> "CfgVehicles" >> _w6Lead)
							    && {_w6Lead isKindOf "Air"}
							    && {(getNumber (configFile >> "CfgVehicles" >> _w6Lead >> "transportSoldier")) > 0} && {({_x isKindOf "Man"} count _w6Cand) > 0} && {({_x isKindOf "Plane"} count _w6Cand) == 0}) then {
								//--- "Elite" = pick the template with the highest AIR-tier requirement
								//--- (its WFBE_<side>AITEAMUPGRADES[3] slot); ties keep the first found.
								_w6CandTier = 0;
								_w6Idx = _w6Tmpls find _w6Cand;
								if (_w6Idx >= 0 && {_w6Idx < count _w6TmplUps}) then {
									_w6UpArr = _w6TmplUps select _w6Idx;
									if (count _w6UpArr > WFBE_UP_AIR) then {_w6CandTier = _w6UpArr select WFBE_UP_AIR};
								};
								if (_w6CandTier > _w6AirTier) then {
									_w6AirTier     = _w6CandTier;
									_w6AirTemplate = _w6Cand;
								};
							};
						};
					} forEach _w6Tmpls;
					if (count _w6AirTemplate > 0) then {_w6Eligible = true};
				};

				//--- W7: veteran company — flag check (one per draw; humans re-draw).
				_w7Eligible = (!_humanCmd);

								//--- W8 (Motor Pool Delivery) RETIRED 2026-06-15 (claude-gaming): card removed - it spawned a
				//--- wfbe_persistent=true vehicle that NEVER despawned + ran a heavy factory/buy-list scan EVERY draw.
				//--- Its weight, eligibility scan, zeroing, case handler and name-map entry are all gone.

				//--- W9: uprising — enemy-held town nearest front, GUER templates available, cap 1 active uprising per side.
				//--- Reuses _cands (enemy towns) already built above.
				_w9Eligible   = false;
				_guerTemplates = missionNamespace getVariable ["WFBE_GUERRESTEAMTEMPLATES", []];
				_guerUnits     = missionNamespace getVariable ["WFBE_GUERRESSOLDIER", ""];
				if (count _guerTemplates > 0 && {_guerUnits != ""} && {count _cands > 0}) then {
					//--- Check no active uprising for this side already.
					_tmpActiveUpr = _logik getVariable "wfbe_aicom_uprising_active";
					_tmpActiveUpr = if (isNil "_tmpActiveUpr") then {false} else {_tmpActiveUpr};
					if (!_tmpActiveUpr) then {_w9Eligible = true};
				};

				//--- W10: lucky salvage — cheap proxy: allDead covers wrecks (avoids allMissionObjects every draw).
				//--- The full sweep (with keepAlive / WarfareBBaseStructure filters) runs only in the W10 apply block.
				_w10Eligible = (count allDead) > 0;

				//--- W11: field hospital — wounded AI infantry present.
				_w11Eligible = ({alive _x && {!isPlayer _x} && {_x isKindOf "Man"} && {damage _x > 0.05} && {side _x == _side}} count allUnits) > 0;

				//--- W1: WAR CHEST gate (claude-gaming 2026-06-13): skip the +funds wildcard when an AI commander is
				//--- already RICH (> 2x funds-start) - it is sitting on a war chest it cannot even spend (group cap),
				//--- so the draw is pure waste; zeroing W1 hands those draws to more useful cards. Humans always eligible
				//--- (their draw credits the commander team's wfbe_funds, which IS useful).
				_w1Eligible = _humanCmd || {((_side) Call GetAICommanderFunds) < (2 * (missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 100000]))};

				//--- W13: gunship strike - air tier unlocked + attack-capable class + 3+ enemy cluster near an enemy town.
				_w13Eligible = false;
				if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0} && {count _cands > 0}) then {
					_w13AirList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
					_w13AttackClasses = [];
					{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Mi24_D","Mi24_V","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su34"]) then {_w13AttackClasses = _w13AttackClasses + [_x]} } forEach _w13AirList;
					if (count _w13AttackClasses > 0) then {
						{ _clustTown = _x; _nearEnemies = {alive _x && {(side _x) == _enemySide} && {(_x distance _clustTown) < 300}} count allUnits; if (_nearEnemies >= 3) exitWith {_w13Eligible = true} } forEach _cands;
					};
				};

				//--- W14: iron dome - owned town to cover + valid AA-pod class for the side.
				_w14Eligible = false;
				if (count _owned > 0 && {!isNull _hq} && {alive _hq}) then {
					_w14AAClass = missionNamespace getVariable [Format ["WFBE_%1DEFENSES_AAPOD", _sideText], ""];
					if (!isNil "_w14AAClass") then {
						if (typeName _w14AAClass == "ARRAY") then {if (count _w14AAClass > 0) then {_w14AAClass = _w14AAClass select 0} else {_w14AAClass = ""}};
						if (typeName _w14AAClass == "STRING" && {_w14AAClass != ""}) then {_w14Eligible = true};
					};
				};

				//--- W15: black market - always eligible (AI funds discount; human side discounts its team buys too).
				_w15Eligible = true;

				//--- W16: lend-lease - at least one of Light/Heavy/Air tier below its configured max level.
				_w16Eligible = false;
				_maxLevels = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", _sideText], []];
				if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_AIR} && {count _maxLevels > WFBE_UP_AIR}) then {
					if ((_upgrades select WFBE_UP_LIGHT) < (_maxLevels select WFBE_UP_LIGHT)) then {_w16Eligible = true};
					if ((_upgrades select WFBE_UP_HEAVY) < (_maxLevels select WFBE_UP_HEAVY)) then {_w16Eligible = true};
					if ((_upgrades select WFBE_UP_AIR)   < (_maxLevels select WFBE_UP_AIR))   then {_w16Eligible = true};
				};

				//--- W20: CAPTURED CACHE - mirror of W16 Lend-Lease but for the SUPPORT line W16 does NOT touch.
				//--- Candidate support upgrade ids (Init_CommonConstants.sqf): Paratroopers / SupplyRate / Gear.
				//--- W16 raises only Light/Heavy/Air, so these three are disjoint from it. Artillery-tied ids are
				//--- EXCLUDED entirely while WFBE_C_AI_COMMANDER_ARTILLERY=0 (the AI is configured never to use arty),
				//--- so a cache draw never sinks into a dead arty tier. Eligible when >=1 candidate tier is below max.
				_w20Eligible  = false;
				_w20MaxLevels = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", _sideText], []];
				//--- Build the support-id set. Paratroopers/SupplyRate/Gear are NON-arty and AI-usable.
				_w20SupIDs = [WFBE_UP_PARATROOPERS, WFBE_UP_SUPPLYRATE, WFBE_UP_GEAR];
				//--- (No arty ids are added here; if arty is ever re-enabled this is the place to append them,
				//---  gated on (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0.)
				_w20Raisable = [];
				if (!isNil "_upgrades") then {
					{
						_w20SupID = _x;
						if (count _upgrades > _w20SupID && {count _w20MaxLevels > _w20SupID}) then {
							if ((_upgrades select _w20SupID) < (_w20MaxLevels select _w20SupID)) then {_w20Raisable = _w20Raisable + [_w20SupID]};
						};
					} forEach _w20SupIDs;
				};
				if (count _w20Raisable > 0) then {_w20Eligible = true};

				//--- W17: supply convoy - owned town + alive HQ + valid faction supply-truck class.
				_w17Eligible = false;
				_w17TruckClass = if (_side == west) then {"WarfareSupplyTruck_USMC"} else {"WarfareSupplyTruck_RU"};
				if (count _owned > 0 && {!isNull _hq} && {alive _hq} && {isClass (configFile >> "CfgVehicles" >> _w17TruckClass)}) then {_w17Eligible = true};

				//--- W18: bounty hvt - enemy town held + resolvable officer/L3 class for the enemy side.
				_w18Eligible = false;
				if (count _cands > 0) then {
					_w18OfficerClass = missionNamespace getVariable [Format ["WFBE_%1_HVT_CLASS", str _enemySide], ""];
					if (_w18OfficerClass == "") then {
						_w18ParaL3 = missionNamespace getVariable [Format ["WFBE_%1PARACHUTELEVEL3", str _enemySide], []];
						if (count _w18ParaL3 > 0) then {_w18OfficerClass = _w18ParaL3 select 0};
					};
					if (_w18OfficerClass != "") then {_w18Eligible = true};
				};

				//--- W12: spoils of war — not already active.
				_w12Key  = Format ["wfbe_aicom_spoils_%1", _sideText];
				_w12Exp  = missionNamespace getVariable _w12Key;
				_w12Eligible = (isNil "_w12Exp") || {_w12Exp <= time};

				//--- W19: HELIBORNE QRF - air-insert a QRF squad to the friendly town MOST under threat.
				//--- Eligible when: the side OWNS at least one town with enemy units within ~600m (under
				//--- threat) AND the side can field a transport heli. The transport requirement REUSES W6's
				//--- resolved air-assault template (_w6Eligible / _w6AirTemplate - its first class is a
				//--- troop-capable Air transport, the SAME thing that drives Common_RunCommanderTeam's
				//--- air-insertion); if W6 resolved no air template for the side, W19 is ineligible too.
				_w19Eligible = false;
				if (_w6Eligible && {count _w6AirTemplate > 0} && {count _owned > 0}) then {
					{
						_w19TownObj = _x;
						if (({alive _x && {(side _x) == _enemySide} && {(_x distance _w19TownObj) < 600}} count allUnits) > 0) exitWith {_w19Eligible = true};
					} forEach _owned;
				};

				//--- -----------------------------------------------------------------------
				//--- BASE WEIGHTS + ESCALATION
				//--- -----------------------------------------------------------------------
				//--- W21: GUER DRIVER-DETONATED VBIED (Feature B, Ray 2026-06-16). The drawing AI commander funds a
				//--- side-resistance suicide car bomb against the enemy town nearest our front. Eligible when an enemy
				//--- town exists, the GUER soldier class resolves (WFBE_GUERRESSOLDIER, set Config_GUE.sqf:87), and the
				//--- VBIED chassis is a LOADED CfgVehicles class (isClass guard - never spawn an empty/invalid car, and it
				//--- keeps the card dark on any map lacking the chassis). NOT WFBE_GUERSOLDIER (never set -> would spawn empty).
				_w21Eligible   = false;
				_w21VbiedClass = "hilux1_civil_2_covered";   //--- GUER depot pickup, confirmed loaded both maps (Units_CO_GUE.sqf)
				if (count _cands > 0
				    && {(missionNamespace getVariable ["WFBE_GUERRESSOLDIER", ""]) != ""}
				    && {isClass (configFile >> "CfgVehicles" >> _w21VbiedClass)}) then {_w21Eligible = true};

				_wW1  = 17; _wW2  = 17; _wW3  =  0;  //--- W3 (Bonus Patrol) REMOVED 2026-06-16 (Ray): obsolete - patrol cap was lowered. Weight forced 0 -> card can NEVER be drawn; apply block left inert.
				_wW6  =  8; _wW7  =  8; _wW10 =  0; _wW11 =  8; _wW12 =  6;  //--- W6 = AIR CAVALRY (Uncommon, weight 8). W10 (Lucky Salvage) REMOVED 2026-06-16 (Ray): salvage function moves to the new cleaner-tied Salvage Lottery. Weight forced 0 -> never drawn; apply block left inert.
				_wW4  =  6; _wW9  =  0;  //--- W4 Rare weight 6. W9 (Uprising) REMOVED 2026-06-16 (Ray): too invasive. Weight forced 0 -> card can NEVER be drawn; apply block left inert (W8 RETIRED 2026-06-15).
				_wW20 =  6;  //--- W20 = CAPTURED CACHE (Uncommon, weight 6 - mirrors W16 Lend-Lease; raises a random SUPPORT-line tier).
				_wW13 =  6; _wW18 =  5;  //--- rebalance 2026-06-14: W13 (Rare) up 4->6
				_wW19 =  5;  //--- W19 = HELIBORNE QRF (Rare, weight 5).
				_wW14 =  7; _wW15 =  6; _wW16 =  6; _wW17 =  7;
				_wW21 =  5;  //--- W21 = GUER VBIED (Feature B, Rare, weight 5).

				if (_losing) then {
					_wW4  = round(_wW4  * _eMult);
					_wW6  = round(_wW6  * _eMult);  //--- Air Cavalry is now a COMBAT reinforcement: a losing side draws it more (mirrors W4/W8/W9 escalation).
					_wW7  = round(_wW7  * _eMult);
					//--- _wW9 escalation REMOVED 2026-06-16 (Ray): W9 (Uprising) is pulled from the deck (base weight 0). No-op kept inert.
					_wW13 = round(_wW13 * _eMult);
					_wW18 = round(_wW18 * _eMult);
					_wW19 = round(_wW19 * _eMult);  //--- losing side draws the QRF reinforcement more (mirrors W4/W8/W9).
				};

				//--- Zero ineligible cards.
				if (!_w3Eligible)  then {_wW3  = 0};
				if (!_w4Eligible)  then {_wW4  = 0};
				if (!_w6Eligible)  then {_wW6  = 0};
				if (!_w7Eligible)  then {_wW7  = 0};
				if (!_w9Eligible)  then {_wW9  = 0};
				if (!_w10Eligible) then {_wW10 = 0};
				if (!_w11Eligible) then {_wW11 = 0};
				if (!_w12Eligible) then {_wW12 = 0};
				if (!_w1Eligible)  then {_wW1  = 0};
				if (!_w13Eligible) then {_wW13 = 0};
				if (!_w14Eligible) then {_wW14 = 0};
				if (!_w15Eligible) then {_wW15 = 0};
				if (!_w16Eligible) then {_wW16 = 0};
				if (!_w17Eligible) then {_wW17 = 0};
				if (!_w18Eligible) then {_wW18 = 0};
				if (!_w19Eligible) then {_wW19 = 0};
				if (!_w20Eligible) then {_wW20 = 0};
				if (!_w21Eligible) then {_wW21 = 0};

				//--- Weight table: [cardID, weight]. Card IDs match W-numbers.
				//--- W8 (Motor Pool Delivery) RETIRED 2026-06-15: it spawned a wfbe_persistent=true vehicle that NEVER
				//--- despawned (worst perf/leak card) + a heavy eligibility scan. Slot 8 is GONE, not reused. W20
				//--- (Captured Cache) is a NEW id appended below - it does NOT reuse the freed 8.
				_weights = [[1,_wW1],[2,_wW2],[3,_wW3],[4,_wW4],[6,_wW6],[7,_wW7],
				            [9,_wW9],[10,_wW10],[11,_wW11],[12,_wW12],
				            [13,_wW13],[14,_wW14],[15,_wW15],[16,_wW16],[17,_wW17],[18,_wW18],[19,_wW19],
				            [20,_wW20],[21,_wW21]];

				_cumSum = 0;
				{ _cumSum = _cumSum + (_x select 1) } forEach _weights;

				_draw   = 1;
				_result = "applied";
				_detail = Format ["losing=%1 myTowns=%2 enemyTowns=%3 humanCmd=%4", _losing, _myTowns, _enemyTowns, _humanCmd];

				//--- Weighted roll + eligibility re-draw (up to 3 attempts; W1 fallback).
				//--- Uses a while loop so the "accept" path can break cleanly.
				_reDraw = 0;
				_drawn  = false;
				while {_reDraw < 3 && {!_drawn}} do {
					_reDraw = _reDraw + 1;
					if (_cumSum > 0) then {
						//--- DE-CORRELATION: second independent random call mixed in.
						_entropy = random 1;
						_roll    = (random _cumSum) + _entropy * 0.0001;
						_i = 0; _chosen = 0; _cumSum2 = 0;
						while {_i < count _weights && {_chosen == 0}} do {
							_cumSum2 = _cumSum2 + ((_weights select _i) select 1);
							if (_roll < _cumSum2) then {_chosen = (_weights select _i) select 0};
							_i = _i + 1;
						};
						if (_chosen == 0) then {_chosen = 1};
						_draw = _chosen;
					};
					//--- Re-draw condition: W7 for human side.
					_needRedraw = (_draw == 7 && {_humanCmd});
					if (!_needRedraw) then {_drawn = true};
				};
				//--- Final fallback: W1 (draw is already at least 1 from init).
				if (!_drawn) then {_draw = 1};

				//--- -----------------------------------------------------------------------
				//--- APPLY
				//--- -----------------------------------------------------------------------
				switch (_draw) do {

					//--- W1: WAR CHEST — AI funds +25% FUNDS_START.
					//--- Human side: credit to commander team wfbe_funds instead.
					case 1: {
						_fundsStart = missionNamespace getVariable [Format ["WFBE_C_ECONOMY_FUNDS_START_%1", _side], 0];
						_bonus      = round(_fundsStart * 0.25);
						if (_humanCmd) then {
							_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
							if (!isNull _cmdTeam) then {
								_curFunds = _cmdTeam getVariable "wfbe_funds";
								if (isNil "_curFunds") then {_curFunds = 0};
								_cmdTeam setVariable ["wfbe_funds", _curFunds + _bonus, true];
								_detail = Format ["human_cmd_team_funds_bonus=%1 funds_before=%2", _bonus, _curFunds];
							} else {
								_detail = "human_cmd_no_team fallback skipped";
								_result = "ineligible";
							};
						} else {
							_curFunds = (_side) Call GetAICommanderFunds;
							[_side, _bonus] Call ChangeAICommanderFunds;
							_detail = Format ["funds_before=%1 bonus=%2 funds_after=%3 losing=%4", _curFunds, _bonus, (_side) Call GetAICommanderFunds, _losing];
						};
					};

					//--- W2: SUPPLY DROP — +1500 supply, capped.
					case 2: {
						_supply    = (_side) Call WFBE_CO_FNC_GetSideSupply;
						_maxSupply = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 99999];
						if (isNil "_supply") then {_supply = 0};
						_supplyGrant = 1500 min (_maxSupply - _supply);
						if (_supplyGrant > 0) then {
							[_side, _supplyGrant, "AI Commander Wildcard: supply drop.", false] Call ChangeSideSupply;
							_detail = Format ["supply_before=%1 grant=%2 max=%3", _supply, _supplyGrant, _maxSupply];
						} else {
							_result = "ineligible";
							_detail = Format ["supply already at cap %1", _maxSupply];
						};
					};

					//--- W3 REMOVED 2026-06-16 (Ray): Bonus Patrol pulled from the deck - obsolete now the patrol cap was
					//--- lowered. Base weight _wW3 is forced 0, so draw==3 is UNREACHABLE and this apply block never runs.
					//--- Block left in place (inert) to avoid disturbing the surrounding switch structure.
					//--- W3: BONUS PATROL — free patrol at current tier, cap bypass.
					case 3: {
						//--- FIX 2026-06-15 (claude-gaming): RESPECT the concurrent patrol cap instead of bypassing it.
						//--- Reuse the EXACT cap the normal driver uses (server_side_patrols.sqf): WFBE_C_SIDE_PATROLS_MAX,
						//--- with WFBE_C_SIDE_PATROLS_MAX_DEFENDER for the resistance/defender side.
						_active = _logik getVariable ["wfbe_side_patrols", 0];
						_w3Max  = missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX", 3];
						if (_side == WFBE_DEFENDER) then {_w3Max = missionNamespace getVariable ["WFBE_C_SIDE_PATROLS_MAX_DEFENDER", _w3Max]};
						if (_active >= _w3Max) then {
							//--- At/over cap: do NOT spawn, do NOT bump the counter - clean skip (still logs, deck moves on).
							_result = "skipped: patrol cap";
							_detail = Format ["patrol cap reached active=%1 max=%2 tier=%3", _active, _w3Max, _tier];
						} else {
							_template = _pool select floor(random count _pool);
							_home     = _hq;
							if (count _owned > 0) then {_home = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity};
							//--- Under cap: book the slot synchronously (mirrors the normal driver), then dispatch.
							_logik setVariable ["wfbe_side_patrols", _active + 1];
							_logik setVariable ["wfbe_side_patrol_last", time];
							//--- Least-loaded live HC (objNull if none). Reuse the declared _w6HcUnit slot.
							_w6HcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
							if (!isNull _w6HcUnit) then {
								[_w6HcUnit, "HandleSpecial", ["delegate-sidepatrol", _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
							};
							_detail = Format ["tier=%1 template=%2 from=%3 active_after=%4 max=%5 hc=%6 humanCmd=%7", _tier, _template, _home getVariable ["name","?"], _active + 1, _w3Max, !isNull _w6HcUnit, _humanCmd];
						};
					};

					//--- W4: AIRBORNE ASSAULT — free max-level (LEVEL3) paradrop on spearhead town.
					//--- Reuses Support_Paratroopers path with a forced level-3 override.
					//--- For human sides: assets join under server/HC AI control.
					case 4: {
						//--- Target: top spearhead town (first in wfbe_aicom_targets) or nearest enemy town to front.
						//--- _cands (enemy towns) already populated in eligibility section.
						_bestTown  = objNull;
						_bestScore = -1e9;
						_targets   = _logik getVariable "wfbe_aicom_targets";
						if (!isNil "_targets" && {count _targets > 0}) then {
							_bestTown = _targets select 0;
						} else {
							{
								_t4Town = _x;
								_dNear = 1e9;
								{ if ((_x getVariable ["sideID","?"]) == _sideID) then {_d = _t4Town distance _x; if (_d < _dNear) then {_dNear = _d}} } forEach towns;
								if (_dNear > 1e8) then {_dNear = _t4Town distance _hq};
								_score = (_t4Town getVariable ["supplyValue", 0]) - (_dNear / 150);
								if (_score > _bestScore) then {_bestScore = _score; _bestTown = _t4Town};
							} forEach _cands;
						};
						if (!isNull _bestTown) then {
							_destination = getPos _bestTown;
							//--- Forced LEVEL3 override: read level-3 classnames.
							_w4Units = missionNamespace getVariable [Format ["WFBE_%1PARACHUTELEVEL3", _sideText], []];
							_w4Model = missionNamespace getVariable [Format ["WFBE_%1PARACARGO", _sideText], ""];
							if (count _w4Units > 0 && {_w4Model != ""}) then {
								//--- FIX 2026-06-15 (claude-gaming): force a LEVEL-3 drop for this wildcard WITHOUT leaking the
								//--- setting into later NORMAL paradrops. Snapshot the side's current WFBE_<side>PARACHUTELEVEL,
								//--- set 3 for the drop, then RESTORE the captured value via a short spawn (style mirrors the
								//--- cleanup spawns used by W9/W13/W14/W18). 10s is ample for Support_Paratroopers to read it.
								_w4PrevParaLevel = missionNamespace getVariable [Format ["WFBE_%1PARACHUTELEVEL", _sideText], 0];
								missionNamespace setVariable [Format ["WFBE_%1PARACHUTELEVEL", _sideText], 3];
								//--- Override the level variable so Paratroopers reads level 3.
								_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
								if (isNull _cmdTeam) then {_cmdTeam = [_side, "aicom-wildcard"] Call WFBE_CO_FNC_CreateGroup};
								[nil, _side, _destination, _cmdTeam] Spawn (Compile preprocessFile "Server\Support\Support_Paratroopers.sqf");
								//--- RESTORE the prior paradrop level after the drop is dispatched (no level-3 leak).
								[_w4PrevParaLevel, _sideText] spawn {
									private ["_prev","_st"];
									_prev = _this select 0; _st = _this select 1;
									sleep 10;
									missionNamespace setVariable [Format ["WFBE_%1PARACHUTELEVEL", _st], _prev];
								};
								_detail = Format ["target=%1 level=3 model=%2 prevLevel=%3 humanCmd=%4", _bestTown getVariable ["name","?"], _w4Model, _w4PrevParaLevel, _humanCmd];
							} else {
								_result = "ineligible";
								_detail = "W4 no PARACHUTELEVEL3 units defined";
							};
						} else {
							_result = "ineligible";
							_detail = "W4 no enemy/neutral town found";
						};
					};

					//--- W6: AIR CAVALRY — found ONE free ELITE air-assault commander team aimed at the
					//--- spearhead FRONT town. CRUCIAL REUSE: we found it through the EXACT SAME path the
					//--- AI commander uses for its own teams (AI_Commander_Teams.sqf) - delegate
					//--- 'delegate-aicom-team' [sideID, template, spawnPos, skill] to a live HC ->
					//--- WFBE_CO_FNC_RunCommanderTeam (server-local fallback if no HC). Because the resolved
					//--- template's first class is a troop-capable Air transport, that file's air-insertion
					//--- fires automatically (load foot infantry -> fly -> para/heli-land at the objective).
					//--- The team registers in wfbe_teams via 'aicom-team-created' and the brain's AssignTowns
					//--- then issues it a spearhead town order (MOVE + SAD) - so it is NEVER a frozen AI, and
					//--- it rides the NORMAL team GC (no GC-exempt DefenseTeam leak the old W6 had). FREE squad:
					//--- no funds are deducted (price is only logged for telemetry).
					case 6: {
						//--- (Re)resolve the elite air-assault template (set in eligibility; re-derive defensively).
						if (count _w6AirTemplate == 0) then {
							_w6Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
							_w6TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
							_w6AirTier = -1;
							{
								_w6Cand = _x;
								if (count _w6Cand > 0) then {
									_w6Lead = _w6Cand select 0;
									if (isClass (configFile >> "CfgVehicles" >> _w6Lead)
									    && {_w6Lead isKindOf "Air"}
									    && {(getNumber (configFile >> "CfgVehicles" >> _w6Lead >> "transportSoldier")) > 0} && {({_x isKindOf "Man"} count _w6Cand) > 0} && {({_x isKindOf "Plane"} count _w6Cand) == 0}) then {
										_w6CandTier = 0;
										_w6Idx = _w6Tmpls find _w6Cand;
										if (_w6Idx >= 0 && {_w6Idx < count _w6TmplUps}) then {
											_w6UpArr = _w6TmplUps select _w6Idx;
											if (count _w6UpArr > WFBE_UP_AIR) then {_w6CandTier = _w6UpArr select WFBE_UP_AIR};
										};
										if (_w6CandTier > _w6AirTier) then {_w6AirTier = _w6CandTier; _w6AirTemplate = _w6Cand};
									};
								};
							} forEach _w6Tmpls;
						};

						if (count _w6AirTemplate == 0) then {
							_result = "ineligible";
							_detail = "W6 AirCav no air-assault template for side";
						} else {
							//--- FRONT TOWN: reuse the SAME spearhead/front selection the commander computes
							//--- (mirrors W4): top wfbe_aicom_targets entry, else best-scored enemy town.
							_w6BestTown  = objNull;
							_w6BestScore = -1e9;
							_w6Targets   = _logik getVariable "wfbe_aicom_targets";
							if (!isNil "_w6Targets" && {count _w6Targets > 0}) then {
								_w6BestTown = _w6Targets select 0;
							} else {
								{
									_w6T4   = _x;
									_w6DNear = 1e9;
									{ if ((_x getVariable ["sideID","?"]) == _sideID) then {_w6D = _w6T4 distance _x; if (_w6D < _w6DNear) then {_w6DNear = _w6D}} } forEach towns;
									if (_w6DNear > 1e8) then {_w6DNear = _w6T4 distance _hq};
									_w6Score = (_w6T4 getVariable ["supplyValue", 0]) - (_w6DNear / 150);
									if (_w6Score > _w6BestScore) then {_w6BestScore = _w6Score; _w6BestTown = _w6T4};
								} forEach _cands;
							};

							//--- Telemetry-only template price (mirrors the canonical lookup; squad is FREE).
							_w6Price = 0;
							{
								_w6PriceCN = _x;
								_w6PriceUD = missionNamespace getVariable _w6PriceCN;
								if (!isNil "_w6PriceUD") then {_w6Price = _w6Price + (_w6PriceUD select QUERYUNITPRICE)};
							} forEach _w6AirTemplate;

							//--- Spawn anchor: HQ (rear, safe). The squad
							//--- air-inserts from here and the brain orders it forward to the front.
							_hqPos     = getPos _hq;
							_w6SpawnPos = _hqPos;

							//--- FOUND ONE TEAM via the commander's own founding path (HC delegate -> fallback).
							//--- Least-loaded live HC (objNull if none) - a whole air platoon is a BIG atomic
							//--- lump, so least-loaded picking keeps it off an already-heavy HC.
							_w6HcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
							if (!isNull _w6HcUnit) then {
								//--- skill arg 0 (no veteran boost); 4th delegate slot matches AI_Commander_Teams.
								[_w6HcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _w6AirTemplate, _w6SpawnPos, 0]] Call WFBE_CO_FNC_SendToClient;
							} else {
								//--- No live HC: run the SAME function server-local (it self-detects isServer
								//--- for team-created/ended routing). Exactly the commander's no-HC fallback.
								[_sideID, _w6AirTemplate, _w6SpawnPos] Spawn WFBE_CO_FNC_RunCommanderTeam;
							};

							_detail = Format ["air_template=%1 lead=%2 tier=%3 target=%4 price=%5 free hc=%6", _w6AirTemplate, _w6AirTemplate select 0, _w6AirTier, if (!isNull _w6BestTown) then {_w6BestTown getVariable ["name","?"]} else {"(brain-picks)"}, _w6Price, !isNull _w6HcUnit];
						};
					};

					//--- W7: VETERAN COMPANY — set a one-shot flag on the side logic so that
					//--- the next team founded by AI_Commander_Teams uses a premium template.
					//--- Human side already blocked (re-draw above).
					case 7: {
						_logik setVariable ["wfbe_aicom_veteran_next", true];
						//--- Also store a skill-boost target so Teams can apply it.
						_logik setVariable ["wfbe_aicom_veteran_skill", 0.85];
						_detail = Format ["flag set; next team will be premium template with skill=0.85 losing=%1", _losing];
					};

					//--- W8 (MOTOR POOL DELIVERY) RETIRED 2026-06-15: case handler removed. Draw 8 can no longer be
					//--- selected (absent from the weights table), so no switch case is needed and none is defined here.

					//--- W9 REMOVED 2026-06-16 (Ray): Uprising pulled from the deck - too invasive. Base weight _wW9 is
					//--- forced 0 (and its escalation no-op'd), so draw==9 is UNREACHABLE and this apply block never runs.
					//--- Block left in place (inert) to avoid disturbing the surrounding switch structure.
					//--- W9: UPRISING — spawn a GUER attack force at enemy-held town nearest the front.
					//--- Cap: 1 active uprising per side (wfbe_aicom_uprising_active flag on logik).
					case 9: {
						//--- Find enemy town nearest our front.
						_targetTown = objNull;
						_nearD      = 1e9;
						{
							_dd = 1e9;
							_candTown = _x; //--- BUG-FIX 2026-06-14: capture outer candidate (inner forEach _owned shadows _x).
							{ _dd = _dd min (_candTown distance _x) } forEach _owned; //--- was '_x distance _this' - _this is the SIDE -> "Type Side" error -> _targetTown never set -> false "no enemy town found".
							if (count _owned == 0) then {_dd = _candTown distance _hq};
							if (_dd < _nearD) then {_nearD = _dd; _targetTown = _candTown};
						} forEach _cands;

						if (!isNull _targetTown) then {
							_guerTmpl = _guerTemplates select floor(random count _guerTemplates);
							_guerGrp  = [resistance, "aicom-uprising"] Call WFBE_CO_FNC_CreateGroup;
							if (isNull _guerGrp) exitWith {
								_logik setVariable ["wfbe_aicom_uprising_active", false];
								_result = "failed";
								_detail = "W9 grpNull at group cap";
							};
							_guerPos  = getPos _targetTown;
							_logik setVariable ["wfbe_aicom_uprising_active", true];

							{
								_guerUnit = _guerGrp createUnit [_x, [(_guerPos select 0) + (random 20) - 10, (_guerPos select 1) + (random 20) - 10, 0], [], 0, "FORM"];
								//--- GUER GROUP CAP: tag uprising units as town-defenders (PUBLIC, mirrors
								//--- Common_CreateTownUnits.sqf) so they do NOT wake towns via the activation
								//--- scan - otherwise an untagged uprising force keeps GUER towns permanently
								//--- active, blocking despawn and ratcheting the resistance group count up.
								if (!isNull _guerUnit) then {_guerUnit setVariable ["WFBE_IsTownDefenderAI", true, true]};
							} forEach _guerTmpl;

							[_guerGrp, _guerPos, 200] Call AIPatrol;
							_guerGrp setBehaviour "AWARE";
							_guerGrp setCombatMode "RED";

							//--- Clear active flag when the group is wiped.
							[_guerGrp, _logik, _sideText] spawn {
								private ["_grp","_lk","_st"];
								_grp = _this select 0;
								_lk  = _this select 1;
								_st  = _this select 2;
								waitUntil {sleep 30; ({alive _x} count (units _grp)) == 0 || gameOver};
								_lk setVariable ["wfbe_aicom_uprising_active", false];
								diag_log ("AICOMSTAT|v2|EVENT|" + _st + "|" + str (round (time / 60)) + "|UPRISING_DONE|cleared");
							};

							_detail = Format ["target=%1 template_size=%2 nearD=%3", _targetTown getVariable ["name","?"], count _guerTmpl, round _nearD];
						} else {
							_result = "ineligible";
							_detail = "W9 no enemy town found";
							_logik setVariable ["wfbe_aicom_uprising_active", false];
						};
					};

					//--- W10 REMOVED 2026-06-16 (Ray): Lucky Salvage pulled from the deck - its salvage function moves to
					//--- the new cleaner-tied Salvage Lottery. Base weight _wW10 is forced 0, so draw==10 is UNREACHABLE
					//--- and this apply block never runs. Block left in place (inert) to avoid disturbing the switch structure.
					//--- W10: LUCKY SALVAGE — sweep battlefield wrecks, convert to AI funds.
					//--- Cap: ~15000 per sweep. Despawn swept wrecks.
					case 10: {
						_wkTotal = 0;
						_wkCap   = 15000;
						{
							_wk   = _x;
							if (!(alive _wk) && {!(_wk isKindOf "WarfareBBaseStructure")} && {!(_wk getVariable ["keepAlive", false])}) then {
								_wkUD   = missionNamespace getVariable (typeOf _wk);
								_wkCost = 250;
								if (!isNil "_wkUD") then {
									_wkCost = round(((_wkUD select QUERYUNITPRICE) * 0.30));
									if (_wkCost < 50) then {_wkCost = 50};
								};
								if (_wkTotal + _wkCost <= _wkCap) then {
									_wkTotal = _wkTotal + _wkCost;
									deleteVehicle _wk;
								};
							};
						} forEach (allMissionObjects "AllVehicles");
						if (_wkTotal > 0) then {
							[_side, _wkTotal] Call ChangeAICommanderFunds;
							_detail = Format ["salvage_funds=%1 cap=%2", _wkTotal, _wkCap];
						} else {
							_result = "ineligible";
							_detail = "W10 no salvageable wrecks found";
						};
					};

					//--- W11: FIELD HOSPITAL — heal all wounded AI infantry side-wide (setDamage 0).
					//--- Also sets a one-shot free re-founding flag on the side logic.
					case 11: {
						_healed = 0;
						{
							if (alive _x && {!isPlayer _x} && {_x isKindOf "Man"} && {damage _x > 0.05} && {side _x == _side}) then {
								_x setDamage 0;
								_healed = _healed + 1;
							};
						} forEach allUnits;
						//--- One-shot free re-founding flag: consumed by AI_Commander_Teams.
						_logik setVariable ["wfbe_aicom_free_refound", true];
						_detail = Format ["healed=%1 free_refound_flag=set", _healed];
					};

					//--- W13: GUNSHIP STRIKE - one attack aircraft, single pass on the largest enemy cluster, self-despawn 90s.
						case 13: {
							_w13AirList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
							_w13AttackClasses = [];
							{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Mi24_D","Mi24_V","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su34"]) then {_w13AttackClasses = _w13AttackClasses + [_x]} } forEach _w13AirList;
							_w13TargetTown = objNull; _w13MaxCluster = 0; _w13BestDist = 1e9;
							{ _clustTown = _x; _nearEnemies = {alive _x && {(side _x) == _enemySide} && {(_x distance _clustTown) < 300}} count allUnits;
							  if (_nearEnemies > _w13MaxCluster || {_nearEnemies == _w13MaxCluster && {(_clustTown distance _hq) < _w13BestDist}}) then {_w13MaxCluster = _nearEnemies; _w13TargetTown = _clustTown; _w13BestDist = _clustTown distance _hq} } forEach _cands;
							if (count _w13AttackClasses > 0 && {!isNull _w13TargetTown} && {_w13MaxCluster >= 3}) then {
								_hqPos = getPos _hq;
								_w13Ang = random 360;
								_w13SpawnPos = [(_hqPos select 0) + 4000 * sin _w13Ang, (_hqPos select 1) + 4000 * cos _w13Ang, 1500];
								_w13Class = _w13AttackClasses select floor(random count _w13AttackClasses);
								_w13Heli = [_w13Class, _w13SpawnPos, _side, random 360, true, true] Call WFBE_CO_FNC_CreateVehicle;
								if (!isNull _w13Heli) then {
									_w13Grp = [_side, "aicom-gunship"] Call WFBE_CO_FNC_CreateGroup;
									_w13PilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
									if (!isNull _w13Grp && {_w13PilotClass != ""}) then {
										_w13Pilot = [_w13PilotClass, _w13Grp, _w13SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _w13Pilot) then {
											_w13Pilot moveInDriver _w13Heli;
											_w13TargetPos = getPos _w13TargetTown;
											_w13Heli flyInHeight 200;
											_w13Grp setBehaviour "COMBAT"; _w13Grp setCombatMode "RED";
											[_w13Grp, _w13TargetPos, 200] Call AIPatrol;
											[_w13Heli, _w13Grp] spawn {
												private ["_heli","_grp"];
												_heli = _this select 0; _grp = _this select 1;
												sleep 90;
												{deleteVehicle _x} forEach (crew _heli);
												if (!isNull _heli) then {deleteVehicle _heli};
												if (!isNull _grp) then {deleteGroup _grp};
											};
											_detail = Format ["class=%1 target=%2 cluster=%3", _w13Class, _w13TargetTown getVariable ["name","?"], _w13MaxCluster];
										} else {
											deleteVehicle _w13Heli; deleteGroup _w13Grp;
											_result = "partial"; _detail = Format ["W13 no pilot for %1", _w13Class];
										};
									} else {
										deleteVehicle _w13Heli;
										_result = "partial"; _detail = "W13 no group/pilot class";
									};
								} else {
									_result = "ineligible"; _detail = Format ["W13 createVehicle null for %1", _w13Class];
								};
							} else {
								_result = "ineligible"; _detail = Format ["W13 no class/target (cluster=%1)", _w13MaxCluster];
							};
						};

						//--- W14: IRON DOME - up to 2 temporary CREWED AA at the most-threatened owned town. createVehicle DIRECT
						//--- (NOT ConstructDefense, which would leak a persistent GC-exempt DefenseTeam group); full despawn at 300s.
						case 14: {
							_w14Target = objNull;
							{ if ((_x getVariable ["wfbe_active", false]) || {_x getVariable ["wfbe_active_air", false]}) then {_w14Target = _x} } forEach _owned;
							if (isNull _w14Target && {count _owned > 0}) then {_w14Target = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity};
							if (isNull _w14Target) then {_w14Target = _hq};
							_w14AAClass = missionNamespace getVariable [Format ["WFBE_%1DEFENSES_AAPOD", _sideText], ""];
							if (typeName _w14AAClass == "ARRAY") then {if (count _w14AAClass > 0) then {_w14AAClass = _w14AAClass select 0} else {_w14AAClass = ""}};
							_w14PilotClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""];
							if (!isNull _w14Target && {alive _w14Target} && {typeName _w14AAClass == "STRING"} && {_w14AAClass != ""} && {_w14PilotClass != ""}) then {
								_w14Pos = getPos _w14Target; _w14Placed = 0;
								for "_w14i" from 1 to 2 do {
									_w14Ang = random 360;
									_w14DPos = [(_w14Pos select 0) + (35 + random 15) * sin _w14Ang, (_w14Pos select 1) + (35 + random 15) * cos _w14Ang, 0];
									_w14AA = createVehicle [_w14AAClass, _w14DPos, [], 0, "NONE"];
									if (!isNull _w14AA) then {
										_w14AA setDir _w14Ang; _w14AA setPos _w14DPos; _w14AA setVariable ["wfbe_side", _side, true];
										_w14Grp = [_side, "aicom-irondome"] Call WFBE_CO_FNC_CreateGroup;
										if (!isNull _w14Grp) then {
											_w14Gunner = [_w14PilotClass, _w14Grp, _w14DPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
											if (!isNull _w14Gunner) then {_w14Gunner moveInGunner _w14AA};
											_w14Placed = _w14Placed + 1;
											[_w14AA, _w14Grp] spawn {
												private ["_aa","_g"];
												_aa = _this select 0; _g = _this select 1;
												sleep 300;
												{deleteVehicle _x} forEach (crew _aa);
												if (!isNull _aa) then {deleteVehicle _aa};
												if (!isNull _g) then {deleteGroup _g};
											};
										} else {
											deleteVehicle _w14AA;
										};
									};
								};
								if (_w14Placed > 0) then {_detail = Format ["placed=%1 around=%2 timer=300s", _w14Placed, _w14Target getVariable ["name","?"]]} else {_result = "ineligible"; _detail = "W14 placed none"};
							} else {_result = "ineligible"; _detail = "W14 no target / AA class / crew class"};
						};

						//--- W15: BLACK MARKET - 10-min 50% production discount flag (consumed in AI_Commander_Produce.sqf).
						case 15: {
							_w15Exp = time + 600;
							missionNamespace setVariable [Format ["wfbe_aicom_discount_%1", _sideText], _w15Exp];
							_detail = Format ["discount=50%% expiry=t+600 humanCmd=%1", _humanCmd];
						};

						//--- W16: LEND-LEASE - raise one random tier (Light/Heavy/Air) below its max by +1; mirrors Server_ProcessUpgrade broadcast.
						case 16: {
							_maxLevels = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", _sideText], []];
							_raisableTiers = [];
							if (count _upgrades > WFBE_UP_AIR && {count _maxLevels > WFBE_UP_AIR}) then {
								if ((_upgrades select WFBE_UP_LIGHT) < (_maxLevels select WFBE_UP_LIGHT)) then {_raisableTiers = _raisableTiers + [WFBE_UP_LIGHT]};
								if ((_upgrades select WFBE_UP_HEAVY) < (_maxLevels select WFBE_UP_HEAVY)) then {_raisableTiers = _raisableTiers + [WFBE_UP_HEAVY]};
								if ((_upgrades select WFBE_UP_AIR)   < (_maxLevels select WFBE_UP_AIR))   then {_raisableTiers = _raisableTiers + [WFBE_UP_AIR]};
							};
							if (count _raisableTiers > 0) then {
								_chosenUpID = _raisableTiers select floor(random count _raisableTiers);
								_newUpgrades = +_upgrades;
								_newUpgrades set [_chosenUpID, (_upgrades select _chosenUpID) + 1];
								_logik setVariable ["wfbe_upgrades", _newUpgrades, true];
								[_side, "NewIntelAvailable"] Spawn SideMessage;
								[_side, "HandleSpecial", ["upgrade-complete", _chosenUpID, (_newUpgrades select _chosenUpID), false]] Call WFBE_CO_FNC_SendToClients;
								_tierName = switch (_chosenUpID) do {case WFBE_UP_LIGHT: {"Light"}; case WFBE_UP_HEAVY: {"Heavy"}; case WFBE_UP_AIR: {"Air"}; default {"?"}};
								_detail = Format ["tier=%1 new_level=%2 losing=%3", _tierName, _newUpgrades select _chosenUpID, _losing];
							} else {_result = "ineligible"; _detail = "W16 no raisable tier"};
						};

						//--- W17: SUPPLY CONVOY - crewed truck HQ->nearest owned town; payout on arrival; self-clean on arrival/timeout(600s)/death.
						case 17: {
							_w17TruckClass = if (_side == west) then {"WarfareSupplyTruck_USMC"} else {"WarfareSupplyTruck_RU"};
							_hqPos = getPos _hq; _w17Ang = random 360;
							_w17SpawnPos = [(_hqPos select 0) + (40 + random 20) * sin _w17Ang, (_hqPos select 1) + (40 + random 20) * cos _w17Ang, 0];
							_w17Truck = [_w17TruckClass, _w17SpawnPos, _side, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
							if (!isNull _w17Truck) then {
								_soldierClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""];
								_w17Grp = [_side, "aicom-convoy"] Call WFBE_CO_FNC_CreateGroup;
								if (!isNull _w17Grp && {_soldierClass != ""} && {count _owned > 0}) then {
									_w17Driver = [_soldierClass, _w17Grp, _w17SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									_w17Gunner = [_soldierClass, _w17Grp, _w17SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _w17Driver) then {_w17Driver moveInDriver _w17Truck};
									if (!isNull _w17Gunner) then {_w17Gunner moveInGunner _w17Truck};
									//--- FRONT TARGET (fix #7): find the OWNED town nearest the enemy front,
									//--- not the REAR town nearest HQ that GetClosestEntity would return.
									//--- Mirrors W18/W21: for each owned town compute its min-distance to any
									//--- enemy town (_cands); the owned town with the smallest such distance
									//--- IS the front-line town.  Fallback: nearest owned town to HQ (safe
									//--- default identical to the old behaviour) when _cands is empty.
									_w17Target = objNull; _nearD = 1e9;
									{
										_candTown = _x; _dd = 1e9;
										{ _dd = _dd min (_candTown distance _x) } forEach _cands;
										if (count _cands == 0) then {_dd = _candTown distance _hq};
										if (_dd < _nearD) then {_nearD = _dd; _w17Target = _candTown};
									} forEach _owned;
									if (isNull _w17Target) then {_w17Target = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity};
									_w17TargetPos = getPos _w17Target;
									_w17MarkerName = Format ["aicom_convoy_%1_%2", _sideText, round time];
									//--- B68 (Ray 2026-06-21) MARKER-LEAK FIX: this W17 supply-convoy marker was GLOBAL (createMarker / setMarker*, non-Local) = visible to ENEMY clients too (Ray: hostile teams must not see your supply patrols). The convoy truck already shows to its OWN side via the standard friendly unit-marker (Init_Unit SupplyVehicle path), so the global marker was a leak + redundant - removed. _w17MarkerName stays defined; the despawn block's deleteMarker on the now-uncreated name is a harmless no-op.
									//--- B68: (convoy marker removed - was enemy-visible global)
									//--- B68: (convoy marker removed)
									//--- B68: (convoy marker removed)
									[_w17Grp, _w17TargetPos, 100] Call AIPatrol;
									_w17Grp setBehaviour "AWARE"; _w17Grp setCombatMode "YELLOW";
									[_w17Truck, _w17Grp, _w17Target, _side, _w17MarkerName, _humanCmd] spawn {
										private ["_truck","_grp","_tgt","_tSide","_mk","_human","_el","_arr","_dead","_sup","_grant","_cmd","_cf"];
										_truck = _this select 0; _grp = _this select 1; _tgt = _this select 2; _tSide = _this select 3; _mk = _this select 4; _human = _this select 5;
										_el = 0; _arr = false; _dead = false;
										waitUntil { sleep 2; _el = _el + 2;
											if (!alive _truck) then {_dead = true};
											if (alive _truck && {(_truck distance _tgt) < 80}) then {_arr = true};
											if (_el >= 600) then {_arr = true};
											(_arr || _dead || gameOver) };
										if (_arr && {!_dead} && {alive _truck}) then {
											_sup = (_tSide) Call WFBE_CO_FNC_GetSideSupply; if (isNil "_sup") then {_sup = 0};
											_grant = 1200 min ((missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 99999]) - _sup);
											if (_grant > 0) then {[_tSide, _grant, "AI Commander Wildcard: supply convoy delivery.", false] Call ChangeSideSupply};
											if (_human) then {
												_cmd = (_tSide) Call WFBE_CO_FNC_GetCommanderTeam;
												if (!isNull _cmd) then {_cf = _cmd getVariable "wfbe_funds"; if (isNil "_cf") then {_cf = 0}; _cmd setVariable ["wfbe_funds", _cf + 5000, true]};
											} else {[_tSide, 5000] Call ChangeAICommanderFunds};
											diag_log ("AICOMSTAT|v2|EVENT|" + str _tSide + "|" + str (round (time / 60)) + "|CONVOY_DELIVERED|supply=" + str _grant);
										};
										deleteMarker _mk;
										{deleteVehicle _x} forEach (crew _truck);
										if (!isNull _truck) then {deleteVehicle _truck};
										if (!isNull _grp) then {deleteGroup _grp};
									};
									_detail = Format ["target=%1 truck=%2 humanCmd=%3", _w17Target getVariable ["name","?"], _w17TruckClass, _humanCmd];
								} else {
									if (!isNull _w17Grp) then {{deleteVehicle _x} forEach (units _w17Grp); deleteGroup _w17Grp};
									deleteVehicle _w17Truck;
									_result = "partial"; _detail = "W17 no group/soldier/owned town";
								};
							} else {_result = "ineligible"; _detail = Format ["W17 createVehicle null for %1", _w17TruckClass]};
						};

						//--- W18: BOUNTY HVT - one enemy officer at the spearhead enemy town with a GLOBAL marker. Bounty is paid ONCE
						//--- by CreateUnit's built-in Killed handler (RequestOnUnitKilled: player->AwardBounty, AI->ChangeTeamFunds);
						//--- the watcher ONLY cleans up marker+group on death / 30-min timeout (no manual award - would double-pay).
						case 18: {
							_w18Target = objNull; _w18Near = 1e9;
							{ _clustTown = _x; _dd = 1e9; { _dd = _dd min (_clustTown distance _x) } forEach _owned; if (count _owned == 0) then {_dd = _clustTown distance _hq}; if (_dd < _w18Near) then {_w18Near = _dd; _w18Target = _clustTown} } forEach _cands;
							_w18OfficerClass = missionNamespace getVariable [Format ["WFBE_%1_HVT_CLASS", str _enemySide], ""];
							if (_w18OfficerClass == "") then { _w18ParaL3 = missionNamespace getVariable [Format ["WFBE_%1PARACHUTELEVEL3", str _enemySide], []]; if (count _w18ParaL3 > 0) then {_w18OfficerClass = _w18ParaL3 select 0} };
							if (!isNull _w18Target && {_w18OfficerClass != ""}) then {
								_w18Pos = getPos _w18Target;
								_w18Grp = [_enemySide, "aicom-hvt"] Call WFBE_CO_FNC_CreateGroup;
								if (!isNull _w18Grp) then {
									_w18HVT = [_w18OfficerClass, _w18Grp, _w18Pos, _enemyID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _w18HVT) then {
										[_w18Grp, _w18Pos, 120] Call AIPatrol;
										_w18Grp setBehaviour "AWARE"; _w18Grp setCombatMode "RED";
										_w18MarkerID = Format ["hvt_%1_%2", _sideText, round time];
										createMarker [_w18MarkerID, _w18Pos];
										_w18MarkerID setMarkerType "mil_dot";
										_w18MarkerID setMarkerColor (if (_enemySide == west) then {"ColorBlue"} else {"ColorRed"});
										_w18MarkerID setMarkerText Format ["HVT (%1)", str _enemySide];
										[_w18HVT, _w18MarkerID, _w18Grp] spawn {
											private ["_hvt","_mk","_grp","_el"];
											_hvt = _this select 0; _mk = _this select 1; _grp = _this select 2; _el = 0;
											waitUntil { sleep 5; _el = _el + 5; (!alive _hvt) || _el >= 1800 || gameOver };
											deleteMarker _mk;
											{deleteVehicle _x} forEach (units _grp);
											if (!isNull _grp) then {deleteGroup _grp};
										};
										_detail = Format ["town=%1 class=%2 humanCmd=%3", _w18Target getVariable ["name","?"], _w18OfficerClass, _humanCmd];
									} else {deleteGroup _w18Grp; _result = "ineligible"; _detail = "W18 createUnit null"};
								} else {_result = "failed"; _detail = "W18 grp null at cap"};
							} else {_result = "ineligible"; _detail = "W18 no enemy town / officer class"};
						};

						//--- W19: HELIBORNE QRF - air-insert a QRF infantry squad to the FRIENDLY town MOST under threat.
						//--- FOUNDED + DELIVERED via the EXACT W6 Air Cavalry path (no new delivery invented): we ship the
						//--- SAME resolved air-assault template (_w6AirTemplate - first class is a troop-capable Air transport)
						//--- to a least-loaded HC as 'delegate-aicom-team' -> WFBE_CO_FNC_RunCommanderTeam (server-local fallback
						//--- if no HC). The ONLY difference from W6: the spawnPos we pass is the THREATENED FRIENDLY TOWN (not HQ),
						//--- so Common_RunCommanderTeam spawns + air-inserts the squad AT that town (its air-insertion LZ is the
						//--- spawnPos) - a true QRF reinforcement landing on the contested friendly town. FREE squad (price logged
						//--- only); rides the NORMAL team GC + brain orders (never a frozen AI).
						case 19: {
							//--- Re-resolve the elite air-assault template defensively (set in eligibility; mirror W6).
							if (count _w6AirTemplate == 0) then {
								_w6Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
								_w6TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
								_w6AirTier = -1;
								{
									_w6Cand = _x;
									if (count _w6Cand > 0) then {
										_w6Lead = _w6Cand select 0;
										if (isClass (configFile >> "CfgVehicles" >> _w6Lead)
										    && {_w6Lead isKindOf "Air"}
										    && {(getNumber (configFile >> "CfgVehicles" >> _w6Lead >> "transportSoldier")) > 0} && {({_x isKindOf "Man"} count _w6Cand) > 0} && {({_x isKindOf "Plane"} count _w6Cand) == 0}) then {
											_w6CandTier = 0;
											_w6Idx = _w6Tmpls find _w6Cand;
											if (_w6Idx >= 0 && {_w6Idx < count _w6TmplUps}) then {
												_w6UpArr = _w6TmplUps select _w6Idx;
												if (count _w6UpArr > WFBE_UP_AIR) then {_w6CandTier = _w6UpArr select WFBE_UP_AIR};
											};
											if (_w6CandTier > _w6AirTier) then {_w6AirTier = _w6CandTier; _w6AirTemplate = _w6Cand};
										};
									};
								} forEach _w6Tmpls;
							};
						
							if (count _owned == 0) then {
								_result = "ineligible";
								_detail = "W19 QRF side owns no town";
							} else {
								if (count _w6AirTemplate == 0) then {
									_result = "ineligible";
									_detail = "W19 QRF no air-assault transport template for side";
								} else {
									//--- MOST-THREATENED FRIENDLY town: among OWNED towns, the one with the most enemy
									//--- units within ~600m. FALLBACK if none strictly under threat: the friendly town
									//--- nearest the front (nearest any enemy town; if no enemy town, nearest the HQ-rear).
									_w19Town       = objNull;
									_w19BestThreat = 0;
									{
										_w19TownObj = _x;
										_w19Threat  = {alive _x && {(side _x) == _enemySide} && {(_x distance _w19TownObj) < 600}} count allUnits;
										if (_w19Threat > _w19BestThreat) then {_w19BestThreat = _w19Threat; _w19Town = _w19TownObj};
									} forEach _owned;
									//--- Fallback: friendly town nearest the front (nearest enemy town, else nearest HQ).
									if (isNull _w19Town) then {
										_w19NearD = 1e9;
										{
											_w19TownObj = _x;
											_w19D = 1e9;
											{ _w19D = _w19D min (_w19TownObj distance _x) } forEach _cands;
											if (count _cands == 0) then {_w19D = _w19TownObj distance _hq};
											if (_w19D < _w19NearD) then {_w19NearD = _w19D; _w19Town = _w19TownObj};
										} forEach _owned;
									};
						
									if (isNull _w19Town) then {
										_result = "ineligible";
										_detail = "W19 QRF no friendly town resolved";
									} else {
										//--- Spawn anchor = the threatened FRIENDLY town: the air-insertion LZ is the spawnPos,
										//--- so the QRF squad lands ON that town (the only divergence from W6, which anchors at HQ).
										_w19TownPos  = getPos _w19Town;
										_w19SpawnPos = _w19TownPos;
						
										//--- Telemetry-only template price (squad is FREE; mirrors W6's canonical lookup).
										_w19Price = 0;
										{
											_w19PriceCN = _x;
											_w19PriceUD = missionNamespace getVariable _w19PriceCN;
											if (!isNil "_w19PriceUD") then {_w19Price = _w19Price + (_w19PriceUD select QUERYUNITPRICE)};
										} forEach _w6AirTemplate;
						
										//--- FOUND ONE TEAM via the commander's own founding path (HC delegate -> server-local
										//--- fallback) - IDENTICAL to W6 Air Cavalry. Least-loaded HC keeps the big air lump off
										//--- an already-heavy HC. 4th delegate slot = skill 0 (no veteran boost), matching W6.
										_w19HcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
										if (!isNull _w19HcUnit) then {
											[_w19HcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _w6AirTemplate, _w19SpawnPos, 0]] Call WFBE_CO_FNC_SendToClient;
										} else {
											//--- No live HC: run the SAME function server-local (self-detects isServer for routing).
											[_sideID, _w6AirTemplate, _w19SpawnPos] Spawn WFBE_CO_FNC_RunCommanderTeam;
										};
						
										_detail = Format ["air_template=%1 lead=%2 tier=%3 town=%4 threat=%5 price=%6 free hc=%7 humanCmd=%8", _w6AirTemplate, _w6AirTemplate select 0, _w6AirTier, _w19Town getVariable ["name","?"], _w19BestThreat, _w19Price, !isNull _w19HcUnit, _humanCmd];
									};
								};
							};
						};

						//--- W20: CAPTURED CACHE - raise ONE random SUPPORT-line tier (Paratroopers/Supply/Gear) +1, bounded
						//--- by its configured max. SAME write + broadcast path as W16 Lend-Lease (wfbe_upgrades + NewIntel +
						//--- upgrade-complete), just over the support ids W16 never touches. Ineligible (all maxed / empty set)
						//--- -> clean "ineligible" result; the deck already redraws/falls back to W1 on a zeroed weight, and the
						//--- eligibility gate above zeroes _wW20 when nothing is raisable, so this case only runs when it can act.
						case 20: {
							//--- Re-derive the raisable support set defensively (mirrors W16 re-checking maxLevels here).
							_w20MaxLevels = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", _sideText], []];
							_w20SupIDs    = [WFBE_UP_PARATROOPERS, WFBE_UP_SUPPLYRATE, WFBE_UP_GEAR];
							_w20Raisable  = [];
							if (!isNil "_upgrades") then {
								{
									_w20SupID = _x;
									if (count _upgrades > _w20SupID && {count _w20MaxLevels > _w20SupID}) then {
										if ((_upgrades select _w20SupID) < (_w20MaxLevels select _w20SupID)) then {_w20Raisable = _w20Raisable + [_w20SupID]};
									};
								} forEach _w20SupIDs;
							};
							if (count _w20Raisable > 0) then {
								_w20ChosenID   = _w20Raisable select floor(random count _w20Raisable);
								_w20NewUpgrades = +_upgrades;
								_w20NewUpgrades set [_w20ChosenID, (_upgrades select _w20ChosenID) + 1];
								_logik setVariable ["wfbe_upgrades", _w20NewUpgrades, true];
								[_side, "NewIntelAvailable"] Spawn SideMessage;
								[_side, "HandleSpecial", ["upgrade-complete", _w20ChosenID, (_w20NewUpgrades select _w20ChosenID), false]] Call WFBE_CO_FNC_SendToClients;
								_w20TierName = switch (_w20ChosenID) do {case WFBE_UP_PARATROOPERS: {"Paratroopers"}; case WFBE_UP_SUPPLYRATE: {"Supply Rate"}; case WFBE_UP_GEAR: {"Gear"}; default {"?"}};
								_detail = Format ["support_tier=%1 new_level=%2 losing=%3", _w20TierName, _w20NewUpgrades select _w20ChosenID, _losing];
							} else {_result = "ineligible"; _detail = "W20 no raisable support tier"};
						};

						//--- W21: GUER DRIVER-DETONATED VBIED (Feature B, Ray 2026-06-16). The drawing AI commander funds a side-resistance
						//--- suicide car bomb aimed at the enemy-held town nearest our front. Spawn mirrors W17 Supply Convoy
						//--- (CreateVehicle+CreateGroup+CreateUnit+moveInDriver+self-clean watcher); drive/behaviour mirror the live
						//--- suicide-driver idiom in Support_Paratroopers.sqf:58-61 (CARELESS + BLUE + disableAI AUTOTARGET/TARGET +
						//--- doMove). KILL-BOUNTY is AUTOMATIC: CreateVehicle bounty=true attaches the killed-EH -> RequestOnUnitKilled
						//--- pays the player who DESTROYS it (last-hit window re-credits a shooter within 60s if the self-destruct
						//--- lands the final blow). MANDATORY GUER invariant: WFBE_IsTownDefenderAI=true on the driver (W9:758) or
						//--- GUER wakes WEST/EAST towns + blocks despawn. Detonation = stacked Sh_122_HE (122mm HE, confirmed loaded
						//--- both maps in the artillery configs); NOT Sh_125_HE/Bo_GBU12 (not loaded here - the allMines trap).
						case 21: {
							_w21VbiedClass = "hilux1_civil_2_covered";
							//--- TARGET: enemy town nearest our front (same nearest-front idiom W9/W18 use over _cands/_owned).
							_w21Target = objNull; _nearD = 1e9;
							{
								_candTown = _x; _dd = 1e9;
								{ _dd = _dd min (_candTown distance _x) } forEach _owned;
								if (count _owned == 0) then {_dd = _candTown distance _hq};
								if (_dd < _nearD) then {_nearD = _dd; _w21Target = _candTown};
							} forEach _cands;
							_soldierClass = missionNamespace getVariable ["WFBE_GUERRESSOLDIER", ""];
							if (!isNull _w21Target && {_soldierClass != ""} && {!isNull _hq}) then {
								_w21TargetPos = getPos _w21Target;
								//--- SPAWN ANCHOR ~700m outside the enemy town on a random bearing (SVBIED drives in from the edge).
								//--- FIX #8: re-roll bearing up to 20 times if the candidate lands in water
								//--- (mirrors Common_WaypointPatrolTown.sqf:48-52); then snap to the nearest
								//--- road node within 120m so the truck starts on a driveable surface.
								_w21Ang      = random 360;
								_w21SpawnPos = [(_w21TargetPos select 0) + 700 * sin _w21Ang, (_w21TargetPos select 1) + 700 * cos _w21Ang, 0];
								_w21Try = 0;
								while {surfaceIsWater _w21SpawnPos && {_w21Try < 20}} do {
									_w21Ang      = random 360;
									_w21SpawnPos = [(_w21TargetPos select 0) + 700 * sin _w21Ang, (_w21TargetPos select 1) + 700 * cos _w21Ang, 0];
									_w21Try = _w21Try + 1;
								};
								//--- Snap to nearest road node (A2-OA nearRoads; safe even if list is empty).
								_w21Roads = _w21SpawnPos nearRoads 120;
								if (count _w21Roads > 0) then {_w21SpawnPos = getPos (_w21Roads select 0)};
								//--- bounty=true (6th arg) -> killed-EH -> player who destroys it gets paid (RequestOnUnitKilled).
								_w21Truck = [_w21VbiedClass, _w21SpawnPos, resistance, random 360, false, true] Call WFBE_CO_FNC_CreateVehicle;
								if (!isNull _w21Truck) then {
									_w21Grp = [resistance, "aicom-vbied"] Call WFBE_CO_FNC_CreateGroup;
									if (!isNull _w21Grp) then {
										_w21Drv = [_soldierClass, _w21Grp, _w21SpawnPos, (resistance Call WFBE_CO_FNC_GetSideID)] Call WFBE_CO_FNC_CreateUnit;
										if (!isNull _w21Drv) then {
											_w21Drv moveInDriver _w21Truck;
											//--- MANDATORY GUER invariant (W9:758): tag town-defender or GUER wakes towns + blocks despawn.
											_w21Drv setVariable ["WFBE_IsTownDefenderAI", true, true];
											_w21Grp setBehaviour "CARELESS";     //--- ignore threats, just drive (Support_Paratroopers.sqf:59)
											_w21Grp setCombatMode "BLUE";        //--- hold fire
											{_w21Drv disableAI _x} forEach ["AUTOTARGET","TARGET"];   //--- Support_Paratroopers.sqf:61
											_w21Drv doMove _w21TargetPos;        //--- doMove - Support_Paratroopers.sqf:58
											//--- WATCHER: detonate on arrival (<25m) OR death OR 600s timeout, then clean up husk+group.
											[_w21Truck, _w21TargetPos, _w21Grp] spawn {
												private ["_veh","_tgt","_grp","_el","_boom","_p"];
												_veh = _this select 0; _tgt = _this select 1; _grp = _this select 2;
												_el = 0; _boom = false;
												waitUntil { sleep 1; _el = _el + 1;
													if (isNull _veh || {!alive _veh}) then {_boom = true};
													if (!isNull _veh && {alive _veh} && {(_veh distance _tgt) < 25}) then {_boom = true};
													if (_el >= 600) then {_boom = true};
													(_boom || gameOver) };
												//--- Detonate ONLY if it reached the town alive. A player who destroyed it en route already
												//--- earned the kill-bounty via the killed-EH; no secondary blast in that case.
												if (!isNull _veh && {alive _veh}) then {
													_p = getPosATL _veh;
													_veh setDamage 1;                 //--- pop the truck; killed-EH still fires for kill-credit
													"Sh_122_HE" createVehicle _p;     //--- stacked 122mm HE = large lethal crater (SADARM idiom)
													"Sh_122_HE" createVehicle _p;
													"Sh_122_HE" createVehicle _p;
												};
												sleep 3;
												{deleteVehicle _x} forEach (crew _veh);
												if (!isNull _veh) then {deleteVehicle _veh};
												if (!isNull _grp) then {deleteGroup _grp};
											};
											_detail = Format ["target=%1 chassis=%2 spawnD=%3 driver=%4", _w21Target getVariable ["name","?"], _w21VbiedClass, round (_w21SpawnPos distance _w21TargetPos), _soldierClass];
										} else {
											deleteVehicle _w21Truck; deleteGroup _w21Grp;
											_result = "partial"; _detail = "W21 createUnit null (driver)";
										};
									} else {
										deleteVehicle _w21Truck;
										_result = "partial"; _detail = "W21 group null at cap";
									};
								} else {
									_result = "ineligible"; _detail = Format ["W21 createVehicle null for %1", _w21VbiedClass];
								};
							} else {
								_result = "ineligible"; _detail = "W21 no enemy town / GUER soldier class";
							};
						};

						//--- W12: SPOILS OF WAR — 10-min double kill-bounty flag.
					//--- Flag lives on missionNamespace (survives spawn death).
					//--- Not stackable: checked above; re-draw if already active.
					//--- Human side: same flag, affects the normal bounty path.
					case 12: {
						_w12Exp = time + 600;
						missionNamespace setVariable [_w12Key, _w12Exp];
						_detail = Format ["expiry=t+%1 (%2 min) humanCmd=%3", 600, 10, _humanCmd];
					};
				};

				//--- Dual logging.
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: [WILDCARD] side=%1 draw=W%2 result=%3 detail=(%4)", _sideText, _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|WILDCARD_W" + str _draw + "|" + _result + "|" + _detail);

				//--- Announcement: human-side draws go to that side only; AI-side draws
				//--- broadcast to ALL clients (nil) so everyone sees what the AI drew.
				//--- BUG-FIX: previously only human-side draws were announced; AI draws were silent.
				_locMsg = if (_humanCmd) then {
					Format ["[Wildcard] Your forces receive: W%1 (%2)", _draw, _result]
				} else {
					_wNameMap = [
						[1,"War Chest"],[2,"Supply Drop"],[3,"Bonus Patrol"],
						[4,"Airborne Assault"],[6,"Air Cavalry"],[7,"Veteran Company"],
						[9,"Uprising"],[10,"Lucky Salvage"],
						[11,"Field Hospital"],[12,"Spoils of War"],
						[13,"Gunship Strike"],[14,"Iron Dome"],[15,"Black Market"],
						[16,"Lend-Lease"],[17,"Supply Convoy"],[18,"Bounty HVT"],
						[19,"Heliborne QRF"],[20,"Captured Cache"],[21,"Insurgent Car Bomb"]
					];
					_wName = Format ["W%1", _draw];
					{if ((_x select 0) == _draw) exitWith {_wName = _x select 1}} forEach _wNameMap;
					Format ["[Wildcard] AI Commander (%1) drew: %2", _sideText, _wName]
				};
				if (_humanCmd) then {
					[_sideText, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[nil, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;
				};

			}; //--- end isolation spawn

		}; //--- end !_skipAI
	}; //--- end !_bothHuman

	sleep _interval;
};
