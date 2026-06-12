/*
	AI Commander Wildcard Events - one free random event per side per interval.
	feat/ai-commander v2.0 (2026-06-12 final deck rebuild).
	Server-side; one instance spawned per side from Init_Server.
	Parameter: _this = side.

	GATE (v2): draws fire as long as AT LEAST ONE side is AI-commanded.
	  Disabled only when BOTH sides have a human commander.
	  AI-commanded side: normal draw, AI wallet.
	  Human-commanded side: draw fires too (PvE spice); human-side payout mapping applies.

	DECK (weights, total=103):
	  W1  War Chest         (20) Common    — AI funds +25% FUNDS_START.
	  W2  Supply Drop       (20) Common    — side supply +1500, capped.
	  W3  Bonus Patrol      (15) Common    — free patrol at current tier, cap bypass.
	  W6  Fortification Grant(8) Uncommon  — +2 base defenses beyond the 4-cap via AI_Commander_Base placer.
	  W7  Veteran Company   ( 8) Uncommon  — next founded team uses premium template + skill boost.
	  W10 Lucky Salvage     ( 8) Uncommon  — one sweep converting wrecks to AI funds (cap ~15000).
	  W11 Field Hospital    ( 8) Uncommon  — heal all wounded AI infantry + one-shot free re-founding flag.
	  W12 Spoils of War     ( 6) Uncommon  — 10-min double kill-bounty flag; not stackable.
	  W4  Airborne Assault  ( 4) Rare      — free max-level paradrop (PARACHUTELEVEL3) on spearhead town.
	  W8  Motor Pool Delivery(3) Rare      — free crewed top-tier vehicle, registers as AI team.
	  W9  Uprising          ( 3) Rare      — GUER attack force at enemy-held town nearest the front; cap 1 active.

	Human-side payout mapping:
	  W1 -> wfbe_funds on the commander's team (instead of AI wallet).
	  W7 -> re-draw (N/A for humans).
	  W3/W4/W8 -> assets join human side under server/HC AI control.
	  W12 -> doubles normal bounty path (flag consumed by RequestOnUnitKilled).
	  W9 -> CAN fire against human-commanded sides (pressure, not stat theft).
	  Draw announced via LocalizeMessage so players see the card.

	DE-CORRELATION: per-side jitter sleep (random 30) before each draw AND a
	second independent random call (random 1) mixed into the roll after the jitter,
	ensuring side workers diverge even on the same frame.

	ESCALATION: losing side (>=5 fewer towns than enemy) doubles W4/W7/W8/W9 weights.

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
				         "_w7Eligible",
				         "_w8Eligible","_w8BestClass","_w8BestPrice","_w8UD","_soldierClass",
				         "_w9Eligible","_guerTemplates","_guerUnits",
				         "_w10Eligible","_w12Eligible","_w12Key","_w12Exp",
				         "_wW1","_wW2","_wW3","_wW4","_wW6","_wW7","_wW8","_wW9","_wW10","_wW11","_wW12",
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
				         "_healed","_humanCmd","_skipAI","_w11Eligible",
				         "_dAng","_spawnPos","_dp","_placed","_dPos",
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

				//--- W6: fortification grant — Barracks alive, can afford one defense.
				_w6Eligible   = false;
				_defMax       = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_DEFENSES_MAX", 4];
				_defCount     = _logik getVariable ["wfbe_aicom_defenses", 0];
				_structures   = (_side) Call WFBE_CO_FNC_GetSideStructures;
				_defClass = if (_defCount % 2 == 0) then {
					missionNamespace getVariable [Format ["WFBE_%1DEFENSES_MG", _sideText], ""]
				} else {
					missionNamespace getVariable [Format ["WFBE_%1DEFENSES_AAPOD", _sideText], ""]
				};
				//--- BUG-FIX: typeName check BEFORE string comparison; _defClass may be an ARRAY
				//--- (defense list entry [classname, cost, ...]) in this mission's config.
				if (!isNil "_defClass") then {
					if (typeName _defClass == "ARRAY") then {if (count _defClass > 0) then {_defClass = _defClass select 0} else {_defClass = ""}};
					if (typeName _defClass == "STRING" && {_defClass != ""}) then {
						_defData  = missionNamespace getVariable _defClass;
						_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
						_defFunds = (_side) Call GetAICommanderFunds;
						_w6Eligible = false;
						{ if ((_x getVariable ["wfbe_structure_type", ""]) == "Barracks" && {alive _x}) exitWith {_w6Eligible = (_defFunds >= _defPrice)} } forEach _structures;
					};
				};

				//--- W7: veteran company — flag check (one per draw; humans re-draw).
				_w7Eligible = (!_humanCmd);

				//--- W8: motor pool — HQ alive, at least one factory built, best-price vehicle findable.
				_w8Eligible   = false;
				_w8BestClass  = "";
				_w8BestPrice  = -1;
				if (!isNull _hq && {alive _hq}) then {
					_facDefs = [["LIGHTUNITS",WFBE_UP_LIGHT],["HEAVYUNITS",WFBE_UP_HEAVY],["AIRCRAFTUNITS",WFBE_UP_AIR]];
					{
						_facEntry    = _x;
						_facListName = Format ["WFBE_%1%2", _sideText, _facEntry select 0];
						_facList     = missionNamespace getVariable [_facListName, []];
						{
							_unitClass = _x;
							_unitUD    = missionNamespace getVariable _unitClass;
							if (!isNil "_unitUD") then {
								_unitPrice = _unitUD select QUERYUNITPRICE;
								_unitUpReq = _unitUD select QUERYUNITUPGRADE;
								if (!isNil "_upgrades" && {count _upgrades > (_facEntry select 1)}) then {
									if (_unitUpReq <= (_upgrades select (_facEntry select 1)) && {_unitPrice > _w8BestPrice}) then {
										//--- Confirm factory exists alive.
										_facIdx   = (missionNamespace getVariable [Format ["WFBE_%1STRUCTURES",  _sideText], []]) find (_facEntry select 0);
										_facClass = "";
										if (_facIdx >= 0) then {
											_facNames = missionNamespace getVariable [Format ["WFBE_%1STRUCTURENAMES", _sideText], []];
											if (_facIdx < count _facNames) then {_facClass = _facNames select _facIdx};
										};
										if (_facClass != "") then {
											_facObj = objNull;
											{ if (typeOf _x == _facClass && {alive _x}) exitWith {_facObj = _x} } forEach _structures;
											if (!isNull _facObj) then {
												_w8BestClass = _unitClass;
												_w8BestPrice = _unitPrice;
												_w8Eligible  = true;
											};
										};
									};
								};
							};
						} forEach _facList;
					} forEach _facDefs;
				};

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

				//--- W12: spoils of war — not already active.
				_w12Key  = Format ["wfbe_aicom_spoils_%1", _sideText];
				_w12Exp  = missionNamespace getVariable _w12Key;
				_w12Eligible = (isNil "_w12Exp") || {_w12Exp <= time};

				//--- -----------------------------------------------------------------------
				//--- BASE WEIGHTS + ESCALATION
				//--- -----------------------------------------------------------------------
				_wW1  = 20; _wW2  = 20; _wW3  = 15;
				_wW6  =  8; _wW7  =  8; _wW10 =  8; _wW11 =  8; _wW12 =  6;
				_wW4  =  4; _wW8  =  3; _wW9  =  3;

				if (_losing) then {
					_wW4  = round(_wW4  * _eMult);
					_wW7  = round(_wW7  * _eMult);
					_wW8  = round(_wW8  * _eMult);
					_wW9  = round(_wW9  * _eMult);
				};

				//--- Zero ineligible cards.
				if (!_w3Eligible)  then {_wW3  = 0};
				if (!_w4Eligible)  then {_wW4  = 0};
				if (!_w6Eligible)  then {_wW6  = 0};
				if (!_w7Eligible)  then {_wW7  = 0};
				if (!_w8Eligible)  then {_wW8  = 0};
				if (!_w9Eligible)  then {_wW9  = 0};
				if (!_w10Eligible) then {_wW10 = 0};
				if (!_w11Eligible) then {_wW11 = 0};
				if (!_w12Eligible) then {_wW12 = 0};

				//--- Weight table: [cardID, weight]. Card IDs match W-numbers.
				_weights = [[1,_wW1],[2,_wW2],[3,_wW3],[4,_wW4],[6,_wW6],[7,_wW7],
				            [8,_wW8],[9,_wW9],[10,_wW10],[11,_wW11],[12,_wW12]];

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

					//--- W3: BONUS PATROL — free patrol at current tier, cap bypass.
					case 3: {
						_template = _pool select floor(random count _pool);
						_home     = _hq;
						if (count _owned > 0) then {_home = [_hq, _owned] Call WFBE_CO_FNC_GetClosestEntity};
						_active   = _logik getVariable ["wfbe_side_patrols", 0];
						_logik setVariable ["wfbe_side_patrols", _active + 1];
						_logik setVariable ["wfbe_side_patrol_last", time];
						_hcs  = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
						_live = [];
						{ if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]} } forEach _hcs;
						if (count _live > 0) then {
							[leader(_live select floor(random count _live)), "HandleSpecial", ["delegate-sidepatrol", _sideID, _template, _home]] Call WFBE_CO_FNC_SendToClient;
						} else {
							[_sideID, _template, _home] Spawn WFBE_CO_FNC_RunSidePatrol;
						};
						_detail = Format ["tier=%1 template=%2 from=%3 active_after=%4 hc=%5 humanCmd=%6", _tier, _template, _home getVariable ["name","?"], _active + 1, count _live > 0, _humanCmd];
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
								//--- Invoke Support_Paratroopers with playerTeam = commander group (AI gets the squad).
								_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
								if (isNull _cmdTeam) then {_cmdTeam = [_side, "aicom-wildcard"] Call WFBE_CO_FNC_CreateGroup};
								[nil, _side, _destination, _cmdTeam] Spawn (Compile preprocessFile "Server\Support\Support_Paratroopers.sqf");
								//--- Override the level variable so Paratroopers reads level 3.
								missionNamespace setVariable [Format ["WFBE_%1PARACHUTELEVEL", _sideText], 3];
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

					//--- W6: FORTIFICATION GRANT — +2 base defenses beyond the normal 4-cap.
					//--- Directly calls ConstructDefense twice via the Base placer pattern.
					case 6: {
						_hqPos  = getPos _hq;
						_placed = 0;
						_defFunds = (_side) Call GetAICommanderFunds;
						for "_dp" from 1 to 2 do {
							_defClass = if ((_defCount + _placed) % 2 == 0) then {
								missionNamespace getVariable [Format ["WFBE_%1DEFENSES_MG", _sideText], ""]
							} else {
								missionNamespace getVariable [Format ["WFBE_%1DEFENSES_AAPOD", _sideText], ""]
							};
							//--- BUG-FIX mirror: same typeName-first guard as eligibility block.
							if (!isNil "_defClass") then {
								if (typeName _defClass == "ARRAY") then {if (count _defClass > 0) then {_defClass = _defClass select 0} else {_defClass = ""}};
								if (typeName _defClass == "STRING" && {_defClass != ""}) then {
									_defData  = missionNamespace getVariable _defClass;
									_defPrice = if (!isNil "_defData") then {_defData select QUERYUNITPRICE} else {0};
									if (_defFunds >= _defPrice) then {
										//--- Ring placement around HQ (same helper pattern as AI_Commander_Base).
										_dAng  = random 360;
										_dPos  = [(_hqPos select 0) + (28 + random 14) * sin _dAng, (_hqPos select 1) + (28 + random 14) * cos _dAng, 0];
										[_defClass, _side, _dPos, random 360, true, true] Call ConstructDefense;
										[_side, -_defPrice] Call ChangeAICommanderFunds;
										_defFunds = _defFunds - _defPrice;
										_logik setVariable ["wfbe_aicom_defenses", _defCount + _placed + 1];
										_placed = _placed + 1;
									};
								};
							};
						};
						if (_placed > 0) then {
							_detail = Format ["placed=%1 defenses_now=%2", _placed, _defCount + _placed];
						} else {
							_result = "ineligible";
							_detail = "W6 no funds for defense";
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

					//--- W8: MOTOR POOL DELIVERY — spawn best-price crewed vehicle from buy lists,
					//--- register as an AI commander team.
					case 8: {
						if (_w8BestClass != "") then {
							_w8UD   = missionNamespace getVariable _w8BestClass;
							_hqPos  = getPos _hq;
							_dAng   = random 360;
							_spawnPos = [(_hqPos select 0) + (50 + random 30) * sin _dAng, (_hqPos select 1) + (50 + random 30) * cos _dAng, 0];
							_v = [_w8BestClass, _spawnPos, _side, random 360, true, true] Call Common_CreateVehicle;
							if (!isNull _v) then {
								//--- Crew the vehicle: commander/gunner from SOLDIER classname.
								_soldierClass = missionNamespace getVariable [Format ["WFBE_%1SOLDIER", _sideText], ""];
								_grp = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
								if (!isNull _grp && {_soldierClass != ""}) then {
									_sideIDLocal = (_side) Call WFBE_CO_FNC_GetSideID;
									_crew1 = [_soldierClass, _grp, _spawnPos, _sideIDLocal] Call WFBE_CO_FNC_CreateUnit;
									_crew2 = [_soldierClass, _grp, _spawnPos, _sideIDLocal] Call WFBE_CO_FNC_CreateUnit;
									if (!isNull _crew1) then {_crew1 moveInDriver _v};
									if (!isNull _crew2) then {_crew2 moveInGunner _v};
									//--- Register as AI team so AssignTowns picks it up.
									_grp setVariable ["wfbe_aicom_founded", true, true];
									_grp setVariable ["wfbe_funds", 0, true];
									_grp setVariable ["wfbe_side", _side];
									_grp setVariable ["wfbe_persistent", true];
									_grp setVariable ["wfbe_queue", []];
									_grp setVariable ["wfbe_vote", -1, true];
									[_grp, false] Call SetTeamAutonomous;
									[_grp, ""] Call SetTeamRespawn;
									[_grp, -1] Call SetTeamType;
									[_grp, "towns"] Call SetTeamMoveMode;
									[_grp, [0,0,0]] Call SetTeamMovePos;
									_existingTeams = _logik getVariable "wfbe_teams";
									if (isNil "_existingTeams") then {_existingTeams = []};
									_logik setVariable ["wfbe_teams", _existingTeams + [_grp], true];
									_detail = Format ["class=%1 price=%2 humanCmd=%3 grp=%4", _w8BestClass, _w8BestPrice, _humanCmd, _grp];
								} else {
									_detail = Format ["class=%1 but no group or soldier class", _w8BestClass];
									_result = "partial";
								};
							} else {
								_result = "ineligible";
								_detail = Format ["W8 createVehicle returned null for %1", _w8BestClass];
							};
						} else {
							_result = "ineligible";
							_detail = "W8 no eligible vehicle found";
						};
					};

					//--- W9: UPRISING — spawn a GUER attack force at enemy-held town nearest the front.
					//--- Cap: 1 active uprising per side (wfbe_aicom_uprising_active flag on logik).
					case 9: {
						//--- Find enemy town nearest our front.
						_targetTown = objNull;
						_nearD      = 1e9;
						{
							_dd = 1e9;
							{ _dd = _dd min (_x distance _this) } forEach _owned;
							if (count _owned == 0) then {_dd = _this distance _hq};
							if (_dd < _nearD) then {_nearD = _dd; _targetTown = _x};
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
						[4,"Airborne Assault"],[6,"Fortification Grant"],[7,"Veteran Company"],
						[8,"Motor Pool Delivery"],[9,"Uprising"],[10,"Lucky Salvage"],
						[11,"Field Hospital"],[12,"Spoils of War"]
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
