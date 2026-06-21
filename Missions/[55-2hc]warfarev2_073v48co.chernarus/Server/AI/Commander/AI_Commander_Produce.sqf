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

private ["_side","_sideText","_logik","_cap","_sideAI","_teams","_templates","_upgrades","_buildings","_structTypes","_facDefs","_team","_type","_template","_want","_cur","_toBuild","_d","_have","_fac","_unitList","_typeName","_track","_ud","_reqUp","_price","_kind","_factories","_isVeh","_id","_q","_canProduce","_funds","_hqP","_batchCap","_batchOrdered","_richFlag","_myID","_ownTowns","_nearFwd","_fwdR","_facObj","_ldr","_effBatch","_ordered","_aliveNow","_retreatSeq","_retreatOrder","_homeR","_refitAtBase","_curDist","_rTries","_rLast","_rBudget","_rProgress","_rMinClose"];

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

//--- V0.6.7: batch cap - tunable, doubled when supervisor sets the wealth-rich flag.
_batchCap = missionNamespace getVariable ["WFBE_C_AICOM_PRODUCE_BATCH", 3];
_richFlag = _logik getVariable ["wfbe_aicom_reinforce_rich", false];
if (_richFlag) then {_batchCap = _batchCap * 2};

//--- Safety cap: do not produce above the per-side AI ceiling.
_cap = missionNamespace getVariable "WFBE_C_AI_COMMANDER_TOTAL_AI_MAX";
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
if (_ownTowns >= (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) then {
	_facDefs = _facDefs + [["Aircraft","AIRCRAFTUNITS",WFBE_UP_AIR]];
};

{
	_team = _x;
	//--- V0.6.5: skip NULL entries (wiped HC teams; getVariable on a null group returns
	//--- nil even with a default -> the lazy-brace check below threw and killed Produce,
	//--- stopping ALL factory purchases for editor teams).
	if (!isNull _team) then {
	_type = _team getVariable ["wfbe_teamtype", -1];
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
				if (count (_team getVariable ["wfbe_queue", []]) == 0) then {_canProduce = true};
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
				//--- Progress = closed at least _rMinClose metres toward HQ since the last re-issue. A first
				//--- attempt (_rLast < 0) counts as progress so we never cull on the very first order.
				_rProgress = (_rLast < 0) || {(_rLast - _curDist) >= _rMinClose};
				if (_rProgress) then {
					//--- Making headway home (or first order): reset the failure counter, keep ordering.
					_rTries = 0;
				} else {
					_rTries = _rTries + 1;
				};
				if (_rTries >= _rBudget) then {
					//--- Budget exhausted with no progress: cull the stuck survivor. Non-player guard is
					//--- belt-and-braces (this branch is already server-local non-HC, non-player-led).
					{ if (!(isPlayer _x)) then {deleteVehicle _x} } forEach (units _team);
					["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] retreat-thrash CULLED (alive=%3, dist=%4, tries=%5) - no progress, recycled.", _sideText, _team, _aliveNow, _curDist, _rTries]] Call WFBE_CO_FNC_AICOMLog;
					deleteGroup _team;
					_canProduce = false;
				} else {
					//--- Still within budget: re-issue retreat + record this cycle's distance for the next
					//--- progress check.
					_team setVariable ["wfbe_aicom_retreat_tries", _rTries, true];
					_team setVariable ["wfbe_aicom_retreat_lastdist", _curDist, true];
					_retreatSeq = ((_team getVariable ["wfbe_aicom_order", [-1]]) select 0) + 1;
					_retreatOrder = [_retreatSeq, "DEFENSE", getPosATL _hqP];
					_team setVariable ["wfbe_aicom_order", _retreatOrder, true];
					_team setVariable ["wfbe_aicom_refit", true, true]; //--- B61: mark for top-up-at-base once home.
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
		_sizeMax  = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 12];
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
				_track    = _fac select 2;
				_reqUp    = _ud select QUERYUNITUPGRADE;
				_price    = _ud select QUERYUNITPRICE;

				if (_reqUp > (_upgrades select _track)) exitWith {}; //--- Not unlocked yet.

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
				_isVeh = if (_toBuild isKindOf "Man") then {[]} else {[true,true,true,true]};
				_id = [floor (random 1000000)];
				_q = (_team getVariable ["wfbe_queue", []]) + [_id];
				_team setVariable ["wfbe_queue", _q];
				[_id, _facObj, _toBuild, _side, _team, _isVeh] Spawn AIBuyUnit;
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
			_team setVariable ["wfbe_aicom_refit", false, true];
			["INFORMATION", Format ["AI_Commander_Produce.sqf: [%1] team [%2] base-refit complete (cur=%3, floor=%4) - released for re-dispatch.", _sideText, _team, _cur, _want]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
