/*
	AI Commander - reinforce under-strength AI teams via AIBuyUnit, within a per-side AI cap.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	For each AI team with no build in flight and below its template size, build the first
	template unit it is short on, at an alive factory of the right kind, if unlocked and
	affordable.
	V0.6.7 ADAPTIVE BATCH: per cycle, per eligible team, order up to (deficit) units capped
	by WFBE_C_AICOM_PRODUCE_BATCH (default 3) and available funds; each unit still charged
	individually.  When the wfbe_aicom_reinforce_rich flag is set by the supervisor (P4
	wealth-conversion), the effective batch cap doubles.
*/

private ["_side","_sideText","_logik","_cap","_capTiers","_capTier","_capTierLast","_sideAI","_teams","_templates","_upgrades","_buildings","_structTypes","_facDefs","_team","_type","_template","_want","_cur","_toBuild","_d","_have","_fac","_unitList","_typeName","_ud","_price","_kind","_factories","_isVeh","_id","_q","_canProduce","_funds","_hqP","_batchCap","_batchOrdered","_richFlag","_myID","_ownTowns","_nearFwd","_fwdR","_facObj","_ldr","_effBatch","_ordered","_aliveNow","_retreatSeq","_retreatOrder","_homeR","_refitAtBase","_refitNow","_refitWas","_refitStart","_refitDur","_curDist","_rTries","_rLast","_rBudget","_rProgress","_rMinClose","_rIssues","_rMaxIssues","_rMaxDist","_slungVeh","_unitVeh","_mergeOn","_mergeRange","_mergeTeam","_mergeBest","_cand","_candLdr","_candAlive","_d2","_mergedInto","_sizeMax"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- V0.6.7: batch cap - tunable, doubled when supervisor sets the wealth-rich flag.
_batchCap = missionNamespace getVariable ["WFBE_C_AICOM_PRODUCE_BATCH", 3];
_richFlag = _logik getVariable ["wfbe_aicom_reinforce_rich", false];
if (_richFlag) then {_batchCap = _batchCap * 2};

//--- Safety cap: do not produce above the per-side AI ceiling.
_capTiers = missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", [140,130,100,80]];
if ((count _capTiers) < 1) then {_capTiers = [missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", 140]]};
_capTier = (missionNamespace getVariable ["WFBE_PopTier", 0]) max 0;
_capTierLast = (count _capTiers) - 1;
if (_capTier > _capTierLast) then {_capTier = _capTierLast};
_cap = _capTiers select _capTier;   //--- B74.2: tiered per-side AI ceiling (was flat WFBE_C_AI_COMMANDER_TOTAL_AI_MAX).
_sideAI = {(side _x == _side) && !(isPlayer _x)} count allUnits;
if (_sideAI >= _cap) exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
_templates = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
if (isNil "_templates") exitWith {};

_upgrades   = (_side) Call WFBE_CO_FNC_GetSideUpgrades;
_buildings  = (_side) Call WFBE_CO_FNC_GetSideStructures;
_structTypes = missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText];
if (isNil "_structTypes") exitWith {};

//--- [STRUCTURES type-name, per-factory UNITS-list suffix, upgrade-track index].
_facDefs = [["Barracks","BARRACKSUNITS",WFBE_UP_BARRACKS], ["Light","LIGHTUNITS",WFBE_UP_LIGHT], ["Heavy","HEAVYUNITS",WFBE_UP_HEAVY]];
//--- AIRCRAFT GATE (defence-in-depth, mirrors AI_Commander_Base): only let the producer
//--- make aircraft once the side is established (>= WFBE_C_AICOM_AIR_MIN_TOWNS towns), so a
//--- captured/pre-placed air factory can't pump aircraft the AI flies poorly with early on.
_myID = (_side) Call WFBE_CO_FNC_GetSideID;
_ownTowns = 0;
{ if ((_x getVariable "sideID") == _myID) then {_ownTowns = _ownTowns + 1} } forEach towns;
if (_ownTowns >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 3])) then {
	_facDefs = _facDefs + [["Aircraft","AIRCRAFTUNITS",WFBE_UP_AIR]];
};
//--- Build83 FLAT AIR CAP at the PRODUCE/refill gate (Ray cmdcon34, 2026-07-01): mirror the founding-gate flat cap
//--- (AI_Commander_Teams.sqf). If the side already has >= WFBE_C_AICOM_AIR_MAX_TOTAL (default 3) ALIVE air units (planes +
//--- attack helis + transport helis TOGETHER), REMOVE "Aircraft" from _facDefs so the producer SKIPS every air refill this
//--- cycle - no factory then handles an air class, so the deficit loop below falls through to a ground/foot class (the same
//--- degrade the founding strip achieves). Self-limiting: the count drops when an airframe dies and air refill resumes. COUNT
//--- matches the founding gate: side-resolved alive isKindOf "Air" (crewed -> crew side; crewless -> wfbe_side tag), which is
//--- AICOM air since town garrisons are ground-only in this mission. A2-OA-safe: isKindOf "Air" + crew/side resolve over vehicles.
private ["_airMaxTotalP","_airAliveP","_facDefsNoAir"];
_airMaxTotalP = missionNamespace getVariable ["WFBE_C_AICOM_AIR_MAX_TOTAL", 3];
if (_airMaxTotalP > 0) then {
	_airAliveP = 0;
	{
		if (alive _x && {_x isKindOf "Air"}) then {
			private ["_airSideOKP"];
			_airSideOKP = false;
			if ((count crew _x) > 0) then {
				if (side ((crew _x) select 0) == _side) then {_airSideOKP = true};
			} else {
				if ((_x getVariable ["wfbe_side", sideUnknown]) == _side) then {_airSideOKP = true};
			};
			if (_airSideOKP) then {_airAliveP = _airAliveP + 1};
		};
	} forEach vehicles;
	if (_airAliveP >= _airMaxTotalP) then {
		_facDefsNoAir = [];
		{ if ((_x select 0) != "Aircraft") then {_facDefsNoAir set [count _facDefsNoAir, _x]} } forEach _facDefs;
		_facDefs = _facDefsNoAir;
	};
};

{
	_team = _x;
	//--- V0.6.5: skip NULL entries (wiped HC teams; getVariable on a null group returns
	//--- nil even with a default -> the lazy-brace check below threw and killed Produce,
	//--- stopping ALL factory purchases for editor teams).
	if (!isNull _team) then {
	_type = _team getVariable "wfbe_teamtype";
	if (isNil "_type") then {_type = -1};

	//--- =========================================================================================
	//--- (cmdcon41-w2) HC-TEAM MAINTENANCE PASS: terminal RECYCLE + friendly-town TOP-UP DISPATCH.
	//--- These act on the HC-resident commander teams (the live army), which the server-local
	//--- _canProduce path below deliberately SKIPS. They only SET flags / broadcast requests that the
	//--- owning HC driver consumes in its own lane (never delete/move a unit from here). A2-OA-safe:
	//--- GROUP vars via plain get + isNil (the [name,default] form is unreliable on groups), no A3
	//--- primitives, exact-case behaviour strings, playableUnits/isPlayer/distance for proximity.
	//--- =========================================================================================
	private ["_wm_ldr","_wm_alive"];
	_wm_ldr = leader _team;
	if (!isNull _wm_ldr && {!isPlayer _wm_ldr}) then {
		_wm_alive = {alive _x} count (units _team);

		//--- (2) RECYCLE CONSUMER: the driver/supervisor marks a zombie/failed-journey team wfbe_aicom_recycle.
		//--- Retire it at a player-SAFE moment by routing it through the existing disband idiom WITHOUT the _cmd
		//--- bypass, so the HC driver's own player-proximity + not-in-COMBAT veto still applies (never a
		//--- player-visible vanish; founding replaces the slot naturally). Guards here are belt-and-braces so we
		//--- never even REQUEST a disband while the team is fighting or a player is close.
		private ["_wm_recycle","_wm_disbanding","_wm_playerNear"];
		_wm_recycle = _team getVariable "wfbe_aicom_recycle";
		if (!isNil "_wm_recycle" && {_wm_recycle}) then {
			_wm_disbanding = _team getVariable "wfbe_aicom_disband"; //--- already flagged? don't re-request
			_wm_disbanding = (!isNil "_wm_disbanding" && {_wm_disbanding});
			_wm_playerNear = false;
			{ if (isPlayer _x && {alive _x} && {(_x distance _wm_ldr) < 500}) exitWith {_wm_playerNear = true} } forEach playableUnits;
			if ((behaviour _wm_ldr != "COMBAT") && {!_wm_playerNear} && {!_wm_disbanding}) then {
				_team setVariable ["wfbe_aicom_disband", true, true]; //--- NO _cmd bypass -> driver still vetoes on proximity/combat
				_team setVariable ["wfbe_aicom_recycle", false, true]; //--- clear the request (one-shot)
				["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] TEAM_RECYCLE requested (alive=%3, no player within 500m, not in combat) - disband flagged (proximity-vetoed, no _cmd bypass).", _sideText, _team, _wm_alive]] Call WFBE_CO_FNC_AICOMLog;
			};
		};

		//--- (3) TOWN-CENTER TOP-UP DISPATCHER (Ray: reinforce at friendly towns): an HC team that is RALLYING or
		//--- PARKED (leader within 400m of its own HQ or an OWN-side town centre) and understrength (alive < 6)
		//--- gets an infantry top-up. We CHARGE the side up front (per-missing-unit flat cost) and broadcast a
		//--- wfbe_aicom_topup_req [count,pos,classes,issuedTime] the owning HC driver consumes to spawn the bodies into the team. Rate-limited to
		//--- one top-up per team per COOLDOWN via a group stamp. Never fires in COMBAT (rallying/parked implies not) or while pending disband (PR #542).
		private ["_wm_rally","_wm_parked","_wm_disbanding","_wm_hqP","_wm_myID","_wm_rallyPos","_wm_missing","_wm_now","_wm_lastTU","_wm_cd","_wm_unitCost","_wm_charge","_wm_curFunds","_wm_infCls","_wm_barr","_wm_cmdTeam","_wm_humanSeated","_wm_mult","_wm_cmdUID","_wm_humanTag"];
		if (_wm_alive < 6 && {behaviour _wm_ldr != "COMBAT"}) then {
			_wm_rally = _team getVariable "wfbe_aicom_rallying";
			_wm_rally = (!isNil "_wm_rally" && {_wm_rally});
			//--- PARKED test: leader hugging own HQ (<400m) or any OWN-side town centre (<400m).
			_wm_parked = false;
			_wm_hqP = (_side) Call WFBE_CO_FNC_GetSideHQ;
			if (!isNull _wm_hqP && {(_wm_ldr distance _wm_hqP) < 400}) then {_wm_parked = true};
			if (!_wm_parked) then {
				_wm_myID = (_side) Call WFBE_CO_FNC_GetSideID;
				{ if (((_x getVariable ["sideID", -1]) == _wm_myID) && {(_wm_ldr distance _x) < 400}) exitWith {_wm_parked = true} } forEach towns;
			};
			_wm_disbanding = _team getVariable "wfbe_aicom_disband";
			_wm_disbanding = (!isNil "_wm_disbanding" && {_wm_disbanding});
			if (!_wm_disbanding && {_wm_rally || {_wm_parked}}) then {
				//--- COOLDOWN gate (one top-up per team per WFBE_C_AICOM_TOPUP_COOLDOWN seconds).
				_wm_now   = time;
				_wm_lastTU = _team getVariable "wfbe_aicom_topup_stamp"; if (isNil "_wm_lastTU") then {_wm_lastTU = -1e9};
				_wm_cd    = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_COOLDOWN", 240];
				if ((_wm_now - _wm_lastTU) >= _wm_cd) then {
					_wm_missing = (6 - _wm_alive) min 4; //--- top up toward 6, at most 4 bodies per request
					if (_wm_missing > 0) then {
						//--- Resolve the side's BASIC infantry classnames the founding templates use: the barracks unit
						//--- roster (WFBE_%1BARRACKSUNITS), whose [0] is the basic rifleman (same source Produce's
						//--- BARRACKSUNITS factory list draws from). Take up to the first 3 Man-class entries so the driver
						//--- has a small basic-infantry pool to spawn from. Falls back to the whole roster head if odd.
						_wm_barr = missionNamespace getVariable [Format ["WFBE_%1BARRACKSUNITS", _sideText], []];
						_wm_infCls = [];
						{
							if ((count _wm_infCls) < 3 && {_x isKindOf "Man"}) then {_wm_infCls = _wm_infCls + [_x]};
						} forEach _wm_barr;
						//--- Lane-336: GUER can arrive through an alias roster; retry that before giving up.
						if ((count _wm_infCls) == 0 && {_side == resistance}) then {
							_wm_barr = missionNamespace getVariable ["WFBE_GUERBARRACKSUNITS", []];
							{
								if ((count _wm_infCls) < 3 && {_x isKindOf "Man"}) then {_wm_infCls = _wm_infCls + [_x]};
							} forEach _wm_barr;
						};
						//--- guard: no roster / all-non-man (shouldn't happen) -> skip rather than dispatch an empty pool.
						if (count _wm_infCls > 0) then {
							//--- CHARGE the side up front: flat per-unit cost * missing (mirrors founding's charge-then-build).
							_wm_unitCost = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_UNIT_COST", 300];
							//--- cmdcon42 TOPUP OPTION B (Ray 2026-07-02): keep the quartermaster auto-refit running under a
							//--- HUMAN commander, but HEAVILY DISCOUNT it (the player commander gets no kill income from his
							//--- squads, as intended) and make each charge VISIBLE to that commander. Human-seat detection is
							//--- the same RAW idiom as AI_Commander.sqf _humanSeated (isPlayer leader of the commander team,
							//--- deliberately NOT the AICOM-LOCK-overridden state: the discount tracks the REAL seat).
							//--- The AI commander keeps paying full price; payer (AICOM treasury) and cooldown are unchanged.
							_wm_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
							_wm_humanSeated = false;
							if (!isNull _wm_cmdTeam) then { if (isPlayer (leader _wm_cmdTeam)) then {_wm_humanSeated = true} };
							_wm_mult = 1;
							if (_wm_humanSeated) then {_wm_mult = missionNamespace getVariable ["WFBE_C_AICOM_TOPUP_HUMAN_MULT", 0.33]};
							_wm_charge   = round (_wm_unitCost * _wm_missing * _wm_mult);
							_wm_curFunds = (_side) Call GetAICommanderFunds;
							if (_wm_curFunds >= _wm_charge) then {
								[_side, -_wm_charge] Call ChangeAICommanderFunds;
								_wm_rallyPos = getPosATL _wm_ldr; //--- plain array = the rally pos the driver spawns at
								_team setVariable ["wfbe_aicom_topup_req", [_wm_missing, _wm_rallyPos, _wm_infCls, _wm_now], true];
								_team setVariable ["wfbe_aicom_topup_stamp", _wm_now, false]; //--- rate-limit stamp (local group var)
								//--- VISIBILITY: UID-targeted command-chat line to the seated human commander ONLY (Client_HandlePVF
								//--- STRING destination = exact player UID; LocalizeMessage "QuartermasterRefit" is a passthrough case).
								//--- Spam-bounded by the per-team 240s cooldown above - one line per real refit charge, human era only.
								if (_wm_humanSeated) then {
									_wm_cmdUID = getPlayerUID (leader _wm_cmdTeam);
									if (_wm_cmdUID != "") then {
										[_wm_cmdUID, "LocalizeMessage", ["QuartermasterRefit", Format ["Quartermaster: -%1 refit %2 (%3 men)", _wm_charge, str _team, _wm_missing]]] Call WFBE_CO_FNC_SendToClients;
									};
								};
								_wm_humanTag = ""; if (_wm_humanSeated) then {_wm_humanTag = Format ["|human=1|mult=%1", _wm_mult]};
								["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] TOPUP_REQ (missing=%3, alive=%4, rally=%5, cost=%6, classes=%7)%8 - charged, broadcast to HC driver.", _sideText, _team, _wm_missing, _wm_alive, _wm_rally, _wm_charge, _wm_infCls, _wm_humanTag]] Call WFBE_CO_FNC_AICOMLog;
							};
						};
					};
				};
			};
		};
	};

	_canProduce = false;
	//--- V0.3: HC-resident commander teams are produced whole on the HC - never here. Produce
	//--- (and the B61 REFILL-AT-BASE below) only ever serves the SERVER-LOCAL re-adopted teams
	//--- (base-GC teams marked wfbe_aicom_founded) whose units are local to the SERVER, so AIBuyUnit
	//--- can spawn refills at a factory for them. B66: the gate is the same (exclude HC teams) but the
	//--- bool read is routed through WFBE_CO_FNC_GroupGetBool (A2-OA: the 2-arg [name,default] form is
	//--- UNRELIABLE for UNSET vars on a GROUP), and the intent is relabelled: this branch is the
	//--- server-local-team path, NOT the HC path.
	if (!isPlayer (leader _team) && {!([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool)}) then { //--- B66
		if (_type >= 0) then {
			if (_type < count _templates) then {
				_q = _team getVariable "wfbe_queue";
				if (isNil "_q") then {_q = []};
				if ((count _q) < 1) then {_canProduce = true};
			};
		};
	};
	//--- V0.5: reinforcement sanity - AIBuyUnit spawns refills at the factory, so only
	//--- refill teams near the base; fully wiped teams reform at base anyway.
	if (_canProduce && {({alive _x} count (units _team)) > 0}) then {
		_hqP = (_side) Call WFBE_CO_FNC_GetSideHQ;
		if (!isNull _hqP) then {
			_ldr = leader _team;
			_aliveNow = {alive _x} count (units _team);
			_refitNow = _team getVariable "wfbe_aicom_refit";
			if (isNil "_refitNow") then {_refitNow = false};
			_refitWas = _team getVariable "wfbe_aicom_refit_prev";
			if (isNil "_refitWas") then {_refitWas = _refitNow};
			_team setVariable ["wfbe_aicom_refit_prev", _refitWas];
			//--- V0.6 RETREAT-AND-REFORM: badly depleted team far from HQ - order it back
			//--- before trying to refill (refills spawn at the factory, not in the field).
			//--- B61 (Ray 2026-06-21) REFILL-AT-BASE: flag a depleted team for a base refit on retreat so
			//--- Produce tops it back to the founding floor once it arrives home, then re-dispatches it,
			//--- instead of parking it forever as a low-strength tracked remnant (the bulk of the base pile).
			_homeR = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_HOME_RANGE", 800];
			if (_aliveNow < 2 && {(_ldr distance _hqP) > _homeR}) then {
				//--- B67 RETREAT-CULL (retreat-thrash fix): a lone survivor far from HQ re-fires this
				//--- retreat-and-reform order every produce cycle and never resolves (live: team O 1-2-F
				//--- alive=1 dist=5566m looping forever - it can't path home and Produce can't refill it in
				//--- the field). Add a per-team failure budget: count re-issues + check distance progress.
				//--- After WFBE_C_AICOM_RETREAT_MAX_TRIES re-issues with NO meaningful close toward HQ, cull
				//--- the survivor (deleteVehicle + deleteGroup) instead of re-ordering - the wfbe_teams entry
				//--- becomes a null group, which every consumer already skips (same lifecycle as a wiped HC
				//--- team), so net unit/group count DROPS (FPS-safe). A2-OA-safe: 1-arg getVariable + isNil
				//--- guard for the new group vars (the 2-arg [name,default] form is unreliable for UNSET
				//--- vars on a GROUP), explicit forEach for the cull, no A3-only array primitives.
				_curDist = _ldr distance _hqP;
				_rTries = _team getVariable "wfbe_aicom_retreat_tries"; if (isNil "_rTries") then {_rTries = 0};
				_rLast  = _team getVariable "wfbe_aicom_retreat_lastdist"; if (isNil "_rLast") then {_rLast = -1};
				_rBudget = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_MAX_TRIES", 4];
				_rMinClose = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_MIN_CLOSE", 50];
				//--- B68 (Ray 2026-06-21): the B67 progress-gated budget never culls a lone survivor that slowly
				//--- crawls home from far away (it closes >MIN_CLOSE/cycle, so tries keep resetting = retreats
				//--- forever, milling at base, never assaulting). Add an ABSOLUTE re-issue count (NOT reset by
				//--- progress) + a hard distance cap so far-stranded remnants get recycled instead of looping.
				_rIssues = _team getVariable "wfbe_aicom_retreat_issues"; if (isNil "_rIssues") then {_rIssues = 0};
				_rMaxIssues = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_MAX_ISSUES", 8];
				_rMaxDist = missionNamespace getVariable ["WFBE_C_AICOM_RETREAT_MAX_DIST", 6000];
				//--- Progress = closed at least _rMinClose metres toward HQ since the last re-issue. A first
				//--- attempt (_rLast < 0) counts as progress so we never cull on the very first order.
				_rProgress = (_rLast < 0) || {(_rLast - _curDist) >= _rMinClose};
				if (_rProgress) then {
					//--- Making headway home (or first order): reset the failure counter, keep ordering.
					_rTries = 0;
				} else {
					_rTries = _rTries + 1;
				};
				if (_rTries >= _rBudget || {_rIssues >= _rMaxIssues} || {_curDist > _rMaxDist}) then {
					//--- cmdcon36 lane342: if an AICOM air leg is currently slinging this team's vehicle,
					//--- do NOT merge/cull the group out from under the attached hull. AirLeg clears the marker
					//--- on detach/drop/fail, so the next Produce pass can re-evaluate normally.
					_slungVeh = objNull;
					{
						if (isNull _slungVeh && {alive _x}) then {
							_unitVeh = vehicle _x;
							if (!isNull _unitVeh && {_unitVeh != _x} && {alive _unitVeh} && {(_unitVeh getVariable ["wfbe_aicom_slung", false])}) then {
								_slungVeh = _unitVeh;
							};
						};
					} forEach (units _team);
					if (!isNull _slungVeh) then {
						["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] retreat-thrash cull DEFERRED while %3 is slung (alive=%4, dist=%5, tries=%6, issues=%7).", _sideText, _team, typeOf _slungVeh, _aliveNow, _curDist, _rTries, _rIssues]] Call WFBE_CO_FNC_AICOMLog;
						_canProduce = false;
					} else {
					//--- B68 STRANDED-MERGE (item stranded-survivor-merge-into-nearest-team-before-cull):
					//--- before throwing away a live trained body, try to JOIN the survivor into the nearest
					//--- healthy same-side SERVER-LOCAL team. Net groups DROP by one and the body keeps fighting.
					//--- A2-OA-safe: distance/count/select, GroupGetBool, `join` on a unit array, local on the
					//--- LEADER object (never on the group). Fall through to the existing cull if no eligible target.
					_mergeOn    = missionNamespace getVariable ["WFBE_C_AICOM_STRANDED_MERGE", 1];
					_mergeRange = missionNamespace getVariable ["WFBE_C_AICOM_STRANDED_MERGE_RANGE", 1200];
					_sizeMax    = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 8]; //--- _sizeMax is declared later inside if(_canProduce); read a local copy here for the 8-12 ceiling guard.
					_mergeTeam  = grpNull;
					_mergeBest  = _mergeRange;  //--- only accept candidates strictly inside the range cap
					if (_mergeOn > 0) then {
						{
							_cand = _x;
							if (!isNull _cand && {_cand != _team}) then {
								_candLdr = leader _cand;
								//--- (b) server-local + non-HC: leader local to server AND not an HC team.
								if (local _candLdr && {!(isPlayer _candLdr)} && {(behaviour _candLdr) != "COMBAT"} && {!([_cand, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
									_candAlive = {alive _x} count (units _cand);
									//--- (c) alive>=2 healthy, (d) below the 12 ceiling so the merge can't overflow
									//--- 8-12 policy: surviving body count must still fit (_candAlive + _aliveNow <= MAX).
									if (_candAlive >= 2 && {(_candAlive + _aliveNow) <= _sizeMax}) then {
										_d2 = _candLdr distance _ldr;
										if (_d2 < _mergeBest) then {_mergeBest = _d2; _mergeTeam = _cand};
									};
								};
							};
						} forEach _teams;
					};
					if (!isNull _mergeTeam) then {
						//--- MERGE: the survivor's live units join the healthy team; the now-empty old group is
						//--- deleted (its wfbe_teams entry becomes a null group, which every consumer already skips
						//--- -- same lifecycle as a wiped HC team / the existing cull). Net groups -1, body preserved.
						_mergedInto = _mergeTeam;  //--- capture for the log before _team is gutted
						(units _team) joinSilent _mergeTeam;  //--- N-FEATUREBUG-49 fix 2026-06-27: joinSilent (not join) to avoid leader churn / behaviour reset on the merged-into team.
						["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] stranded survivor MERGED into [%3] (alive=%4, dist=%5, mergeDist=%6) - body preserved, groups-1.", _sideText, _team, _mergedInto, _aliveNow, _curDist, round _mergeBest]] Call WFBE_CO_FNC_AICOMLog;
						deleteGroup _team;
						_canProduce = false;
					} else {
						//--- No eligible nearby team: existing cull, unchanged (guardrail = never strands the survivor).
						//--- Non-player guard is belt-and-braces (this branch is already server-local non-HC, non-player-led).
						{ if (!(isPlayer _x)) then {["produce-cull-unit", _x, Format ["tries=%1 issues=%2", _rTries, _rIssues]] Call WFBE_CO_FNC_LogVehDelete; deleteVehicle _x} } forEach (units _team);
						["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] retreat-thrash CULLED (alive=%3, dist=%4, tries=%5, issues=%6) - recycled (no-progress OR issue-cap OR too-far).", _sideText, _team, _aliveNow, _curDist, _rTries, _rIssues]] Call WFBE_CO_FNC_AICOMLog;
						deleteGroup _team;
						_canProduce = false;
					};
					};
				} else {
					//--- Still within budget: re-issue retreat + record this cycle's distance for the next
					//--- progress check.
					_team setVariable ["wfbe_aicom_retreat_tries", _rTries, true];
					_team setVariable ["wfbe_aicom_retreat_issues", _rIssues + 1, true]; //--- B68: monotonic re-issue count, never reset by progress.
					_team setVariable ["wfbe_aicom_retreat_lastdist", _curDist, true];
					_retreatOrder = _team getVariable "wfbe_aicom_order";
					if (isNil "_retreatOrder") then {_retreatOrder = [-1]};
					_retreatSeq = (_retreatOrder select 0) + 1;
					_retreatOrder = [_retreatSeq, "defense", getPosATL _hqP];
					_team setVariable ["wfbe_aicom_order", _retreatOrder, true];
					_team setVariable ["wfbe_aicom_refit", true, true]; //--- B61: mark for top-up-at-base once home.
					if (!_refitWas) then {
						_team setVariable ["wfbe_aicom_refit_start", time];
						diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|REFIT_START|team=" + str _team + "|alive=" + str _aliveNow);
					};
					_team setVariable ["wfbe_aicom_refit_prev", true];
					["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] retreat-and-reform ordered (alive=%3, dist=%4, tries=%5).", _sideText, _team, _aliveNow, _curDist, _rTries]] Call WFBE_CO_FNC_AICOMLog;
					_canProduce = false;
				};
			} else {
				//--- B67 RETREAT-CULL: the team is no longer a stuck lone survivor far from HQ (it reformed
				//--- to alive>=2, or is now within home-range). Reset the retreat failure counters to their
				//--- sentinel defaults (matching the read-path defaults above) so a future depletion starts a
				//--- fresh budget. Only touch them if a counter was actually set (read via the A2-safe 1-arg
				//--- getVariable + isNil guard; the 2-arg [name,default] form is unreliable for UNSET group vars).
				_rTries = _team getVariable "wfbe_aicom_retreat_tries";
				if (!isNil "_rTries") then {
					_team setVariable ["wfbe_aicom_retreat_tries", 0, true];
					_team setVariable ["wfbe_aicom_retreat_lastdist", -1, true];
					_team setVariable ["wfbe_aicom_retreat_issues", 0, true]; //--- B68: reset the monotonic re-issue count when the team reforms / returns in-range.
				};
				//--- B61 (Ray 2026-06-21): treat the OWN HQ as an always-eligible reinforce point. A team
				//--- that has retreated home (refit flag set + now within home-range of HQ) is forced
				//--- in-range so it refills regardless of REINFORCE_RANGE, is topped to the floor below,
				//--- then re-dispatched - rather than sitting at base as an un-refillable survivor.
				_refitAtBase = ([_team, "wfbe_aicom_refit", false] Call WFBE_CO_FNC_GroupGetBool) && {(_ldr distance _hqP) <= _homeR}; //--- B66: A2-safe GROUP bool read (was unreliable getVariable[name,default])
				if (!_refitAtBase && {_ldr distance _hqP > (missionNamespace getVariable ["WFBE_C_AI_COMMANDER_REINFORCE_RANGE", 1200])}) then {
					//--- FORWARD-REINFORCE: a deep team beyond base range may still refill if its
					//--- leader is hugging an owned town (front-line resupply), so spearheads stop
					//--- bleeding out far from HQ. The refill spawn point is pulled forward below.
					_nearFwd = false;
					if (_ownTowns > 0) then {
						_fwdR = missionNamespace getVariable ["WFBE_C_AICOM_FWD_REINFORCE_RANGE", 500];
						{ if (((_x getVariable "sideID") == _myID) && {(_ldr distance _x) < _fwdR}) exitWith {_nearFwd = true} } forEach towns;
					};
					if (!_nearFwd) then {_canProduce = false};
				};
			};
		};
	};
	if (_canProduce) then {
		_template = _templates select _type;
		_cur  = {alive _x} count (units _team);
		//--- punchy-AICOM SIZE FLOOR (Ray 2026-06-17; deficit-fill 2026-06-18): an infantry/light-motorized
		//--- team is built/topped-up to clamp(templateSize, MIN, MAX). MBT teams + ATTACK-HELI teams are
		//--- EXEMPT from the MIN floor (vehicle+crew is the punch - never pad with riflemen).
		//--- DEFICIT-FILL FIX (2026-06-18): the floor now applies on REFILL of an existing under-strength team
		//--- too (not only when _cur==0). Previously _cur>0 refills used floor=1, so a team that founded small
		//--- then refilled plateaued at its template size (~5.5) instead of 8-12; LIVE CMDRSTAT showed
		//--- unitsPerTeam 5.4-5.8 with captures=0. Under-strength non-MBT/non-attack-heli teams now top up
		//--- toward MIN (8). When the template composition is already complete but the team is still below the
		//--- floor, the selector below pads with an extra dismount (FILL-TO-FLOOR) so small patrols actually
		//--- reach 8-12. Still bounded by sizeMax/AI_MAX, the batch/funds caps, and the per-side AI ceiling.
		//--- A2-OA detection: classname-literal isKindOf + getNumber transportSoldier (no A3 primitives).
		private ["_tmplSize","_isMBT","_isAttackHeli","_floorN","_sizeMin","_sizeMax"];
		_tmplSize = count _template;
		_sizeMin  = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MIN", 8];
		_sizeMax  = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 8];
		_isMBT = false;
		{ if (_x isKindOf "Tank") exitWith {_isMBT = true} } forEach _template;
		_isAttackHeli = false;
		{ if (_x isKindOf "Helicopter" && {(getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier")) == 0}) exitWith {_isAttackHeli = true} } forEach _template;
		_floorN = if (!(_isMBT || _isAttackHeli)) then {_sizeMin} else {1};
		_want = ((_tmplSize max _floorN) min _sizeMax) min (missionNamespace getVariable "WFBE_C_AI_MAX");

		//--- RANK-2 health-gated refill (claude-gaming 2026-06-13): a critically-weak or JUST-FOUNDED server-local
		//--- team (alive < CRITICAL_STRENGTH of template) is rushed to FULL this cycle (effective batch = full
		//--- deficit) so server-local teams form WHOLE instead of dribbling 1-3/cycle, and depleted teams stop
		//--- lingering as 2-man remnants (cuts groups + drains the stuck war chest). Healthy teams keep the small
		//--- batch. STILL bounded by the funds gate + factory + the per-side AI cap, so no spawn runaway; HC teams
		//--- already skipped above. Set WFBE_C_AICOM_CRITICAL_STRENGTH <= 0 to disable (revert to flat batch cap).
		_effBatch = _batchCap;
		if (_want > 0 && {(_cur / _want) < (missionNamespace getVariable ["WFBE_C_AICOM_CRITICAL_STRENGTH", 0.30])}) then {
			_effBatch = _want - _cur;
		};

		if (_cur < _want) then {
			//--- V0.6.7: order up to batch cap units per team this cycle (deficit-capped; RANK-2 raises it for weak teams).
			_batchOrdered = 0;
			_ordered = []; //--- E7: per-class pending-order tally (reset per team)
			while {_cur < _want && _batchOrdered < _effBatch} do {
				//--- First template classname the team is still short on.
				_toBuild = "";
				{
					_d = _x;
					_have = ({typeOf _x == _d} count (units _team)) + ({_x == _d} count _ordered); //--- E7: real members + this-batch pending (async) orders
					if (_have < ({_x == _d} count _template)) exitWith {_toBuild = _d};
				} forEach _template;

				//--- FILL-TO-FLOOR (deficit-fill 2026-06-18): the template composition is already satisfied
				//--- but _cur is still below _want (the MIN floor raised the target above templateSize). Pad
				//--- with one extra dismount so infantry/light-motorized teams actually reach 8-12 instead of
				//--- plateauing at their template size. Pick the LAST man-class in the template (a basic
				//--- rifleman/grenadier) - never duplicate a vehicle. MBT/attack-heli teams never reach here
				//--- (floor=1 -> _want=templateSize). A2-OA safe: classname-literal isKindOf "Man".
				if (_toBuild == "") then {
					{ if (_x isKindOf "Man") then {_toBuild = _x} } forEach _template;
				};

				if (_toBuild == "") exitWith {}; //--- Nothing buildable (all-vehicle template) - stop batch.

				//--- Which production factory builds it?
				_fac = [];
				{
					_unitList = missionNamespace getVariable [Format ["WFBE_%1%2", _sideText, (_x select 1)], []];
					if (_toBuild in _unitList) exitWith {_fac = _x};
				} forEach _facDefs;

				if (count _fac == 0) exitWith {}; //--- No factory handles this class.

				_ud = missionNamespace getVariable _toBuild;
				if (isNil "_ud") exitWith {};

				_typeName = _fac select 0;
				_price    = _ud select QUERYUNITPRICE;

				//--- feat/common-isunitunlocked: shared facMap/QUERYUNITUPGRADE tier-unlock check (was the
				//--- inline _track=_fac select 2 / _reqUp compare; the shared function re-derives the SAME
				//--- track via its own facMap scan, since _fac (from _facDefs) mirrors that facMap 1:1).
				if (!(([_toBuild, _sideText, _upgrades] Call WFBE_CO_FNC_IsUnitUnlocked) select 0)) exitWith {}; //--- Not unlocked yet.

				_kind = _structTypes find _typeName;
				if (_kind < 0) exitWith {};

				_factories = [_side, _kind, _buildings] Call GetFactories;
				if (count _factories == 0) exitWith {};

				//--- FORWARD-REINFORCE: spawn the refill at the factory nearest this team's
				//--- leader. A forward team hugging a captured town refills from that town's
				//--- factory (resupplies the front) instead of a lone unit trekking from the
				//--- rear. Null leader (wiped team) falls back to factory[0] = reform at base.
				_facObj = _factories select 0;
				_ldr = leader _team;
				if (!isNull _ldr) then {
					{ if ((_x distance _ldr) < (_facObj distance _ldr)) then {_facObj = _x} } forEach _factories;
				};

				_funds = (_side) Call GetAICommanderFunds;
				if (_funds < _price) exitWith {}; //--- Cannot afford next unit; stop batch.

				//--- W15 BLACK MARKET (claude-gaming 2026-06-13): honor a live 50% discount flag set by the wildcard deck.
					private ["_w15Key","_w15Exp","_priceCharged"];
					_w15Key = Format ["wfbe_aicom_discount_%1", _sideText];
					_w15Exp = missionNamespace getVariable _w15Key;
					_priceCharged = if (!isNil "_w15Exp" && {_w15Exp > time}) then {round (_price * 0.5)} else {_price};
					[_side, -_priceCharged] Call ChangeAICommanderFunds;
					diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|UNIT_PRODUCED|class=" + _toBuild + "|factory=" + _typeName + "|cost=" + str _priceCharged + "|listCost=" + str _price + "|batch=" + str (_batchOrdered + 1));
				_isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};
				_id = [floor (random 1000000)];
				_q = _team getVariable "wfbe_queue";
				if (isNil "_q") then {_q = []};
				_q = _q + [_id];
				_team setVariable ["wfbe_queue", _q];
				//--- N8 fix: pass the exact _priceCharged (post W15-discount) so Server_BuyUnit.sqf can refund
				//--- the SAME amount on a createVehicle spawn failure instead of re-deriving list price.
				[_id, _facObj, _toBuild, _side, _team, _isVeh, _priceCharged] Spawn AIBuyUnit;
				_ordered = _ordered + [_toBuild]; //--- E7: record in-flight order so the selector counts it
				["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] ordering [%3] at %4 factory (cost %5, batch %6/%7 rich=%8).", _sideText, _team, _toBuild, _typeName, _price, _batchOrdered + 1, _batchCap, _richFlag]] Call WFBE_CO_FNC_AICOMLog;

				_batchOrdered = _batchOrdered + 1;
				_cur = _cur + 1; //--- Optimistic count so deficit loop terminates correctly.
			};
		};
		//--- B61 (Ray 2026-06-21) REFILL-AT-BASE: once a base-refitting team is back at/above the
		//--- founding floor, clear the refit flag so it stops being a special-case base hugger and the
		//--- strategy layer (wfbe_teammode) re-dispatches it to the front like any other full team.
		if (([_team, "wfbe_aicom_refit", false] Call WFBE_CO_FNC_GroupGetBool) && {_cur >= _want}) then { //--- B66: A2-safe GROUP bool read
			_refitStart = _team getVariable "wfbe_aicom_refit_start";
			if (isNil "_refitStart") then {_refitStart = time};
			_team setVariable ["wfbe_aicom_refit", false, true];
			_refitDur = round (time - _refitStart);
			if (_refitDur < 0) then {_refitDur = 0};
			if (_refitWas) then {
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|REFIT_END|team=" + str _team + "|alive=" + str _cur + "|durationSec=" + str _refitDur);
			};
			_team setVariable ["wfbe_aicom_refit_prev", false];
			["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] base-refit complete (cur=%3, floor=%4) - released for re-dispatch.", _sideText, _team, _cur, _want]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
