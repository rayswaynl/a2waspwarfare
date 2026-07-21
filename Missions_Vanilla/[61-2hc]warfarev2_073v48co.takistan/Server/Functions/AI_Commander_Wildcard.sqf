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

	REMOVED (Ray 2026-06-27) — five more cards pulled as boring/low-payoff (weights forced to 0, apply blocks left inert):
	  W7  Veteran Company   — REMOVED: invisible payoff (a flag on the next founded team); player sees nothing happen.
	  W14 Iron Dome         — REMOVED: dull, rarely matters.
	  W17 Supply Convoy     — REMOVED: dull, slow, easily ignored.
	  W18 Bounty HVT        — REMOVED: dull, rarely engaged.
	  W21 GUER VBIED        — REMOVED: boring/useless.

	ADDED (Ray 2026-06-27) — three visible combat-reinforcement cards (mirror the W6 Air Cavalry founding path):
	  W22 Top Gun          (6) Rare     — a fixed-wing fighter loiters the front ~180s hunting enemy aircraft, self-despawns.
	  W23 Armor Column     (7) Uncommon — founds one free TANK team (tank-led template) at HQ; brain orders it to the front.
	  W24 Technical Swarm  (6) Rare     — founds two free CAR-led gun-truck teams charging the front.

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
         "_bothHuman","_cmdTeam","_hq","_sideText","_jitter","_humanCmd","_skipAI","_wcCost","_wcCool","_wcKey","_wcLast","_wcFunds"];

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

		//--- PURCHASE GATE (WFBE_C_AI_COMMANDER_WILDCARD_COST > 0, claude-gaming 2026-07-07):
		//--- wildcards become a paid AI-commander action - the side spends wfbe_aicom_funds per draw
		//--- and may draw at most once per WFBE_C_AI_COMMANDER_WILDCARD_COOLDOWN seconds (30 min).
		//--- AI-commander only for now: a HUMAN-commanded side has no buy path yet, so under the
		//--- purchase model it gets NO auto-draw (the old free human-side draw is gated off here).
		//--- COST == 0 (default) leaves every branch below inert -> behaviour identical to legacy.
		_wcCost = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_COST", 0];
		if (!_skipAI && {_wcCost > 0}) then {
			if (_humanCmd) then {
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - purchase model (COST=%2), human commander has no buy path yet", _sideText, _wcCost]] Call WFBE_CO_FNC_AICOMLog;
				_skipAI = true;
			} else {
				_wcCool = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_WILDCARD_COOLDOWN", 1800];
				_wcKey  = Format ["WFBE_WILDCARD_LASTFIRE_%1", _sideText];
				_wcLast = missionNamespace getVariable [_wcKey, -99999];
				if ((time - _wcLast) < _wcCool) then {
					["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - wildcard cooldown (%2s of %3s left)", _sideText, round (_wcCool - (time - _wcLast)), _wcCool]] Call WFBE_CO_FNC_AICOMLog;
					_skipAI = true;
				};
				if (!_skipAI) then {
					_wcFunds = (_side) Call GetAICommanderFunds;
					if (_wcFunds < _wcCost) then {
						["INFORMATION", Format ["AI_Commander_Wildcard.sqf: draw skipped for %1 - cannot afford wildcard (have %2, need %3)", _sideText, round _wcFunds, _wcCost]] Call WFBE_CO_FNC_AICOMLog;
						_skipAI = true;
					} else {
						//--- Charge BEFORE dispatch and stamp the cooldown immediately (mirror Init_IcbmTel fire order: no double-fire race).
						[_side, -_wcCost] Call ChangeAICommanderFunds;
						missionNamespace setVariable [_wcKey, time];
						["INFORMATION", Format ["AI_Commander_Wildcard.sqf: %1 purchased a wildcard for %2 (funds %3 -> %4)", _sideText, _wcCost, round _wcFunds, round (_wcFunds - _wcCost)]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
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
				         "_w4LvlText","_destination",
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
	         "_w13Eligible","_w13AirList","_w13AttackClasses","_w13TargetTown","_w13MaxCluster","_w13BestDist","_w13Class","_w13Ang","_w13SpawnPos","_w13Heli","_w13Pilot","_w13TargetPos","_w13Grp","_w13PilotClass","_clustTown","_nearEnemies","_w13Enemies",
	         "_w14Eligible","_w14AAClass","_w14Target","_w14Pos","_w14Placed","_w14Ang","_w14DPos","_w14AA","_w14i","_w14Grp","_w14Gunner","_w14PilotClass",
	         "_w15Eligible","_w15Exp",
	         "_w16Eligible","_maxLevels","_raisableTiers","_chosenUpID","_newUpgrades","_tierName",
	         "_w17Eligible","_w17TruckClass","_w17Truck","_w17Grp","_w17Driver","_w17Gunner","_w17Target","_w17TargetPos","_w17MarkerName","_w17SpawnPos","_w17Ang",
	         "_w18Eligible","_w18OfficerClass","_w18ParaL3","_w18Pos","_w18Grp","_w18HVT","_w18MarkerID","_w18Target","_w18Near","_w1Eligible",
		         "_w19Eligible","_w19TownObj","_w19Town","_w19BestThreat","_w19Threat","_w19TownPos","_w19SpawnPos","_w19NearD","_w19D","_w19HcUnit","_w19Price","_w19PriceCN","_w19PriceUD","_wW19","_wW20",
		         "_w20Eligible","_w20SupIDs","_w20Raisable","_w20ChosenID","_w20NewUpgrades","_w20TierName","_w20MaxLevels","_w20SupID",
				         "_w21Eligible","_wW21","_w21VbiedClass","_w21Grp","_w21Truck","_w21Drv","_w21Target","_w21TargetPos","_w21SpawnPos","_w21Ang","_w21Try","_w21Roads",
		         "_wNameMap","_wName","_wDesc",
		         "_w22Eligible","_w22PlaneClass","_w22AirList","_w22Target","_w22Targets","_w22Ang","_w22SpawnPos","_w22Plane","_w22Grp","_w22PilotClass","_w22Pilot","_w22Gunner","_w22TargetPos","_wW22",
		         "_w23Eligible","_w23Template","_w23Tier","_w23Tmpls","_w23TmplUps","_w23Cand","_w23Lead","_w23CandTier","_w23Idx","_w23UpArr","_wW23",
		         "_w24Eligible","_w24Template","_w24Tier","_w24Tmpls","_w24TmplUps","_w24Cand","_w24Lead","_w24CandTier","_w24Idx","_w24UpArr","_w24n","_wW24",
		         "_mkPos","_mkLife","_mkColor","_mkType","_mkName","_mkBestTown","_mkBestScore","_mkT4","_mkDNear","_mkD","_mkScore"];

				_side     = _this select 0;
				_humanCmd = _this select 1;
				_logik    = (_side) Call WFBE_CO_FNC_GetSideLogic;
				_sideID   = (_side) Call WFBE_CO_FNC_GetSideID;
				_sideText = str _side;

				if (isNil "_logik") exitWith {};

				//--- WAR-CHEST REQUISITION consume (cmdcon44 economy-sink, claude 2026-07-07): the supervisor armed a
				//--- PAID early draw (team-cap-pinned + funds over FLOOR+COST). Debit HERE at draw time (never at arm
				//--- time) so a skipped or dead draw can never eat money silently. Re-verify the wallet still covers
				//--- COST while staying over FLOOR (Produce/TOPUP may have spent since the arm) and that the side is
				//--- still AI-commanded; otherwise drop the request without charge (the arm-side cooldown still backs
				//--- off re-arming). _paidDraw also zeroes W1 below (a paid draw must never roll the funds-refund card).
				private ["_paidDraw","_reqCost","_reqFloor","_reqFunds"];
				_paidDraw = false;
				if ((missionNamespace getVariable ["WFBE_C_AICOM2_REQDRAW_ENABLE", 0]) > 0 && {_logik getVariable ["wfbe_aicom_reqdraw_req", false]}) then {
					_logik setVariable ["wfbe_aicom_reqdraw_req", false];
					if (!_humanCmd) then {
						_reqCost  = missionNamespace getVariable ["WFBE_C_AICOM2_REQDRAW_COST", 75000];
						_reqFloor = missionNamespace getVariable ["WFBE_C_AICOM2_REQDRAW_FLOOR", 250000];
						_reqFunds = (_side) Call GetAICommanderFunds;
						if (_reqFunds >= (_reqCost + _reqFloor)) then {
							[_side, -_reqCost] Call ChangeAICommanderFunds;
							_paidDraw = true;
							["INFORMATION", Format ["AI_Commander_Wildcard.sqf: [%1] REQDRAW consumed - paid %2 for a requisitioned draw (funds %3 -> %4).", _sideText, _reqCost, _reqFunds, _reqFunds - _reqCost]] Call WFBE_CO_FNC_AICOMLog;
							diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|REQDRAW_SPEND|cost=" + str _reqCost + "|funds=" + str (_reqFunds - _reqCost));
						};
					};
				};

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
				if (!isNull _hq && {alive _hq} && {(count _owned > 0) || {count _cands > 0}} && {!isNil "_upgrades"} && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0} && {(count _owned) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3])}) then {  //--- B59 (Ray 2026-06-20): gate W6 Air Cavalry on air research + established towns (mirror W13/Produce) so no early/ungated Mi-24
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

				//--- W10: lucky salvage — cheap proxy: allDead covers wrecks without a broad mission-object scan.
				//--- The filtered allDead sweep runs only in the inert W10 apply block.
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
					{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Ka52","Ka52Black","Mi24_D","Mi24_V","Mi24_P","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su25_TK_EP1","Su34","Su39"]) then {_w13AttackClasses = _w13AttackClasses + [_x]} } forEach _w13AirList;
					if (count _w13AttackClasses > 0) then {
						//--- one allUnits pass: the alive/side filter is town-invariant, only the distance is per-town
						_w13Enemies = [];
						{ if (alive _x && {(side _x) == _enemySide}) then {_w13Enemies set [count _w13Enemies, _x]} } forEach allUnits;
						{ _clustTown = _x; _nearEnemies = {(_x distance _clustTown) < 300} count _w13Enemies; if (_nearEnemies >= 3) exitWith {_w13Eligible = true} } forEach _cands;
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
				//--- W16 raises only Light/Heavy/Air, so these three are disjoint from it. Artillery-tied ids stay
				//--- EXCLUDED here regardless of WFBE_C_AI_COMMANDER_ARTILLERY's default (flipped ON 2026-07-08,
				//--- fable/alife-arty-dwell) - deliberately out of scope for that change; see the note below.
				//--- Eligible when >=1 (non-arty) candidate tier is below max.
				_w20Eligible  = false;
				_w20MaxLevels = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", _sideText], []];
				//--- Build the support-id set. Paratroopers/SupplyRate/Gear are NON-arty and AI-usable.
				_w20SupIDs = [WFBE_UP_PARATROOPERS, WFBE_UP_SUPPLYRATE, WFBE_UP_GEAR];
				//--- (No arty ids are added here on purpose - fable/alife-arty-dwell 2026-07-08 flipped the master
				//---  flag's default ON but intentionally left this wildcard-cache hookup untouched (unrelated
				//---  behaviour, not requested). If arty upgrade ids are ever wanted here, gate on
				//---  (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ARTILLERY", 0]) > 0.)
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

				//--- W22: TOP GUN (2026-06-27) - air-superiority fighter loiters the front for a window and hunts
				//--- enemy aircraft. Eligible: HQ alive, AIR research >=1, established towns (mirror W6/W13 gate), and
				//--- the side fields a fixed-wing PLANE in WFBE_<side>AIRCRAFTUNITS (helis don't count - this is a jet).
				_w22Eligible   = false;
				_w22PlaneClass = "";
				if (!isNull _hq && {alive _hq} && {!isNil "_upgrades"} && {count _upgrades > WFBE_UP_AIR} && {(_upgrades select WFBE_UP_AIR) > 0} && {(count _owned) >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3])}) then {
					_w22AirList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
					{ if (_w22PlaneClass == "" && {isClass (configFile >> "CfgVehicles" >> _x)} && {_x isKindOf "Plane"}) then {_w22PlaneClass = _x} } forEach _w22AirList;
					if (_w22PlaneClass != "") then {_w22Eligible = true};
				};

				//--- W23: ARMOR COLUMN (2026-06-27) - found ONE free TANK-led team at HQ, brain orders it to the front.
				//--- SAME founding path as W6 Air Cavalry, but the resolved template's LEAD class isKindOf "Tank" and the
				//--- elite pick is by HEAVY-tier. Eligible: HQ alive, HEAVY research >=1, a tank-led template exists, a town to aim at.
				_w23Eligible = false;
				_w23Template = [];
				_w23Tier     = -1;
				if (!isNull _hq && {alive _hq} && {(count _owned > 0) || {count _cands > 0}} && {!isNil "_upgrades"} && {count _upgrades > WFBE_UP_HEAVY} && {(_upgrades select WFBE_UP_HEAVY) > 0}) then {
					_w23Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
					_w23TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
					{
						_w23Cand = _x;
						if (count _w23Cand > 0) then {
							_w23Lead = _w23Cand select 0;
							if (isClass (configFile >> "CfgVehicles" >> _w23Lead) && {_w23Lead isKindOf "Tank"}) then {
								_w23CandTier = 0;
								_w23Idx = _w23Tmpls find _w23Cand;
								if (_w23Idx >= 0 && {_w23Idx < count _w23TmplUps}) then {
									_w23UpArr = _w23TmplUps select _w23Idx;
									if (count _w23UpArr > WFBE_UP_HEAVY) then {_w23CandTier = _w23UpArr select WFBE_UP_HEAVY};
								};
								if (_w23CandTier > _w23Tier) then {_w23Tier = _w23CandTier; _w23Template = _w23Cand};
							};
						};
					} forEach _w23Tmpls;
					if (count _w23Template > 0) then {_w23Eligible = true};
				};

				//--- W24: TECHNICAL SWARM (2026-06-27) - found TWO free CAR-led (motorized gun-truck/HMMWV) teams charging
				//--- the front. SAME founding path; LEAD class isKindOf "Car", elite pick by LIGHT-tier. Eligible: HQ alive,
				//--- LIGHT research >=1, a car-led template exists, a town to aim at.
				_w24Eligible = false;
				_w24Template = [];
				_w24Tier     = -1;
				if (!isNull _hq && {alive _hq} && {(count _owned > 0) || {count _cands > 0}} && {!isNil "_upgrades"} && {count _upgrades > WFBE_UP_LIGHT} && {(_upgrades select WFBE_UP_LIGHT) > 0}) then {
					_w24Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
					_w24TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
					{
						_w24Cand = _x;
						if (count _w24Cand > 0) then {
							_w24Lead = _w24Cand select 0;
							if (isClass (configFile >> "CfgVehicles" >> _w24Lead) && {_w24Lead isKindOf "Car"}) then {
								_w24CandTier = 0;
								_w24Idx = _w24Tmpls find _w24Cand;
								if (_w24Idx >= 0 && {_w24Idx < count _w24TmplUps}) then {
									_w24UpArr = _w24TmplUps select _w24Idx;
									if (count _w24UpArr > WFBE_UP_LIGHT) then {_w24CandTier = _w24UpArr select WFBE_UP_LIGHT};
								};
								if (_w24CandTier > _w24Tier) then {_w24Tier = _w24CandTier; _w24Template = _w24Cand};
							};
						};
					} forEach _w24Tmpls;
					if (count _w24Template > 0) then {_w24Eligible = true};
				};

				_wW1  = 17; _wW2  = 17; _wW3  =  0;  //--- W3 (Bonus Patrol) REMOVED 2026-06-16 (Ray): obsolete - patrol cap was lowered. Weight forced 0 -> card can NEVER be drawn; apply block left inert.
				_wW6  =  8; _wW7  =  0; _wW10 =  0; _wW11 =  8; _wW12 =  6;  //--- W6 = AIR CAVALRY (Uncommon, weight 8). W7 (Veteran Company) REMOVED 2026-06-27 (Ray): boring/no visible payoff. Weight forced 0 -> never drawn; apply block left inert. W10 (Lucky Salvage) REMOVED 2026-06-16 (Ray): salvage moved to the cleaner-tied Salvage Lottery.
				_wW4  =  6; _wW9  =  0;  //--- W4 Rare weight 6. W9 (Uprising) REMOVED 2026-06-16 (Ray): too invasive. Weight forced 0 -> card can NEVER be drawn; apply block left inert (W8 RETIRED 2026-06-15).
				_wW20 =  6;  //--- W20 = CAPTURED CACHE (Uncommon, weight 6 - mirrors W16 Lend-Lease; raises a random SUPPORT-line tier).
				_wW13 =  6; _wW18 =  0;  //--- rebalance 2026-06-14: W13 (Rare) up 4->6. W18 (Bounty HVT) REMOVED 2026-06-27 (Ray): boring/useless. Weight forced 0 -> never drawn; apply block left inert.
				_wW19 =  5;  //--- W19 = HELIBORNE QRF (Rare, weight 5).
				_wW14 =  0; _wW15 =  6; _wW16 =  6; _wW17 =  0;  //--- W14 (Iron Dome) + W17 (Supply Convoy) REMOVED 2026-06-27 (Ray): boring/useless. Weights forced 0 -> never drawn; apply blocks left inert.
				_wW21 =  0;  //--- W21 (GUER VBIED) REMOVED 2026-06-27 (Ray): boring/useless. Weight forced 0 -> never drawn; apply block left inert.
				_wW22 =  6; _wW23 =  7; _wW24 =  6;  //--- NEW 2026-06-27 (Ray): W22 Top Gun (Rare), W23 Armor Column (Uncommon), W24 Technical Swarm (Rare) - all visible combat reinforcements; escalate when losing.

				if (_losing) then {
					_wW4  = round(_wW4  * _eMult);
					_wW6  = round(_wW6  * _eMult);  //--- Air Cavalry is now a COMBAT reinforcement: a losing side draws it more (mirrors W4/W8/W9 escalation).
					//--- _wW7 escalation REMOVED 2026-06-27 (Ray): W7 (Veteran Company) pulled from the deck (base weight 0). No-op kept inert.
					//--- _wW9 escalation REMOVED 2026-06-16 (Ray): W9 (Uprising) is pulled from the deck (base weight 0). No-op kept inert.
					_wW13 = round(_wW13 * _eMult);
					//--- _wW18 escalation REMOVED 2026-06-27 (Ray): W18 (Bounty HVT) pulled from the deck (base weight 0). No-op kept inert.
					_wW19 = round(_wW19 * _eMult);  //--- losing side draws the QRF reinforcement more (mirrors W4/W8/W9).
					_wW22 = round(_wW22 * _eMult);  //--- Top Gun: a losing side that owns the air draws air-superiority more.
					_wW23 = round(_wW23 * _eMult);  //--- Armor Column: losing side draws the heavy reinforcement more.
					_wW24 = round(_wW24 * _eMult);  //--- Technical Swarm: losing side draws the fast reinforcement more.
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
				if (!_w22Eligible) then {_wW22 = 0};
				if (!_w23Eligible) then {_wW23 = 0};
				if (!_w24Eligible) then {_wW24 = 0};

				//--- REQDRAW (cmdcon44): a PAID draw must never roll W1 War Chest (funds refund = circular sink).
				//--- Usually already 0 via the funds-rich eligibility skip above, but FUNDS_START is per-side config -
				//--- keep the guarantee explicit.
				if (_paidDraw) then {_wW1 = 0};

				//--- Weight table: [cardID, weight]. Card IDs match W-numbers.
				//--- W8 (Motor Pool Delivery) RETIRED 2026-06-15: it spawned a wfbe_persistent=true vehicle that NEVER
				//--- despawned (worst perf/leak card) + a heavy eligibility scan. Slot 8 is GONE, not reused. W20
				//--- (Captured Cache) is a NEW id appended below - it does NOT reuse the freed 8.
				_weights = [[1,_wW1],[2,_wW2],[4,_wW4],[6,_wW6],[11,_wW11],[12,_wW12],[13,_wW13],[15,_wW15],[16,_wW16],[19,_wW19],[20,_wW20],[22,_wW22],[23,_wW23],[24,_wW24]];

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
						_roll    = ((random _cumSum) + _entropy * 0.0001) min (_cumSum - 0.00001);
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
						_maxSupply = missionNamespace getVariable ["WFBE_C_MAX_ECONOMY_SUPPLY_LIMIT", 40000];
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
								//--- A1 FIX (2026-07-15): the old override wrote WFBE_<side>PARACHUTELEVEL (no level suffix), a
								//--- variable Support_Paratroopers.sqf never reads (it derives the level from wfbe_upgrades), so an
								//--- unresearched side (level 0) errored on the nil PARACHUTELEVEL0 key - and the 10s restore wrote
								//--- the snapshot default 0 back into the global. The level-3 override is now passed explicitly as
								//--- the optional 5th Support_Paratroopers argument (race-free, no global state).
								_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
								if (isNull _cmdTeam) then {
									_cmdTeam = [_side, "aicom-wildcard"] Call WFBE_CO_FNC_CreateGroup;
									//--- W4 GROUP-LEAK FIX (owner order 2026-07-17, round-2 bughunt item 1): this fallback group (taken
									//--- when the side has no live HQ commander team yet) was created bare and never registered in
									//--- wfbe_teams, unlike the standard AICOM founding path (Server_HandleSpecial.sqf "aicom-team-created",
									//--- ~417-418; the path W6/W19/W23 use) - so the per-side 144-group-cap GC (server_groupsGC.sqf:93)
									//--- never saw it and could never reap it: every AI-commanded W4 draw permanently leaked one live
									//--- paratrooper group toward the cap. Register it the same way "aicom-team-created" does.
									private ["_w4Teams"];
									_w4Teams = _logik getVariable ["wfbe_teams", []];
									_logik setVariable ["wfbe_teams", _w4Teams + [_cmdTeam], true];
								};
								[nil, _side, _destination, _cmdTeam, 3] Spawn (Compile preprocessFile "Server\Support\Support_Paratroopers.sqf");
								_detail = Format ["target=%1 level=3 model=%2 humanCmd=%3", _bestTown getVariable ["name","?"], _w4Model, _humanCmd];
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

					//--- W8 (MOTOR POOL DELIVERY) RETIRED 2026-06-15: case handler removed. Draw 8 can no longer be
					//--- selected (absent from the weights table), so no switch case is needed and none is defined here.

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
							{ if (_x in ["AH64D","AH64D_EP1","AH1Z","Ka50","Ka52","Ka52Black","Mi24_D","Mi24_V","Mi24_P","A10","A10_US_EP1","AV8B","AV8B2","Su25_Ins","Su25_TK_EP1","Su34","Su39"]) then {_w13AttackClasses = _w13AttackClasses + [_x]} } forEach _w13AirList;
							_w13TargetTown = objNull; _w13MaxCluster = 0; _w13BestDist = 1e9;
							//--- one allUnits pass: the alive/side filter is town-invariant, only the distance is per-town
							_w13Enemies = [];
							{ if (alive _x && {(side _x) == _enemySide}) then {_w13Enemies set [count _w13Enemies, _x]} } forEach allUnits;
							{ _clustTown = _x; _nearEnemies = {(_x distance _clustTown) < 300} count _w13Enemies;
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
											//--- ATTACK-HELI GUNNER (flag WFBE_C_AIR_ATTACK_GUNNER, default 0/byte-identical): the W13
											//--- gunship's main armament fires from the GUNNER seat - pilot-only flies but never engages.
											//--- Mount a gunner (mirrors B62, Server_GuerAirDef.sqf:378-387), gated on an empty gunner seat.
											if ((missionNamespace getVariable ["WFBE_C_AIR_ATTACK_GUNNER", 0]) > 0 && {(_w13Heli emptyPositions "gunner") > 0}) then {
												private "_w13Gunner"; _w13Gunner = [_w13PilotClass, _w13Grp, _w13SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
												if (!isNull _w13Gunner) then { _w13Gunner moveInGunner _w13Heli; };
											};
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

						//--- W12: SPOILS OF WAR — 10-min double kill-bounty flag.
					//--- Flag lives on missionNamespace (survives spawn death).
					//--- Not stackable: checked above; re-draw if already active.
					//--- Human side: same flag, affects the normal bounty path.
					case 12: {
						_w12Exp = time + 600;
						missionNamespace setVariable [_w12Key, _w12Exp];
						_detail = Format ["expiry=t+%1 (%2 min) humanCmd=%3", 600, 10, _humanCmd];
					};

					//--- W22: TOP GUN (2026-06-27) - spawn one fixed-wing fighter that loiters the front for 180s and
					//--- engages enemy aircraft/ground (COMBAT/RED), then self-despawns. Spawn/crew/despawn idiom mirrors
					//--- W13 Gunship Strike; the difference is a PLANE class + a longer loiter window over the front.
					case 22: {
						_w22AirList = missionNamespace getVariable [Format ["WFBE_%1AIRCRAFTUNITS", _sideText], []];
						_w22PlaneClass = "";
						{ if (_w22PlaneClass == "" && {isClass (configFile >> "CfgVehicles" >> _x)} && {_x isKindOf "Plane"}) then {_w22PlaneClass = _x} } forEach _w22AirList;
						_w22Target  = objNull;
						_w22Targets = _logik getVariable "wfbe_aicom_targets";
						if (!isNil "_w22Targets" && {count _w22Targets > 0}) then {_w22Target = _w22Targets select 0};
						if (isNull _w22Target && {count _cands > 0}) then {_w22Target = _cands select floor(random count _cands)};
						if (_w22PlaneClass != "" && {!isNull _hq}) then {
							_hqPos       = getPos _hq;
							_w22Ang      = random 360;
							_w22SpawnPos = [(_hqPos select 0) + 4000 * sin _w22Ang, (_hqPos select 1) + 4000 * cos _w22Ang, 1000];
							_w22Plane    = [_w22PlaneClass, _w22SpawnPos, _side, random 360, true, true] Call WFBE_CO_FNC_CreateVehicle;
							if (!isNull _w22Plane) then {
								_w22Grp        = [_side, "aicom-topgun"] Call WFBE_CO_FNC_CreateGroup;
								_w22PilotClass = missionNamespace getVariable [Format ["WFBE_%1PILOT", _sideText], ""];
								if (!isNull _w22Grp && {_w22PilotClass != ""}) then {
									_w22Pilot = [_w22PilotClass, _w22Grp, _w22SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _w22Pilot) then {
										_w22Pilot moveInDriver _w22Plane;
										//--- PLANE GUNNER (flag WFBE_C_AIR_ATTACK_GUNNER, default 0/byte-identical): the W22 top-gun
										//--- plane pick is the side's first Plane class, which can be a TWO-seat airframe (Su34: the
										//--- WSO/gunner seat fires the guided armament) - it flew pilot-only and never engaged with
										//--- those weapons. Mount a gunner too, mirroring B62 (Server_GuerAirDef.sqf:378-387) and the
										//--- merged AirResp/W13 mounts (#1027/#1028). Gated on an EMPTY gunner seat, so single-seat
										//--- fixed-wings (A10/AV8B/Su25) are unaffected even when the flag is armed. The 180s teardown
										//--- above already deletes ALL crew ({deleteVehicle _x} forEach (crew _pl)), covering the gunner.
										if ((missionNamespace getVariable ["WFBE_C_AIR_ATTACK_GUNNER", 0]) > 0 && {(_w22Plane emptyPositions "gunner") > 0}) then {
											_w22Gunner = [_w22PilotClass, _w22Grp, _w22SpawnPos, _sideID] Call WFBE_CO_FNC_CreateUnit;
											if (!isNull _w22Gunner) then { _w22Gunner moveInGunner _w22Plane; };
										};
										_w22Plane flyInHeight 600;
										_w22Grp setBehaviour "COMBAT"; _w22Grp setCombatMode "RED";
										_w22TargetPos = if (!isNull _w22Target) then {getPos _w22Target} else {_hqPos};
										[_w22Grp, _w22TargetPos, 800] Call AIPatrol;
										[_w22Plane, _w22Grp] spawn {
											private ["_pl","_grp"];
											_pl = _this select 0; _grp = _this select 1;
											sleep 180;
											{deleteVehicle _x} forEach (crew _pl);
											if (!isNull _pl) then {deleteVehicle _pl};
											if (!isNull _grp) then {deleteGroup _grp};
										};
										_detail = Format ["class=%1 loiter=%2 window=180s", _w22PlaneClass, if (!isNull _w22Target) then {_w22Target getVariable ["name","?"]} else {"HQ"}];
									} else {
										deleteVehicle _w22Plane; deleteGroup _w22Grp;
										_result = "partial"; _detail = Format ["W22 no pilot for %1", _w22PlaneClass];
									};
								} else {
									deleteVehicle _w22Plane;
									_result = "partial"; _detail = "W22 no group/pilot class";
								};
							} else {
								_result = "ineligible"; _detail = Format ["W22 createVehicle null for %1", _w22PlaneClass];
							};
						} else {
							_result = "ineligible"; _detail = "W22 no plane class / HQ";
						};
					};

					//--- W23: ARMOR COLUMN (2026-06-27) - found ONE free TANK team via the commander's OWN founding path
					//--- (HC delegate 'delegate-aicom-team' -> WFBE_CO_FNC_RunCommanderTeam server-local fallback), EXACTLY
					//--- like W6 Air Cavalry. The template (tank lead + escort + dismounts) registers in wfbe_teams and the
					//--- brain orders it to a spearhead town - never a frozen AI, rides the normal team GC. FREE squad.
					case 23: {
						if (count _w23Template == 0) then {
							_w23Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
							_w23TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
							_w23Tier = -1;
							{
								_w23Cand = _x;
								if (count _w23Cand > 0) then {
									_w23Lead = _w23Cand select 0;
									if (isClass (configFile >> "CfgVehicles" >> _w23Lead) && {_w23Lead isKindOf "Tank"}) then {
										_w23CandTier = 0; _w23Idx = _w23Tmpls find _w23Cand;
										if (_w23Idx >= 0 && {_w23Idx < count _w23TmplUps}) then {_w23UpArr = _w23TmplUps select _w23Idx; if (count _w23UpArr > WFBE_UP_HEAVY) then {_w23CandTier = _w23UpArr select WFBE_UP_HEAVY}};
										if (_w23CandTier > _w23Tier) then {_w23Tier = _w23CandTier; _w23Template = _w23Cand};
									};
								};
							} forEach _w23Tmpls;
						};
						if (count _w23Template == 0) then {
							_result = "ineligible"; _detail = "W23 no tank template for side";
						} else {
							_hqPos    = getPos _hq;
							_w6HcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
							if (!isNull _w6HcUnit) then {
								[_w6HcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _w23Template, _hqPos, 0]] Call WFBE_CO_FNC_SendToClient;
							} else {
								[_sideID, _w23Template, _hqPos] Spawn WFBE_CO_FNC_RunCommanderTeam;
							};
							_detail = Format ["armor_template=%1 lead=%2 tier=%3 hc=%4", _w23Template, _w23Template select 0, _w23Tier, !isNull _w6HcUnit];
						};
					};

					//--- W24: TECHNICAL SWARM (2026-06-27) - found TWO free CAR-led (gun-truck/HMMWV) teams the same way,
					//--- aimed at the front: a fast, light swarm. Two foundings (1s apart); the side-team cap in
					//--- RunCommanderTeam naturally bounds it if the side is already at capacity.
					case 24: {
						if (count _w24Template == 0) then {
							_w24Tmpls   = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", _sideText], []];
							_w24TmplUps = missionNamespace getVariable [Format ["WFBE_%1AITEAMUPGRADES", _sideText], []];
							_w24Tier = -1;
							{
								_w24Cand = _x;
								if (count _w24Cand > 0) then {
									_w24Lead = _w24Cand select 0;
									if (isClass (configFile >> "CfgVehicles" >> _w24Lead) && {_w24Lead isKindOf "Car"}) then {
										_w24CandTier = 0; _w24Idx = _w24Tmpls find _w24Cand;
										if (_w24Idx >= 0 && {_w24Idx < count _w24TmplUps}) then {_w24UpArr = _w24TmplUps select _w24Idx; if (count _w24UpArr > WFBE_UP_LIGHT) then {_w24CandTier = _w24UpArr select WFBE_UP_LIGHT}};
										if (_w24CandTier > _w24Tier) then {_w24Tier = _w24CandTier; _w24Template = _w24Cand};
									};
								};
							} forEach _w24Tmpls;
						};
						if (count _w24Template == 0) then {
							_result = "ineligible"; _detail = "W24 no motorized template for side";
						} else {
							_hqPos = getPos _hq;
							for "_w24n" from 1 to 2 do {
								_w6HcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
								if (!isNull _w6HcUnit) then {
									[_w6HcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _w24Template, _hqPos, 0]] Call WFBE_CO_FNC_SendToClient;
								} else {
									[_sideID, _w24Template, _hqPos] Spawn WFBE_CO_FNC_RunCommanderTeam;
								};
								sleep 1;
							};
							_detail = Format ["motor_template=%1 lead=%2 tier=%3 count=2", _w24Template, _w24Template select 0, _w24Tier];
						};
					};
				};

				//--- Dual logging.
				["INFORMATION", Format ["AI_Commander_Wildcard.sqf: [WILDCARD] side=%1 draw=W%2 result=%3 detail=(%4)", _sideText, _draw, _result, _detail]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|WILDCARD_W" + str _draw + "|" + _result + "|" + _detail);

				//--- Announcement: human-side draws go to that side only; AI-side draws
				//--- broadcast to ALL clients (nil) so everyone sees what the AI drew.
				//--- BUG-FIX: previously only human-side draws were announced; AI draws were silent.
				//--- Resolve a player-facing NAME + EFFECT DESCRIPTION for the drawn card from a single
				//--- source-of-truth map [id, name, what-it-does]. Used by BOTH the human-side and AI-side
				//--- announcements so players always see WHAT the wildcard does, not just its name/number
				//--- (Ray 2026-06-27). Inert ids (3/9/10) kept for completeness; they can never be drawn.
				_wNameMap = [
					[1,"War Chest","bonus war funds for the side"],
					[2,"Supply Drop","+1500 supply delivered to the front"],
					[4,"Airborne Assault","elite paratroopers drop on the front line"],
					[6,"Air Cavalry","a free elite air-assault squad deploys to the front"],
					[11,"Field Hospital","all wounded infantry are healed"],
					[12,"Spoils of War","double kill-bounty for the next 10 minutes"],
					[13,"Gunship Strike","an attack aircraft strafes a troop cluster"],
					[15,"Black Market","50% production discount for the next 10 minutes"],
					[16,"Lend-Lease","a vehicle tier (light/heavy/air) is upgraded"],
					[19,"Heliborne QRF","a helicopter inserts a QRF at a threatened town"],
					[20,"Captured Cache","a support tier (paratroopers/supply/gear) is upgraded"],
					[22,"Top Gun","a fighter flies cover over the front and hunts enemy aircraft"],
					[23,"Armor Column","a free tank platoon rolls to the front"],
					[24,"Technical Swarm","a wave of gun-trucks charges the front"]
				];
				_wName = Format ["W%1", _draw];
				_wDesc = "";
				{if ((_x select 0) == _draw) exitWith {_wName = _x select 1; _wDesc = _x select 2}} forEach _wNameMap;
				if ((_draw in [20]) && {_result in ["applied"]} && {!(isNil "_w20TierName")} && {!(isNil "_w20ChosenID")} && {!(isNil "_w20NewUpgrades")}) then {
					_wDesc = Format ["%1 support reaches level %2", _w20TierName, _w20NewUpgrades select _w20ChosenID];
				};

				//--- -----------------------------------------------------------------------
				//--- MAP MARKER (feature: wildcard events show on the map for the OWNING side)
				//--- -----------------------------------------------------------------------
				//--- Only the events with a clear single world position + a bounded lifetime get a
				//--- marker; pure-economy/flag draws (W1/W2/W11/W12/W15/W16/W20 + the inert ids) have
				//--- no battlefield location, so they get none. We resolve the position from the SAME
				//--- target var the apply block already computed (re-using its work; no second scan),
				//--- and a lifetime that matches the event's own watcher/loiter window so the marker
				//--- expires WITH the event - one marker per active event, always cleaned up.
				//---
				//--- LOCALITY: the marker is broadcast via WFBE_CO_FNC_SendToClients to the SIDE object
				//--- (_side) - Client_HandlePVF matches a SIDE destination against sideJoined, so ONLY
				//--- this side's clients run WildcardMarker.sqf and createMarkerLocal. The enemy never
				//--- sees it. The marker uses the side colour + a distinct icon + a short label.
				if (_result == "applied") then {
					_mkPos  = [];
					_mkLife = 0;
					_mkType = "mil_objective";
					switch (_draw) do {
						//--- W4 Airborne Assault: the drop town (enemy/neutral front town). Short info beat.
						case 4:  {if (!isNil "_bestTown" && {!isNull _bestTown}) then {_mkPos = getPos _bestTown}; _mkLife = 120; _mkType = "mil_pickup"};
						//--- W6 Air Cavalry: the front town the squad is aimed at (HQ-spawned, brain-ordered fwd).
						case 6:  {if (!isNil "_w6BestTown" && {!isNull _w6BestTown}) then {_mkPos = getPos _w6BestTown}; _mkLife = 300; _mkType = "mil_pickup"};
						//--- W13 Gunship Strike: the strafed cluster town. Lifetime = the 90s strike window.
						case 13: {if (!isNil "_w13TargetPos") then {_mkPos = _w13TargetPos}; _mkLife = 90; _mkType = "mil_destroy"};
						//--- W19 Heliborne QRF: the threatened FRIENDLY town the QRF lands on.
						case 19: {if (!isNil "_w19TownPos") then {_mkPos = _w19TownPos}; _mkLife = 300; _mkType = "mil_pickup"};
						//--- W22 Top Gun: the loiter point over the front. Lifetime = the 180s loiter window.
						case 22: {if (!isNil "_w22TargetPos") then {_mkPos = _w22TargetPos}; _mkLife = 180; _mkType = "mil_circle"};
						//--- W23/W24 handled below (their apply spawns at HQ; mark the front town they head to).
						case 23: {};
						case 24: {};
					};
					//--- W23 Armor Column / W24 Technical Swarm: spawn at HQ, brain orders them to the front.
					//--- Mark the best-scored spearhead/front town (the SAME selection W4/W6 use) so the side
					//--- sees WHERE the reinforcement is headed.
					if (_draw == 23 || {_draw == 24}) then {
						_mkBestTown  = objNull;
						_mkBestScore = -1e9;
						{
							_mkT4    = _x;
							_mkDNear = 1e9;
							{ if ((_x getVariable ["sideID","?"]) == _sideID) then {_mkD = _mkT4 distance _x; if (_mkD < _mkDNear) then {_mkDNear = _mkD}} } forEach towns;
							if (_mkDNear > 1e8 && {!isNull _hq}) then {_mkDNear = _mkT4 distance _hq};
							_mkScore = (_mkT4 getVariable ["supplyValue", 0]) - (_mkDNear / 150);
							if (_mkScore > _mkBestScore) then {_mkBestScore = _mkScore; _mkBestTown = _mkT4};
						} forEach _cands;
						if (!isNull _mkBestTown) then {_mkPos = getPos _mkBestTown; _mkLife = 300; _mkType = "mil_arrow2"};
					};

					if (count _mkPos > 0 && {_mkLife > 0}) then {
						_mkColor = if (_side == west) then {"ColorBlue"} else {"ColorRed"};
						_mkName  = Format ["wc_%1_%2_%3", _sideText, _draw, round time];
						//--- CREATE on the owning side only (SIDE destination -> sideJoined match in Client_HandlePVF).
						[_side, "WildcardMarker", ["create", _mkName, _mkPos, _mkColor, _mkType, _wName, _wDesc]] Call WFBE_CO_FNC_SendToClients;
						//--- Self-expiring watcher: delete the marker on the SAME side after the event lifetime.
						//--- One marker per event; this is the only deletion path (no leak, no spam).
						[_side, _mkName, _mkLife] spawn {
							private ["_s","_n","_lf"];
							_s = _this select 0; _n = _this select 1; _lf = _this select 2;
							sleep _lf;
							[_s, "WildcardMarker", ["delete", _n]] Call WFBE_CO_FNC_SendToClients;
						};
					};
				};

				_locMsg = if (_humanCmd) then {
					Format ["[Wildcard] Your forces receive %1 - %2.", _wName, _wDesc]
				} else {
					Format ["[Wildcard] AI Commander (%1) drew %2 - %3.", _sideText, _wName, _wDesc]
				};
				if (_humanCmd) then {
					//--- ROUTING FIX 2026-06-27: send to the SIDE object, not str _side. Client_HandlePVF only
					//--- matches a SIDE destination against sideJoined; a STRING destination is treated as a player
					//--- UID (matches nobody) - so the old [_sideText,...] human-side popup silently reached no one.
					[_side, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;
				} else {
					[nil, "LocalizeMessage", ["Wildcard", _locMsg]] Call WFBE_CO_FNC_SendToClients;
				};

			}; //--- end isolation spawn

		}; //--- end !_skipAI
	}; //--- end !_bothHuman

	//--- WAR-CHEST REQUISITION early wake (cmdcon44, claude 2026-07-07): flag OFF keeps the original single
	//--- full-interval sleep (inert path, byte-identical behaviour). Flag ON waits in 30s chunks and breaks
	//--- early when the supervisor arms a paid draw, so the requisition fires within ~30s+jitter instead of
	//--- up to a full interval later.
	if ((missionNamespace getVariable ["WFBE_C_AICOM2_REQDRAW_ENABLE", 0]) <= 0) then {
		sleep _interval;
	} else {
		private ["_reqSlept"];
		_reqSlept = 0;
		while {_reqSlept < _interval && {!(_logik getVariable ["wfbe_aicom_reqdraw_req", false])}} do {
			sleep 30;
			_reqSlept = _reqSlept + 30;
		};
	};
};
