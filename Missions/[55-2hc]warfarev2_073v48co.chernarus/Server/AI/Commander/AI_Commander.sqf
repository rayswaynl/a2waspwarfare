/*
	AI Commander - per-side supervisor.
	feat/ai-commander. Server-side; one instance spawned per present side from Init_Server.
	Parameter: _this = side OR [side, ownerGeneration] from the watchdog.

	Always running. Each tick it asks "is the AI commanding this side right now, and how?"
	  - No human commander -> FULL: executor + town auto-assign + economy (types/upgrade/produce).
	  - Human commander     -> ASSIST (hybrid): executor + town auto-assign for DELEGATED teams only,
	                           no economy (rule A: the AI never spends while a human commands).
	The executor (every tick) turns explicit Move/Patrol/Defend orders into waypoints - for the AI's own
	orders AND the human commander's (which are otherwise inert). Covers every takeover path (vote, re-vote,
	disconnect) with no edits to the vote/assign files.
*/

private ["_args","_side","_logik","_active","_ltTypes","_ltUp","_ltTown","_ltProd","_ltBase","_ltTeams","_ltStrat","_ltMHQReloc","_ltBrief","_ltBaseSell","_ltDisband","_ltBeacon","_humanCmd","_cmdTeam","_prevHuman","_state","_prevState","_doctrine","_order","_factory","_program","_winner","_held","_myID","_ownerKey","_ownerSeq","_passedOwner","_ltStat","_elMin","_towns","_supply","_funds","_fTeams","_eTeams","_upgLvls","_upgCsv","_upgArr","_i","_cbrResearchAppended","_richThreshold","_fundsRich","_dynTarget","_richFlag","_prevRich","_stipendActive","_prevStipendActive","_stipendTowns","_ltStipend","_tickS","_stipendFunds","_stipendSupply","_stipendFundsGrant","_stipendSupplyGrant","_stipendMaxTime","_dual","_tickUniKey","_tickUni","_noHumanSince","_canBuild","_grpCount","_hcCount","_briefTowns","_briefFunds","_briefTeams","_briefDoctrine","_briefStrat","_briefTs","_ltIntent","_ltPara","_prevDelegate","_aiDelegate","_aiStrategy"];

_args = _this;
_side = if (typeName _args == "ARRAY") then {_args select 0} else {_args};
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_myID = (_side) Call WFBE_CO_FNC_GetSideID;
_ownerKey = format ["wfbe_aicom_owner_%1", _myID];
_passedOwner = -1;
if (typeName _args == "ARRAY" && {count _args > 1}) then {_passedOwner = _args select 1};
if (_passedOwner >= 0) then {
	_ownerSeq = _passedOwner;
	missionNamespace setVariable [_ownerKey, _ownerSeq];
} else {
	_ownerSeq = (missionNamespace getVariable [_ownerKey, 0]) + 1;
	missionNamespace setVariable [_ownerKey, _ownerSeq];
};

//--- Wait for full server init before commanding.
waitUntil {sleep 1; !(isNil "serverInitFull")};

//--- SUPERVISOR HEARTBEAT (B69): seed the per-side liveness beat BEFORE the loop so the
//--- variable exists the moment the loop starts (closes the 'never stamped yet' ambiguity).
//--- Server-only; integer key by side ID; a watchdog reads time-(this) > N*TICK => loop dead.
missionNamespace setVariable [format ["wfbe_aicom_hb_%1", _myID], time];
diag_log ("AICOMHB|v2|" + (str _side) + "|" + (str _myID) + "|SEED|" + (str (round time)) + "|owner=" + str _ownerSeq);

//--- B69 worker-stagger: one-time per-side phase jitter so the two supervisors' economy
//--- workers fall on different frames (mirrors AI_Commander_Wildcard.sqf de-correlation idiom).
//--- Skip when only one AI side is present (nothing to de-correlate). random/sleep = A2-OA core.
if (count (WFBE_PRESENTSIDES - [resistance]) > 1) then {
	private "_phaseJitter";
	_phaseJitter = random (missionNamespace getVariable ["WFBE_C_AICOM_SUPERVISOR_JITTER", 7]);
	if (_phaseJitter > 0) then {
		["INFORMATION", Format ["AI_Commander.sqf: [%1] spawn phase-jitter %2s (worker de-correlation).", str _side, _phaseJitter]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|0|SUPERVISOR_JITTER|" + str _phaseJitter);
		sleep _phaseJitter;
	};
};

//--- V0.2: pick a doctrine once - the primary factory path this AI builds around.
if (isNil {_logik getVariable "wfbe_aicom_doctrine"}) then {
	//--- AICOM v2 (wiki + Miksuu strategy): de-correlate the doctrine from the ENEMY's for varied matches (was a
		//--- blind coin flip - both sides could roll identical plans). If the enemy already picked, take the OTHER route.
		private ["_eSideD","_eLogikD","_eDocD"];
		_eSideD = if (_side == west) then {east} else {west};
		_eLogikD = (_eSideD) Call WFBE_CO_FNC_GetSideLogic;
		_eDocD = if (isNil "_eLogikD" || {isNull _eLogikD}) then {""} else {_eLogikD getVariable ["wfbe_aicom_doctrine", ""]};
		_doctrine = if (_eDocD == "HF") then {"LF"} else {if (_eDocD == "LF") then {"HF"} else {if (random 1 > 0.5) then {"HF"} else {"LF"}}};
	_logik setVariable ["wfbe_aicom_doctrine", _doctrine];
	["INFORMATION", Format ["AI_Commander.sqf: [%1] doctrine picked: %2 (primary factory path).", str _side, _doctrine]] Call WFBE_CO_FNC_AICOMLog;

	//--- V0.4: doctrine research PROGRAM. The upgrade worker always takes the FIRST entry
	//--- whose level is not yet reached, so a prepended program IS the strategy: rush the
	//--- doctrine factory to 3 with Barracks/Gear mixed in until Gear 3 + Barracks 2, then
	//--- fall through to the faction's curated default order (= branch out).
	//--- Duplicates in the tail are harmless (the worker skips reached levels).
	_order = missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side];
	if (!isNil "_order" && {!isNil "WFBE_UP_PATROLS"}) then {
		_factory = if (_doctrine == "HF") then {WFBE_UP_HEAVY} else {WFBE_UP_LIGHT};
		_program = [
			[WFBE_UP_BARRACKS,1],
			[_factory,1],
			[WFBE_UP_GEAR,1],
			[WFBE_UP_SUPPLYRATE,1],
			[WFBE_UP_PATROLS,1],
			[_factory,2],
			[WFBE_UP_GEAR,2],
			[WFBE_UP_BARRACKS,2],
			[_factory,3],
			[WFBE_UP_GEAR,3],
			[WFBE_UP_SUPPLYRATE,2],
			[WFBE_UP_PATROLS,2],
			[WFBE_UP_PATROLS,3]
		];
		missionNamespace setVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], _program + _order];
		["INFORMATION", Format ["AI_Commander.sqf: [%1] doctrine research program set (%2: factory id %3 to lvl 3, Gear 3, Barracks 2, then branch out).", str _side, _doctrine, _factory]] Call WFBE_CO_FNC_AICOMLog;

		//--- V0.6 task 49c: experital-awareness research extension (nil-guarded).
		//--- Convoys (PATROLS lvl 4): activate when the side's LEVELS array shows PATROLS max >= 4.
		//--- CBRADAR (upgrades 1..2): activate when WFBE_UP_CBRADAR constant exists and the
		//--- LEVELS array is long enough to include it. Both are no-ops on this mission.
		_upgLvls = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", str _side], []];
		if (!isNil "WFBE_UP_PATROLS" && {count _upgLvls > WFBE_UP_PATROLS} && {(_upgLvls select WFBE_UP_PATROLS) >= 4}) then {
			_order = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], []];
			missionNamespace setVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], _order + [[WFBE_UP_PATROLS,4]]];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] experital scaffold: Convoys (PATROLS lvl 4) appended to research program.", str _side]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|0|SCAFFOLD_RESEARCH|Convoys-PATROLS4");
		};
		//--- CBR research is NOT appended here unconditionally.
		//--- It is appended reactively in the main loop when wfbe_aicom_arty_threat is set.
		//--- (WFBE_UP_CBRADAR guard kept so the flag is checked only when CBR exists in upgrades.)
	};
};

_ltTypes = 0; _ltUp = 0; _ltTown = 0; _ltProd = 0; _ltBase = 0; _ltTeams = 0; _ltStrat = 0; _ltStat = -301; _ltBrief = 0; _ltBaseSell = -1e6; _ltMHQReloc = 0; _ltDisband = 0;
_ltBeacon = 0; //--- AICOM FORWARD SPAWN-BEACON throttle (Approach A): gated WFBE_C_AICOM_SPAWNBEACON_ENABLE (default 0 = INERT), paced to WFBE_C_AICOM_SPAWNBEACON_INTERVAL.
_ltPara = 0; //--- AICOM PARATROOPS throttle: cheap O(towns) scan + drop attempt; paced to the town interval (worker self-cooldowns the actual drop, gated WFBE_C_AICOM_PARATROOPS_ENABLE, default-OFF).
_ltIntent = 0; //--- COMMAND CONSOLE: throttle for the AI-INTENT publish block (now runs on the _active gate, not _canBuild, so the readout refreshes + reaches JIP/assist clients).
_prevHuman = false; _prevState = "";
_prevDelegate = true; //--- cmdcon27 THREAD B: init TRUE to match the new delegate default (avoids a spurious edge-reset at loop start). prev value of the AI-maneuver delegate flag, for the edge-reset that neutralises sticky orders on a mode flip.
_cbrResearchAppended = false; //--- Tracks whether CBR research was reactively appended this round.
//--- V0.7 bootstrap stipend state.
_prevStipendActive = false;
_ltStipend = -1e9;
_noHumanSince = -1;

["INITIALIZATION", Format ["AI_Commander.sqf: supervisor started for %1 (owner generation %2).", str _side, _ownerSeq]] Call WFBE_CO_FNC_AICOMLog;

//--- WAR-BRIEF: one-time [AICOM BOOT] snapshot (server groups, HC count, aiMax, starting funds).
_grpCount = 0;
{ if (side _x == _side) then {_grpCount = _grpCount + 1} } forEach allGroups;
_hcCount = count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
["INFORMATION", Format ["AI_Commander.sqf: [AICOM BOOT] side=%1 serverGroups=%2 HCs=%3 aiMax=%4 startFunds=%5", str _side, _grpCount, _hcCount, missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", -1], (_side) Call GetAICommanderFunds]] Call WFBE_CO_FNC_AICOMLog;

//--- AI COMMANDER LOCK startup notice.
if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {
	["INFORMATION", Format ["AI_Commander.sqf: [%1] WFBE_C_AI_COMMANDER_LOCK=1 - AI retains full command regardless of human slot occupancy.", str _side]] Call WFBE_CO_FNC_AICOMLog;
};

while {!gameOver && {(missionNamespace getVariable [_ownerKey, _ownerSeq]) == _ownerSeq}} do {
	//--- SUPERVISOR HEARTBEAT (B69): unconditional per-tick liveness beat. MUST be the first
	//--- statement, above the _active gate and before EVERY worker Call, so even a worker that
	//--- throws (e.g. createVehicle on a malformed classname, AI_Commander_Base.sqf:503-516)
	//--- leaves this tick's stamp behind; the loop then dies and the beat freezes. A watchdog
	//--- treats time - (missionNamespace getVariable ['wfbe_aicom_hb_<id>', -1]) > k*TICK as DEAD.
	//--- Distinct from wfbe_aicom_lastbrief (300s, written inside the loop -> useless as liveness).
	missionNamespace setVariable [format ["wfbe_aicom_hb_%1", _myID], time];

	_active = false;
	if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_ENABLED", 0]) > 0) then { //--- FIX7 (Ray): defaulted [..,0] - the bare single-arg getVariable threw if nil at an early-boot race.
		if (alive ((_side) Call WFBE_CO_FNC_GetSideHQ)) then {_active = true};
	};

	if (_active) then {
		_cmdTeam  = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
		_humanCmd = false;
		if (!isNull _cmdTeam) then {
			if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
		};

		//--- AI COMMANDER LOCK: when lock=1, treat _humanCmd as false so AI keeps full command
		//--- even if a human occupies the commander slot (eval/night protection).
		if ((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_LOCK", 0]) > 0) then {
			_humanCmd = false;
		};

		//--- Human just left -> clear leftover explicit orders so full-auto retakes cleanly.
		if (_prevHuman) then {
			if (!_humanCmd) then {
				//--- cmdcon27 THREAD A: HC-resident teams (wfbe_aicom_hc) drive ONLY off wfbe_aicom_order, not wfbe_teammode -
				//--- so the reset MUST bump their order seq (mirror AI_Commander_Strategy.sqf:398-400) or they keep their
				//--- STALE order + stay Executor-ineligible -> stuck ~2-3.5 min. Server-local teams ignore the order var.
				{ if (!isNull _x) then {
					[_x, "towns"] Call SetTeamMoveMode;
					_x setVariable ["wfbe_exec_sig", []];
					if (_x getVariable ["wfbe_aicom_hc", false]) then {
						_x setVariable ["wfbe_aicom_order",
							[(if (isNil {_x getVariable "wfbe_aicom_order"}) then {-1} else {(_x getVariable "wfbe_aicom_order") select 0}) + 1,
							 "towns", getPos (leader _x)], true];
					};
				} } forEach (_logik getVariable ["wfbe_teams", []]);
					_logik setVariable ["wfbe_aicom_focus", objNull]; _logik setVariable ["wfbe_aicom_focus_t0", -1e9]; //--- AICOM v2 fix (wiki cross-check): clear the commander FOCUS when a human commander leaves so a departed commander's "Move All" doesn't tunnel-vision the auto-AI for the 600s TTL.
			};
		};
		_prevHuman = _humanCmd;

		//--- COMMAND CONSOLE squad-command mode (claude-gaming 2026-06-29): read the player's AI-maneuver DELEGATE flag
		//--- (set ON/OFF from the war room via aicom-ai-command). cmdcon27 THREAD B: Default-ABSENT => TRUE => AI keeps running Strategy/Allocate when a human commands; player flips war-room to DIRECT (false) to drive.
		//--- When ON, the AI maneuver-brain (Strategy/Snapshot/Allocate) runs UNDER the human commander while the player
		//--- keeps the economy. DELEGATE EDGE-RESET: on a flip of _aiDelegate, neutralise every team (clear its move
		//--- mode + exec-sig + the commander FOCUS) so the Executor/AssignTowns don't fight over a team carrying the
		//--- previous owner's sticky order - same reset the human-left path (above) uses. A2-OA: Bool != Bool is ILLEGAL,
		//--- so compare via 0/1 scalars.
		_aiDelegate = _logik getVariable ["wfbe_aicom_player_delegate", true]; //--- cmdcon27 THREAD B: AI keeps running Strategy/Allocate BY DEFAULT when a human takes command; player flips war-room to DIRECT (false) to drive.
		if ((if (_aiDelegate) then {1} else {0}) != (if (_prevDelegate) then {1} else {0})) then {
			//--- cmdcon27 THREAD A: bump HC-team order seq on the delegate flip too (same stuck-teams root cause).
			{ if (!isNull _x) then {
				[_x, "towns"] Call SetTeamMoveMode;
				_x setVariable ["wfbe_exec_sig", []];
				if (_x getVariable ["wfbe_aicom_hc", false]) then {
					_x setVariable ["wfbe_aicom_order",
						[(if (isNil {_x getVariable "wfbe_aicom_order"}) then {-1} else {(_x getVariable "wfbe_aicom_order") select 0}) + 1,
						 "towns", getPos (leader _x)], true];
				};
			} } forEach (_logik getVariable ["wfbe_teams", []]);
			_logik setVariable ["wfbe_aicom_focus", objNull];
			_logik setVariable ["wfbe_aicom_focus_t0", -1e9];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] squad-command mode flipped (AI-strategy delegate now %2) - teams reset to neutral.", str _side, if (_aiDelegate) then {"ON"} else {"OFF"}]] Call WFBE_CO_FNC_AICOMLog;
		};
		_prevDelegate = _aiDelegate;

		//--- B36 (Ray 2026-06-15) #3a: build-grace tracker. _noHumanSince = when the side last became
		//--- human-commander-less (-1 while a human commands). The AI builds only after the grace window
		//--- with no human commander - from match start, re-armed each time a human commander leaves.
		if (_humanCmd) then {
			_noHumanSince = -1;
		} else {
			if (_noHumanSince < 0) then {_noHumanSince = time};
		};
		_canBuild = (_noHumanSince >= 0) && {(time - _noHumanSince) >= (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_BUILD_GRACE", 300])};

		//--- COMMAND CONSOLE squad-command mode (claude-gaming 2026-06-29): _aiStrategy widens the maneuver-brain gate.
		//--- The AI runs Strategy/Snapshot/Allocate when it holds full command (_canBuild) OR when a human commander has
		//--- DELEGATED maneuver to it (_aiDelegate, war-room "AI STRATEGY"). _canBuild is left EXACTLY as-is so the
		//--- economy block (Base/Upgrade/MHQ/Teams/Produce/wealth/CBR) stays player-owned in delegate mode (Ray: the
		//--- player keeps the economy). Squad CREATION (HYBRID-REFILL), AssignTowns, Execute and the unstuck/driver
		//--- logic already run on the _humanCmd/_active gates and KEEP running here (Ray: it also creates squads + runs
		//--- the unstuck logic) - they are NOT gated by this.
		_aiStrategy = _canBuild || _aiDelegate;

		//--- Lifecycle log + running flag (full command only; income routes to aicom_funds only with no human).
		_state = if (_humanCmd) then {"assist"} else {"full"};
		if (_state != _prevState) then {
			_logik setVariable ["wfbe_aicom_running", !_humanCmd];
			if (_state == "full")   then {["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander ACTIVE (full command).", str _side]] Call WFBE_CO_FNC_AICOMLog};
			if (_state == "assist") then {["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander ASSIST (hybrid - human commander; executor + town auto-assign + B67 team-found/refill quartermaster, base/upgrade OFF).", str _side]] Call WFBE_CO_FNC_AICOMLog};
			_prevState = _state;
		};

		//--- Executor: every tick (responsive explicit orders, human or AI).
		(_side) Call WFBE_SE_FNC_AI_Com_Execute;

		//--- COMMAND CONSOLE: player war-room ARTILLERY-HERE resolver - every tick (so it bites under a HUMAN commander,
		//--- where the autonomous Strategy arty block is dormant). Self-gates on WFBE_C_AICOM_PLAYER_ARTY + a fresh,
		//--- friendly-fire-guarded, fire-once request; nil-guarded so it is inert until the function is registered.
		if (!isNil "WFBE_SE_FNC_AI_Com_PlayerArty") then {(_side) Call WFBE_SE_FNC_AI_Com_PlayerArty};

		//--- AICOM PARATROOPS (claude-gaming 2026-06-29): tier+structure-gated AI paratroop reinforcement drop.
		//--- Paced to the town interval (cheap O(towns) threat scan); the worker HARD-gates on the researched
		//--- Paratroopers upgrade tier + a live Tactical Center (CommandCenter) structure, self-cooldowns the
		//--- actual drop, and exits under a human commander. Flag-gated default-OFF (WFBE_C_AICOM_PARATROOPS_ENABLE),
		//--- nil-guarded so it is inert until the worker function is registered. Reuses the player KAT_Paratroopers fn.
		if (!isNil "WFBE_SE_FNC_AI_Com_Paratroops" && {time - _ltPara > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOWN_INTERVAL")}) then {
			(_side) Call WFBE_SE_FNC_AI_Com_Paratroops; _ltPara = time;
		};

		//--- AI-INTENT PUBLISH (moved out of _canBuild, claude-gaming 2026-06-28): publish the side-keyed INTENT /
		//--- OBJECTIVE / ACTIVE / FOCUS / TEAMS / FUNDS reads the client RHUD row + the command-console intent readout
		//--- consume. Runs on the _active gate (HQ alive + AICOM on) every strategy interval, so it REFRESHES even
		//--- under a human commander (assist) and reaches JIP joiners - the old _canBuild placement left it frozen/
		//--- blank whenever the AI was not in full-build mode. PV only on change (cheap). The intent wording reflects
		//--- the AI's own strat_mode/targets, which are fresh exactly when the AI holds command (when the readout shows).
		if ((missionNamespace getVariable ["WFBE_C_AICOM_INTENT_HUD", 1]) > 0 && {time - _ltIntent > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL", 60])}) then {
			_ltIntent = time;
			private ["_sm","_tg","_objT","_objNm","_intent","_iKey","_nKey","_pKey"];
			_sm = _logik getVariable ["wfbe_aicom_strat_mode", "spearhead"];
			_tg = _logik getVariable ["wfbe_aicom_targets", []];
			_objT = if (count _tg > 0) then {_tg select 0} else {objNull};
			_objNm = if (!isNull _objT) then {_objT getVariable ["name", "?"]} else {""};
			_intent = switch (_sm) do {
				case "strike":    {"ASSAULTING HQ"};
				case "laststand": {"DEFENDING BASE"};
				case "relief":    {"DEFENDING"};
				default { if (_objNm != "") then {"ATTACKING " + _objNm} else {"ADVANCING"} };
			};
			_iKey = format ["WFBE_AICOM_INTENT_%1", _myID];
			_nKey = format ["WFBE_AICOM_OBJNAME_%1", _myID];
			_pKey = format ["WFBE_AICOM_OBJPOS_%1", _myID];
			if ((missionNamespace getVariable [_iKey, ""]) != _intent) then {
				missionNamespace setVariable [_iKey, _intent]; publicVariable _iKey;
			};
			if ((missionNamespace getVariable [_nKey, ""]) != _objNm) then {
				missionNamespace setVariable [_nKey, _objNm]; publicVariable _nKey;
				missionNamespace setVariable [_pKey, (if (!isNull _objT) then {getPos _objT} else {[0,0,0]})]; publicVariable _pKey;
			};
			//--- ACTIVE = the AI actually HOLDS command this side now (no human commander) so a player's nudge will
			//--- steer it; FOCUS_NAME = the player-set focus town (TTL'd) or "" when none/expired. PV only on change.
			//--- A2-OA: == / != do NOT support Bool operands - never compare two Bools directly. Convert to a 0/1
			//--- scalar and compare those (PV only when the flag actually flips), so this stays change-cheap + A2-safe.
			private ["_aKey","_fKey","_active2","_activeN","_prevActiveN","_focusT","_focusT0","_focusNm"];
			_aKey = format ["WFBE_AICOM_ACTIVE_%1", _myID];
			_active2 = !_humanCmd;
			_activeN = if (_active2) then {1} else {0};
			//--- -1 sentinel default forces a publish the FIRST tick (var still nil), so JIP/early clients always
			//--- read a real ACTIVE value instead of the client-side default.
			private "_prevA"; _prevA = missionNamespace getVariable _aKey;
			_prevActiveN = -1;
			if (!isNil "_prevA") then {_prevActiveN = if (_prevA) then {1} else {0}};
			if (_activeN != _prevActiveN) then {
				missionNamespace setVariable [_aKey, _active2]; publicVariable _aKey;
			};
			_fKey = format ["WFBE_AICOM_FOCUS_NAME_%1", _myID];
			_focusT  = _logik getVariable "wfbe_aicom_focus";
			_focusT0 = _logik getVariable "wfbe_aicom_focus_t0";
			_focusNm = "";
			if (!isNil "_focusT" && {!isNull _focusT} && {!isNil "_focusT0"} && {(time - _focusT0) < (missionNamespace getVariable ["WFBE_C_AICOM2_FOCUS_TTL", 600])}) then {
				_focusNm = _focusT getVariable ["name", "?"];
			};
			if ((missionNamespace getVariable [_fKey, ""]) != _focusNm) then {
				missionNamespace setVariable [_fKey, _focusNm]; publicVariable _fKey;
			};
			private ["_tKey","_uKey","_teamsN","_fundsN"];
			_tKey = format ["WFBE_AICOM_TEAMS_%1", _myID];
			_uKey = format ["WFBE_AICOM_FUNDS_%1", _myID];
			_teamsN = count (_logik getVariable ["wfbe_teams", []]);
			_fundsN = (_side) Call GetAICommanderFunds;
			if ((missionNamespace getVariable [_tKey, -1]) != _teamsN) then {
				missionNamespace setVariable [_tKey, _teamsN]; publicVariable _tKey;
			};
			if ((missionNamespace getVariable [_uKey, -1]) != _fundsN) then {
				missionNamespace setVariable [_uKey, _fundsN]; publicVariable _uKey;
			};
		};

		//--- Town auto-assign: worker self-gates per team by delegation.
		if (time - _ltTown > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOWN_INTERVAL")) then {
			(_side) Call WFBE_SE_FNC_AI_Com_AssignTowns; _ltTown = time;
		};

		//--- B69 (bootstrap-stipend-out-of-canbuild): the 0-town survival drip is a LIFELINE, not a
		//--- 'spend'. It runs on the _active gate (HQ alive + AICOM enabled) so a one-tick human
		//--- blip that re-arms _noHumanSince (zeroing _canBuild for 300s) cannot suspend the only income
		//--- a broke 0-town side has. Internal guards unchanged: 0 towns AND time<MAXTIME AND 60s rate.
		//--- Funds route to the SEPARATE AICOM treasury (ChangeAICommanderFunds) -> no contention with a
		//--- human commander's spend in assist state (same treasury separation HYBRID-REFILL relies on).
		//--- V0.7 BOOTSTRAP STIPEND: trickle funds+supply while the side owns 0 towns AND
		//--- time < WFBE_C_AICOM_BOOTSTRAP_MAXTIME.  Scales the per-minute amounts to the
		//--- actual tick spacing so the grant is tick-rate-independent.
		//--- supply is only granted when the dual-currency economy is active (system == 0).
		_stipendMaxTime = missionNamespace getVariable ["WFBE_C_AICOM_BOOTSTRAP_MAXTIME", 3600];
		_stipendTowns = 0;
		{ if ((_x getVariable "sideID") == _myID) then {_stipendTowns = _stipendTowns + 1} } forEach towns;
		_stipendActive = (_stipendTowns == 0) && (time < _stipendMaxTime);
		if (_stipendActive && !_prevStipendActive) then {
			["INFORMATION", Format ["AI_Commander.sqf: [%1] BOOTSTRAP STIPEND started (0 towns, time %2 s < max %3 s).", str _side, round time, _stipendMaxTime]] Call WFBE_CO_FNC_AICOMLog;
			diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|BOOTSTRAP_STIPEND|start");
		};
		if (!_stipendActive && _prevStipendActive) then {
			if (_stipendTowns > 0) then {
				["INFORMATION", Format ["AI_Commander.sqf: [%1] BOOTSTRAP STIPEND ended - first town captured.", str _side]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|BOOTSTRAP_STIPEND|end-first-town");
			} else {
				["INFORMATION", Format ["AI_Commander.sqf: [%1] BOOTSTRAP STIPEND ended - max time %2 s reached.", str _side, _stipendMaxTime]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|BOOTSTRAP_STIPEND|end-timeout");
			};
		};
		_prevStipendActive = _stipendActive;
		if (_stipendActive) then {
			//--- Grant once per 60 s (last-stipend timestamp guards the rate).
			if (time - _ltStipend >= 60) then {
				//--- Scale configured per-minute amounts by actual elapsed time since last grant
				//--- so a missed tick doesn't silently drop income (capped at 3x to avoid windfalls).
				_tickS = (time - _ltStipend) min 180;
				if (_ltStipend < -1e8) then {_tickS = 60}; //--- first grant: treat as one minute.
				_stipendFunds  = missionNamespace getVariable ["WFBE_C_AICOM_BOOTSTRAP_FUNDS",  100];
				_stipendSupply = missionNamespace getVariable ["WFBE_C_AICOM_BOOTSTRAP_SUPPLY",  50];
				_stipendFundsGrant  = round (_stipendFunds  * (_tickS / 60));
				_stipendSupplyGrant = round (_stipendSupply * (_tickS / 60));
				[_side, _stipendFundsGrant] Call ChangeAICommanderFunds;
				_dual = (missionNamespace getVariable ["WFBE_C_ECONOMY_CURRENCY_SYSTEM", 0]) == 0;
				//--- B74.2 (Ray 2026-06-24, directive #3): CASH-only AICOM boost. The bootstrap stipend's synthetic SUPPLY grant is
				//--- the only supply the AI is ever handed that it did not earn from towns; gate it behind BOOTSTRAP_SUPPLY_ENABLE
				//--- (default 0 = off) so AICOM keeps its funds trickle but no longer gets free supply. Town supply income is untouched.
				if (_dual && {(missionNamespace getVariable ["WFBE_C_AICOM_BOOTSTRAP_SUPPLY_ENABLE", 0]) > 0}) then {
					[_side, _stipendSupplyGrant, "AI commander bootstrap stipend.", false] Call ChangeSideSupply;
				};
				_ltStipend = time;
			};
		};

		//--- B67 HYBRID-REFILL (full-send hybrid commander, item #5): while a HUMAN commands this side
		//--- (assist state), the AI stays a quartermaster - it keeps FOUNDING and REFILLING its own teams
		//--- so the side is never starved of AI bodies, but it does NOT build the base or research upgrades
		//--- (the human owns those - AI_Com_Base / AI_Com_Upgrade stay OFF here). Gated separately from the
		//--- full-economy _canBuild block on its own WFBE_C_AI_COMMANDER_HYBRID_REFILL switch (>0). Funds come
		//--- from the SEPARATE AI-commander treasury (Teams/Produce charge GetAICommanderFunds), NOT the side
		//--- funds the human spends, so there is no contention with the human's purchases. Reuses the same
		//--- _ltTeams/_ltProd throttles as the full path (they are never both active in the same tick: this
		//--- block runs only when _humanCmd, the _canBuild block only when !_humanCmd via _noHumanSince).
		if (_humanCmd && {(missionNamespace getVariable ["WFBE_C_AI_COMMANDER_HYBRID_REFILL", 1]) > 0}) then {
			//--- Found AI combat teams up to the side target (self-gates on funds/HC/group-cap inside the worker).
			if (time - _ltTeams > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_INTERVAL", 90])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Teams; _ltTeams = time;
			};
			//--- Refill under-strength AI teams at the factories (self-gates per team + AI-cap inside the worker).
			if (time - _ltProd > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL")) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Produce; _ltProd = time;
			};
		};

		//--- Economy/build: full command AND only after the build-grace window (#3a, Ray 2026-06-15).
		//--- rule A still holds (no AI spend under a human); the AI also waits the build-grace with no
		//--- human commander (from start, re-armed when a human leaves) before it starts building.
		//--- Ray 2026-06-28: retire idle rear FOOT teams when mobile force is fielded - runs in EVERY command mode
		//--- (AI-command OR human-commander); the in-view + safety checks inside the pass protect immersion/safety.
		if (time - _ltDisband > (missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_INTERVAL", 300])) then {
			if (!isNil "WFBE_SE_FNC_AI_Com_DisbandLowTier") then {(_side) Call WFBE_SE_FNC_AI_Com_DisbandLowTier};
			_ltDisband = time;
		};
		//--- COMMAND CONSOLE squad-command mode (claude-gaming 2026-06-29): the MANEUVER BRAIN (Strategy + the v2
		//--- Snapshot/Allocate) is the ONE block moved out of the _canBuild economy gate onto _aiStrategy, so it runs
		//--- either when the AI holds full command (_canBuild) OR when a human commander delegated maneuver to it
		//--- (war-room "AI STRATEGY"). Everything else economy-related stays inside if (_canBuild) below.
		if (_aiStrategy) then {
			//--- V0.5: war strategy (spearheads, town relief, HQ strike, artillery).
			if (time - _ltStrat > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_STRATEGY_INTERVAL", 60])) then {
				//--- AICOM v2 (M0): refresh the server-authoritative world-model snapshot (wfbe_aicom2_snap)
				//--- immediately before the strategy worker. Behaviour-neutral until M3 reads it; emits AICOM2|SNAP.
				if (!isNil "WFBE_SE_FNC_AICOM2_Snapshot") then {(_side) Call WFBE_SE_FNC_AICOM2_Snapshot};
				(_side) Call WFBE_SE_FNC_AI_Com_Strategy; _ltStrat = time;
				//--- AICOM v2 (M1): the single offensive Allocator runs AFTER Strategy so its concentrated
				//--- fist choice wins (overwrites wfbe_aicom_targets) + assigns each team an alloc_target.
				//--- Inert unless WFBE_C_AICOM2_ALLOCATE_ENABLE>0 (checked inside) -> legacy path = instant rollback.
				if (!isNil "WFBE_SE_FNC_AICOM2_Allocate") then {(_side) Call WFBE_SE_FNC_AICOM2_Allocate};
				//--- NOTE (claude-gaming 2026-06-28): the AI-INTENT publish block was MOVED OUT of this gate
				//--- (it used to live here) to the _active-gated block just below the Executor, so the command-console
				//--- intent readout refreshes + reaches JIP/assist clients even when the AI is not in full-build mode.
			};
		};
		if (_canBuild) then {
			//--- B60 MHQ RELOCATION (Ray 2026-06-21): when the front advances far from the deployed HQ,
			//--- mobilize -> DRIVE the MHQ forward to a standoff behind the front town -> re-deploy. Self-gates
			//--- on WFBE_C_AICOM_MHQ_RELOCATE + single-flight + deployed-HQ + enemy-standoff; drive runs in its own Spawn.
			if (time - _ltMHQReloc > (missionNamespace getVariable ["WFBE_C_AICOM_MHQ_RELOCATE_INTERVAL", 180])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_MHQReloc; _ltMHQReloc = time;
			};
			//--- B74.2 (Ray 2026-06-24, directive #5): structure-sell / recycle pass. Interval-gated, single-side, nil-guarded.
			//--- Dark by default (WFBE_C_AICOM_BASE_SELL_ENABLE=0 -> the worker early-exits). Sells the lowest-cost redundant
			//--- non-HQ/non-CC structure, refunds part of its cost to side supply, frees the build slot (wfbe_structures_live).
			if ((missionNamespace getVariable ["WFBE_C_AICOM_BASE_SELL_ENABLE", 0]) > 0 && {time - _ltBaseSell >= (missionNamespace getVariable ["WFBE_C_AICOM_BASE_SELL_INTERVAL", 120])}) then {
				if (!isNil "WFBE_SE_FNC_AI_Com_BaseSell") then {(_side) Call WFBE_SE_FNC_AI_Com_BaseSell; _ltBaseSell = time};
			};
			//--- V0.2: build the base (HQ deploy -> doctrine build order -> defenses).
			if (time - _ltBase > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_BASE_INTERVAL", 60])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Base; _ltBase = time;
			};
			//--- AICOM FORWARD SPAWN-BEACON (Approach A, claude-gaming 2026-06-29): park a forward ambulance (a wired
			//--- mobile respawn) behind the spearhead town so AI + humans get a spawn line that follows the front.
			//--- INERT by default - both the flag AND the worker's own gate must pass (WFBE_C_AICOM_SPAWNBEACON_ENABLE=0
			//--- -> the worker is never called). nil-guarded like the other optional workers.
			if ((missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_ENABLE", 0]) > 0 && {time - _ltBeacon > (missionNamespace getVariable ["WFBE_C_AICOM_SPAWNBEACON_INTERVAL", 120])}) then {
				if (!isNil "WFBE_SE_FNC_AI_Com_Beacon") then {(_side) Call WFBE_SE_FNC_AI_Com_Beacon; _ltBeacon = time};
			};
			//--- V0.2: found AI combat teams up to the target (editor slots are not enough on AI-only sides).
			if (time - _ltTeams > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_INTERVAL", 90])) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Teams; _ltTeams = time;
			};
			if (time - _ltTypes > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TYPES_INTERVAL")) then {
				(_side) Call WFBE_SE_FNC_AI_Com_AssignTypes; _ltTypes = time;
			};
			if (time - _ltUp > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_UPGRADE_INTERVAL")) then {
				if !(_logik getVariable ["wfbe_upgrading", false]) then {(_side) Call WFBE_SE_FNC_AI_Com_Upgrade};
				_ltUp = time;
			};
			if (time - _ltProd > (missionNamespace getVariable "WFBE_C_AI_COMMANDER_PRODUCE_INTERVAL")) then {
				(_side) Call WFBE_SE_FNC_AI_Com_Produce; _ltProd = time;
			};

			//--- V0.6.7 P4: ADAPTIVE SPEND CONTROLLER - wealth conversion into reinforcement priority.
			//--- When the AI is funds-rich (> 2x extra-team threshold) and all team targets are
			//--- already met, signal Produce to use doubled batch cap so surplus converts to armies.
			_richThreshold = (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_FUNDS_PER_EXTRA_TEAM", 15000]) * 2;
			_funds = (_side) Call GetAICommanderFunds;
			_fundsRich = _funds > _richThreshold;
			_dynTarget = _logik getVariable ["wfbe_aicom_dyntarget", missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_TARGET", 4]];
			_fTeams = 0;
			{
				if (!isNull _x) then {
					if (([_x, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) || {[_x, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool}) then {
						_fTeams = _fTeams + 1;
					};
				};
			} forEach (_logik getVariable ["wfbe_teams", []]);
			_richFlag = _fundsRich && (_fTeams >= _dynTarget);
			//--- A2: == / != do not support Bool operands - use transition if/else instead.
			_prevRich = _logik getVariable ["wfbe_aicom_reinforce_rich", false];
			if (_richFlag && !_prevRich) then {
				_logik setVariable ["wfbe_aicom_reinforce_rich", true];
					//--- B752 (Ray 2026-06-25): THROTTLE the veteran-premium override. At the trivial 30k threshold vs the 8-18M
					//--- the commander hoards, this re-armed ~125x/round = 54% of foundings = the variety-killer (it spammed the
					//--- single highest-tier template). Only RE-ARM past a COOLDOWN so the premium is rare again (~10-15%); the
					//--- b750 effectiveness draw supplies the variety on every other founding.
					if (time - (_logik getVariable ["wfbe_aicom_veteran_t0", -1e10]) > (missionNamespace getVariable ["WFBE_C_AICOM_VETERAN_COOLDOWN", 900])) then {
						_logik setVariable ["wfbe_aicom_veteran_next", true];
						_logik setVariable ["wfbe_aicom_veteran_t0", time];
					};
				["INFORMATION", Format ["AI_Commander.sqf: [%1] wealth conversion active (funds %2 > threshold %3, teams %4/%5) - Veteran founding armed.", str _side, _funds, _richThreshold, _fTeams, _dynTarget]] Call WFBE_CO_FNC_AICOMLog;
				diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|WEALTH_CONVERSION|funds" + str _funds);
			};
			if (!_richFlag && _prevRich) then {
				_logik setVariable ["wfbe_aicom_reinforce_rich", false];
			};

			//--- Reactive CBR research: append [WFBE_UP_CBRADAR,1/2] to the AI upgrade program
			//--- once, the first tick after wfbe_aicom_arty_threat is set.  No-op if the constant
			//--- or the upgrades-levels array doesn't include CBR (vanilla / non-experital builds).
			if (!_cbrResearchAppended && {!isNil "WFBE_UP_CBRADAR"} && {_logik getVariable ["wfbe_aicom_arty_threat", false]}) then {
				_upgLvls = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_LEVELS", str _side], []];
				if (count _upgLvls > WFBE_UP_CBRADAR) then {
					_order = missionNamespace getVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], []];
					missionNamespace setVariable [Format ["WFBE_C_UPGRADES_%1_AI_ORDER", str _side], _order + [[WFBE_UP_CBRADAR,1],[WFBE_UP_CBRADAR,2]]];
					_cbrResearchAppended = true;
					["INFORMATION", Format ["AI_Commander.sqf: [%1] CBRadar research (lvl 1-2) appended to program - arty threat confirmed at %2 min.", str _side, round (time / 60)]] Call WFBE_CO_FNC_AICOMLog;
					diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|SCAFFOLD_RESEARCH_REACTIVE|CBRadar-1-2");
				};
			};
		};
	} else {
		if (_prevState != "stopped") then {
			_logik setVariable ["wfbe_aicom_running", false];
			["INFORMATION", Format ["AI_Commander.sqf: [%1] AI commander STOPPED (disabled / HQ down).", str _side]] Call WFBE_CO_FNC_AICOMLog;
			_prevState = "stopped"; _prevHuman = false;
		};
	};

	//--- V0.6 task 48: AICOMSTAT TICK every 5 minutes (ungated - always flows).
	if (time - _ltStat >= 300) then {
		_elMin = round (time / 60);
		_towns = 0; { if ((_x getVariable "sideID") == _myID) then {_towns = _towns + 1} } forEach towns;
		_supply = if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {(_side) Call WFBE_CO_FNC_GetSideSupply} else {0};
		_funds = (_side) Call GetAICommanderFunds;
		_fTeams = 0; _eTeams = 0;
		{
			if (!isNull _x) then {
				if (([_x, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) || {[_x, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool}) then {
					_fTeams = _fTeams + 1;
				} else {
					if ((count units _x) > 0 && {!isPlayer (leader _x)} && {alive (leader _x)}) then {_eTeams = _eTeams + 1};
				};
			};
		} forEach (_logik getVariable ["wfbe_teams", []]);
		_upgArr = _logik getVariable ["wfbe_upgrades", []];
		_upgCsv = "";
		for "_i" from 0 to (count _upgArr - 1) do {
			_upgCsv = _upgCsv + str (_upgArr select _i);
			if (_i < (count _upgArr - 1)) then {_upgCsv = _upgCsv + ":"};
		};
		// Append live unit count: read from missionNamespace cache written by server_groupsGC
		// each audit cycle (wfbe_units_west / _east / _guer). Falls back to 0 if not yet written.
		_tickUniKey = switch (_side) do {
			case west:       { "wfbe_units_west" };
			case east:       { "wfbe_units_east" };
			case resistance: { "wfbe_units_guer" };
			default          { "" };
		};
		_tickUni = 0;
		if (_tickUniKey != "") then {
			_tickUni = missionNamespace getVariable _tickUniKey;
			if (isNil "_tickUni") then { _tickUni = 0 };
		};
		diag_log ("AICOMSTAT|v1|TICK|" + (str _side) + "|" + str _elMin + "|" + str _towns + "|" + str _supply + "|" + str _funds + "|" + str _fTeams + "|" + str _eTeams + "|" + _upgCsv + "|units=" + str _tickUni);

		//--- ECONOMY breakdown (claude-gaming 2026-06-15): the TICK above is a point-in-time snapshot
		//--- of supply/funds, but Steff needs the funds-rich / supply-starved FLOW visible. Compute the
		//--- net change in each pool since the previous tick (income minus spend over the ~5-min window)
		//--- from a cheap cached prev value on the side logic. A POSITIVE net = accrued faster than spent;
		//--- a NEGATIVE net = spent down. Read alongside towns: 0-town sides show supply flat at 0 while
		//--- funds keep climbing = the famine state. Single diag_log on the existing 300s _ltStat cadence.
		private ["_prevFundsKey","_prevSupplyKey","_prevFunds","_prevSupply","_dFunds","_dSupply"];
		_prevFundsKey  = "wfbe_aicom_econ_prevfunds";
		_prevSupplyKey = "wfbe_aicom_econ_prevsupply";
		_prevFunds  = _logik getVariable [_prevFundsKey, -1];
		_prevSupply = _logik getVariable [_prevSupplyKey, -1];
		if (_prevFunds >= 0) then {
			_dFunds  = _funds - _prevFunds;
			_dSupply = _supply - _prevSupply;
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str _elMin + "|ECONOMY|funds=" + str _funds + "|supply=" + str _supply + "|netFunds=" + str _dFunds + "|netSupply=" + str _dSupply + "|towns=" + str _towns);
		};
		_logik setVariable [_prevFundsKey,  _funds];
		_logik setVariable [_prevSupplyKey, _supply];

		//--- ECONFLOW (claude-gaming 2026-06-15, B35): player-team economy split. Sums wfbe_funds across
		//--- player-led teams and reports the net change since last window, so the dashboard can show the
		//--- human-vs-AI wallet split. O(teams) (~4-8), 300s cadence. A2 trap: wfbe_funds plain-get + isNil
		//--- (getVariable [key,default] on a group is unreliable in 1.64). Silent in pure AI-vs-AI (no spam).
		private ["_ptFunds","_tf","_prevPtKey","_prevPtFunds","_dPtFunds"];
		_ptFunds = 0;
		{
			if (!isNull _x && {!isNull leader _x} && {isPlayer (leader _x)}) then {
				_tf = _x getVariable "wfbe_funds";
				if (isNil "_tf") then {_tf = 0};
				_ptFunds = _ptFunds + _tf;
			};
		} forEach (_logik getVariable ["wfbe_teams", []]);
		_prevPtKey = "wfbe_econ_prevptfunds";
		_prevPtFunds = _logik getVariable [_prevPtKey, -1];
		if (_prevPtFunds >= 0 && {_ptFunds > 0 || _prevPtFunds > 0}) then {
			_dPtFunds = _ptFunds - _prevPtFunds;
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str _elMin + "|ECONFLOW|playerFunds=" + str _ptFunds + "|netPlayerFunds=" + str _dPtFunds + "|aicomFunds=" + str _funds + "|supply=" + str _supply);
		};
		_logik setVariable [_prevPtKey, _ptFunds];

		_ltStat = time; //--- advance the throttle BEFORE CMDRSTAT so a CMDRSTAT failure could never spam/stall the AICOMSTAT tick

		//--- CMDRSTAT (claude-gaming 2026-06-13): commander-team SERVER-LOCAL vs HC-DELEGATED split +
		//--- 2-man-remnant fragmentation, for the group-reduction A/B ledger. SRVPERF 'groups' is
		//--- count allGroups - it INCLUDES HC-delegated proxies, so it overcounts server load. THIS
		//--- isolates srvTeams (founded teams whose LEADER is server-local) vs hcTeams (offloaded) and
		//--- flags remnants (alive but < 30% of template). Pure diag_log = gameplay-transparent.
		//--- Mirrors the proven group-getVariable[name,default] form on line 255; local() is checked on
		//--- the LEADER (an Object) never on the group (A2 OA 1.64 trap); team-type index bounds-guarded.
		private ["_srvTeams","_hcTeams","_foundedN","_aliveSum","_remnants","_cmdrTpl","_isHc","_isFounded","_aliveN","_tt","_tplSize","_upt","_ldr"];
		//--- SOAK DRAFT (claude-gaming 2026-06-20, propose-only, behaviour-neutral): the blended
		//--- unitsPerTeam reads BELOW the 8-12 floor (live 6.3/7.3) but RPT confirms infantry founds
		//--- at 10 (founding-pad fires) while 4-man vehicle/armour teams (correctly NOT padded) drag
		//--- the AVERAGE down. So the "below floor" alarm is partly a metric artifact. Split the live
		//--- average into infantry vs vehicle so the AM review can see the real infantry dribble
		//--- (attrition with no HC refill) separate from intended small vehicle crews. Pure additive
		//--- diag_log fields appended AFTER unitsPerTeam= (parser-compatible). A2-OA-safe: isKindOf /
		//--- getNumber / count only, no A3 commands, no sim/distance-gating, no antistack touch.
		private ["_infSum","_infN","_vehSum","_vehN","_isVehTeam","_uptInf","_uptVeh"];
		_srvTeams = 0; _hcTeams = 0; _foundedN = 0; _aliveSum = 0; _remnants = 0;
		_infSum = 0; _infN = 0; _vehSum = 0; _vehN = 0;
		_cmdrTpl = missionNamespace getVariable [Format ["WFBE_%1AITEAMTEMPLATES", str _side], []];
		{
			if (!isNull _x) then {
				_isHc = [_x, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool;
				_isFounded = [_x, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool;
				if (_isHc) then {_hcTeams = _hcTeams + 1};
				_ldr = leader _x;
				if (_isFounded && {!_isHc} && {!isNull _ldr} && {local _ldr}) then {_srvTeams = _srvTeams + 1};
				if (_isHc || _isFounded) then {
					_foundedN = _foundedN + 1;
					_aliveN = {alive _x} count (units _x);
					_aliveSum = _aliveSum + _aliveN;
					_tt = _x getVariable ["wfbe_teamtype", -1];
					//--- SOAK DRAFT: classify the team as VEHICLE (Tank or non-transport heli in its
					//--- template = the founding-pad's _isBigVeh rule, Teams.sqf:294-297) vs INFANTRY,
					//--- so the per-bucket average isolates the real infantry dribble. Unknown _tt =>
					//--- infantry bucket (the common case). First match wins (exitWith).
					_isVehTeam = false;
					if (_tt >= 0 && {_tt < (count _cmdrTpl)}) then {
						_tplSize = count (_cmdrTpl select _tt);
						if (_aliveN > 0 && {_tplSize > 0} && {_aliveN < (ceil (0.30 * _tplSize))}) then {_remnants = _remnants + 1};
						{
							if (_x isKindOf "Tank") exitWith {_isVehTeam = true};
							if ((_x isKindOf "Helicopter") && {(getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier")) == 0}) exitWith {_isVehTeam = true};
						} forEach (_cmdrTpl select _tt);
					};
					if (_isVehTeam) then {_vehSum = _vehSum + _aliveN; _vehN = _vehN + 1} else {_infSum = _infSum + _aliveN; _infN = _infN + 1};
				};
			};
		} forEach (_logik getVariable ["wfbe_teams", []]);
		_upt = 0;
		if (_foundedN > 0) then {_upt = (round ((_aliveSum / _foundedN) * 10)) / 10};
		//--- SOAK DRAFT: per-bucket averages (0 when a side has no team of that bucket this tick).
		_uptInf = 0; if (_infN > 0) then {_uptInf = (round ((_infSum / _infN) * 10)) / 10};
		_uptVeh = 0; if (_vehN > 0) then {_uptVeh = (round ((_vehSum / _vehN) * 10)) / 10};
		diag_log ("CMDRSTAT|v1|" + (str _side) + "|" + str _elMin + "|srvTeams=" + str _srvTeams + "|hcTeams=" + str _hcTeams + "|foundedTeams=" + str _foundedN + "|unitsPerTeam=" + str _upt + "|remnants=" + str _remnants + "|infPerTeam=" + str _uptInf + "|infTeams=" + str _infN + "|vehPerTeam=" + str _uptVeh + "|vehTeams=" + str _vehN);

		//--- COMBATSTAT (claude-gaming 2026-06-15): periodic per-side combat-attrition delta from the
		//--- FREE cumulative counters WF_Logic already maintains (Common_UpdateStatistics writes
		//--- <STR_SIDE>Casualties / <STR_SIDE>VehiclesLost on every death via RequestOnUnitKilled:162,
		//--- and <STR_SIDE>UnitsCreated on every spawn path). Only the per-EVENT WASPSTAT|KILL line
		//--- existed (gated, one row/kill) - there was NO periodic per-side attrition summary, so the
		//--- A/B ledger could not see exchange/bleed rate without replaying every KILL row. We read the
		//--- free counters with the SAME str-side key the writers use, cache a prev on the side logic
		//--- (exactly the ECONOMY prevFunds/prevSupply pattern), and emit cumulative + net-this-window.
		//--- Pure read of existing counters = ZERO new scan; one diag_log per side on the 300s _ltStat cadence.
		private ["_csCas","_csVeh","_csMade","_csKilled","_pCasK","_pVehK","_pMadeK","_pKilledK","_pCas","_pVeh","_pMade","_pKilled","_dCas","_dVeh","_dMade","_dKilled"];
		_csCas  = WF_Logic getVariable [Format ["%1Casualties",    str _side], 0];
		_csVeh  = WF_Logic getVariable [Format ["%1VehiclesLost",  str _side], 0];
		_csMade = WF_Logic getVariable [Format ["%1UnitsCreated",  str _side], 0];
		_csKilled = WF_Logic getVariable [Format ["%1KilledEnemy",  str _side], 0]; //--- B35: enemies downed by this side (exchange ratio = killed/cas)
		_pCasK = "wfbe_combat_prevcas"; _pVehK = "wfbe_combat_prevveh"; _pMadeK = "wfbe_combat_prevmade"; _pKilledK = "wfbe_combat_prevkilled";
		_pCas = _logik getVariable [_pCasK, -1]; _pVeh = _logik getVariable [_pVehK, -1]; _pMade = _logik getVariable [_pMadeK, -1]; _pKilled = _logik getVariable [_pKilledK, -1];
		if (_pCas >= 0) then {
			_dCas = _csCas - _pCas; _dVeh = _csVeh - _pVeh; _dMade = _csMade - _pMade; _dKilled = _csKilled - _pKilled;
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str _elMin + "|COMBATSTAT|cas=" + str _csCas + "|vehLost=" + str _csVeh + "|made=" + str _csMade + "|killed=" + str _csKilled + "|netCas=" + str _dCas + "|netVehLost=" + str _dVeh + "|netMade=" + str _dMade + "|netKilled=" + str _dKilled);
		};
		_logik setVariable [_pCasK, _csCas]; _logik setVariable [_pVehK, _csVeh]; _logik setVariable [_pMadeK, _csMade]; _logik setVariable [_pKilledK, _csKilled];
	};

	//--- SRVPERF (claude-gaming 2026-06-13): server-global perf line for the legacy-vs-next A/B
	//--- ledger. Global 300s throttle so it logs once regardless of which side's worker fires.
	if (time - (missionNamespace getVariable ["wfbe_srvperf_t", -999]) >= 300) then {
		missionNamespace setVariable ["wfbe_srvperf_t", time];
		private ["_pActive"];
		_pActive = 0;
		{ if (_x getVariable ["wfbe_active", false]) then {_pActive = _pActive + 1} } forEach towns;
		diag_log ("SRVPERF|v1|" + str (round (time / 60)) + "|fps=" + str (round (diag_fps)) + "|units=" + str (count allUnits) + "|groups=" + str (count allGroups) + "|veh=" + str (count vehicles) + "|dead=" + str (count allDead) + "|activeTowns=" + str _pActive);

		//--- WASPSCALE (claude-gaming 2026-07-01): perf/scope tracker - one allUnits pass per 5-min window (reuses this
		//--- SRVPERF throttle, zero per-frame cost) buckets live AI by side + counts humans, groups, fps, tier and map.
		private ["_aiW","_aiE","_aiG","_humN","_tier"]; _aiW=0;_aiE=0;_aiG=0;_humN=0; { if (isPlayer _x) then {_humN=_humN+1} else { switch (side _x) do { case west:{_aiW=_aiW+1}; case east:{_aiE=_aiE+1}; case resistance:{_aiG=_aiG+1} } } } forEach allUnits; _tier = missionNamespace getVariable ["WFBE_PopTier",0]; diag_log ("WASPSCALE|v1|" + str (round (time/60)) + "|tier=" + str _tier + "|players=" + str _humN + "|AI_W=" + str _aiW + "|AI_E=" + str _aiE + "|AI_GUER=" + str _aiG + "|AI_TOT=" + str (_aiW+_aiE+_aiG) + "|groups=" + str (count allGroups) + "|fps=" + str (round diag_fps) + "|map=" + worldName);

		//--- GRPBUDGET (claude-gaming 2026-06-13): per-side group count vs Arma 2 OA's 144/side HARD CAP - the
		//--- "group budget" alarm. Near the cap the AI commander cannot found teams (economy stalls on unspent
		//--- funds) and spawns can SILENTLY FAIL. Server-global, shares the SRVPERF 300s throttle. Keep the
		//--- normal GRPBUDGET line every window, but latch the loud WARN so a server that sits near cap for
		//--- hours does not print the same alarm forever; RECOVER clears the latch when counts drop again.
		private ["_gbW","_gbE","_gbG","_gbMax","_gbWarn"];
		_gbW = missionNamespace getVariable ["wfbe_grpcnt_west", -1]; if (_gbW < 0) then { _gbW = {side _x == west} count allGroups; }; //--- B7: groupsGC cache + fallback
		_gbE = missionNamespace getVariable ["wfbe_grpcnt_east", -1]; if (_gbE < 0) then { _gbE = {side _x == east} count allGroups; };
		_gbG = missionNamespace getVariable ["wfbe_grpcnt_guer", -1]; if (_gbG < 0) then { _gbG = {side _x == resistance} count allGroups; };
		_gbMax = _gbW max _gbE max _gbG;
		diag_log ("GRPBUDGET|v1|" + str (round (time / 60)) + "|west=" + str _gbW + "|east=" + str _gbE + "|guer=" + str _gbG + "|cap=144");
		_gbWarn = missionNamespace getVariable ["WFBE_C_GROUP_BUDGET_WARN", 125];
		if (_gbMax >= _gbWarn) then {
			if ((missionNamespace getVariable ["wfbe_grpbudget_warn_active", 0]) < 1) then {
				missionNamespace setVariable ["wfbe_grpbudget_warn_active", 1];
				diag_log ("GRPBUDGET|v1|WARN|" + str (round (time / 60)) + "|near-cap max=" + str _gbMax + "/144 warn=" + str _gbWarn + " (west=" + str _gbW + " east=" + str _gbE + " guer=" + str _gbG + ")");
			};
		} else {
			if ((missionNamespace getVariable ["wfbe_grpbudget_warn_active", 0]) > 0) then {
				missionNamespace setVariable ["wfbe_grpbudget_warn_active", 0];
				diag_log ("GRPBUDGET|v1|RECOVER|" + str (round (time / 60)) + "|max=" + str _gbMax + "/144 warn=" + str _gbWarn + " (west=" + str _gbW + " east=" + str _gbE + " guer=" + str _gbG + ")");
			};
		};

		//--- HCDELEG (claude-gaming 2026-06-15): SERVER-AUTHORITATIVE per-HC owned-unit load + imbalance
		//--- ratio (task #34). CMDRSTAT only has the AGGREGATE hcTeams count; HCSTAT|v1 is HC-SELF-REPORTED
		//--- (if an HC freezes, its report silently stops and you cannot tell an overloaded HC from a dead
		//--- one). The SERVER already knows the truth: routing is by `owner (leader hcGroup)`, so we bucket
		//--- allUnits by owner ONCE - the SAME single-pass tally Server_PickLeastLoadedHC:45-56 runs on every
		//--- delegation - and emit per-HC counts + max/min imbalance. Independent of HC health. Fires once
		//--- per 300s on the server-global SRVPERF/GRPBUDGET wfbe_srvperf_t throttle (one tally per window,
		//--- not per side, not per delegation): O(units) - the cheapest scan in the picker, fired 300x less often.
		private ["_hcReg","_hcLive","_hcOwners","_hcCounts","_ho","_hidx","_hMax","_hMin","_hCsv","_hRatio","_hc"];
		_hcReg = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
		_hcLive = [];
		{ if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_hcLive = _hcLive + [_x]} } forEach _hcReg;
		if (count _hcLive > 0) then {
			_hcOwners = []; _hcCounts = [];
			{ _hcOwners set [_forEachIndex, owner (leader _x)]; _hcCounts set [_forEachIndex, 0] } forEach _hcLive;
			{ _ho = owner _x; _hidx = _hcOwners find _ho; if (_hidx >= 0) then {_hcCounts set [_hidx, (_hcCounts select _hidx) + 1]} } forEach allUnits;
			_hMax = 0; _hMin = 1e9; _hCsv = "";
			{
				_hc = _hcCounts select _forEachIndex;
				if (_hc > _hMax) then {_hMax = _hc};
				if (_hc < _hMin) then {_hMin = _hc};
				_hCsv = _hCsv + str (_hcOwners select _forEachIndex) + ":" + str _hc;
				if (_forEachIndex < ((count _hcLive) - 1)) then {_hCsv = _hCsv + ","};
			} forEach _hcLive;
			_hRatio = if (_hMin > 0) then {(round ((_hMax / _hMin) * 10)) / 10} else {-1};
			diag_log ("HCDELEG|v1|" + str (round (time / 60)) + "|liveHC=" + str (count _hcLive) + "|perHC=" + _hCsv + "|max=" + str _hMax + "|min=" + str _hMin + "|imbalance=" + str _hRatio);
		};
	};

	//--- WAR-BRIEF: recurring [AICOM BRIEF] every ~300s (owned towns, funds, teams, doctrine, posture).
	_briefTs = _logik getVariable ["wfbe_aicom_lastbrief", 0];
	if (time - _briefTs > 300) then {
		_briefTowns = 0;
		_myID = (_side) Call WFBE_CO_FNC_GetSideID;
		{ if ((_x getVariable ["sideID", -1]) == _myID) then {_briefTowns = _briefTowns + 1} } forEach towns;
		_briefFunds  = (_side) Call GetAICommanderFunds;
		_briefTeams  = count (_logik getVariable ["wfbe_teams", []]);
		_briefDoctrine = _logik getVariable ["wfbe_aicom_doctrine", "?"];
		_briefStrat  = _logik getVariable ["wfbe_aicom_strat_mode", "?"];
		["INFORMATION", Format ["AI_Commander.sqf: [AICOM BRIEF] side=%1 towns=%2 funds=%3 teams=%4 doctrine=%5 posture=%6", str _side, _briefTowns, _briefFunds, _briefTeams, _briefDoctrine, _briefStrat]] Call WFBE_CO_FNC_AICOMLog;
		_logik setVariable ["wfbe_aicom_lastbrief", time];
	};

	sleep (missionNamespace getVariable "WFBE_C_AI_COMMANDER_TICK");
};

if (!gameOver && {(missionNamespace getVariable [_ownerKey, _ownerSeq]) != _ownerSeq}) exitWith {
	diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|SUPERVISOR_SUPERSEDED|old=" + str _ownerSeq + "|new=" + str (missionNamespace getVariable [_ownerKey, -1]));
	["WARNING", Format ["AI_Commander.sqf: [%1] supervisor owner generation %2 superseded by %3 - exiting old instance.", str _side, _ownerSeq, missionNamespace getVariable [_ownerKey, -1]]] Call WFBE_CO_FNC_AICOMLog;
};

//--- V0.5: round verdict - one line per side for the stats pipeline / meta-learning.
_held = 0;
{ if ((_x getVariable "sideID") == _myID) then {_held = _held + 1} } forEach towns;
_winner = sideUnknown;
if (!isNil "WF_Logic") then {_winner = WF_Logic getVariable ["WF_Winner", sideUnknown]};
["INFORMATION", Format ["AI_Commander.sqf: [%1] ROUND OVER after %2 min: winner [%3], my doctrine %4, towns held %5, funds left %6.", str _side, round (time / 60), _winner, _logik getVariable ["wfbe_aicom_doctrine", "?"], _held, (_side) Call GetAICommanderFunds]] Call WFBE_CO_FNC_AICOMLog;
//--- V0.6 task 48: AICOMSTAT END - always emitted ungated regardless of LOG setting.
diag_log ("AICOMSTAT|v1|END|" + (str _side) + "|" + str (round (time / 60)) + "|" + (str _winner) + "|" + (_logik getVariable ["wfbe_aicom_doctrine", "?"]) + "|" + str _held + "|" + str ((_side) Call GetAICommanderFunds));

//--- ROUNDSTAT (claude-gaming 2026-06-13): one server-global round-summary line for the A/B
//--- ledger, tagged with the active arm. Guarded (wfbe_roundstat_done) so only the first side's
//--- worker emits it. avg-fps + peak-units are derived externally from the SRVPERF time series.
if (!(missionNamespace getVariable ["wfbe_roundstat_done", false])) then {
	missionNamespace setVariable ["wfbe_roundstat_done", true];
	private ["_rArm", "_rGating", "_rWest", "_rEast"];
	_rArm = missionNamespace getVariable ["WFBE_C_AB_ARM", "?"];
	_rGating = missionNamespace getVariable ["WFBE_C_SIM_GATING", 0];
	_rWest = 0; _rEast = 0;
	{ if ((_x getVariable "sideID") == WFBE_C_WEST_ID) then {_rWest = _rWest + 1}; if ((_x getVariable "sideID") == WFBE_C_EAST_ID) then {_rEast = _rEast + 1} } forEach towns;
	diag_log ("ROUNDSTAT|v1|" + str (round (time / 60)) + "|arm=" + _rArm + "|simGating=" + str _rGating + "|winner=" + (str _winner) + "|townsW=" + str _rWest + "|townsE=" + str _rEast + "|units=" + str (count allUnits) + "|dead=" + str (count allDead));
};

