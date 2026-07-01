/*
	AI Commander - found new AI combat teams up to the side's target.
	feat/ai-commander V0.3. Server-side worker, full-command mode only.
	Parameter: _this = side.

	V0.3: whole teams are produced ON A HEADLESS CLIENT when one is registered
	(delegate-aicom-team -> Common_RunCommanderTeam.sqf): the brain picks a
	doctrine-weighted unlocked template, charges the full template price from
	AI commander funds, and ships the classnames + a spawn position at the
	doctrine factory to the HC. The HC creates and DRIVES the team locally
	(orders arrive via the public wfbe_aicom_order group variable) - server
	FPS cost ~ 0 and no factory-queue interference with human players.

	Fallback (no live HC): found an empty server-local group with the canonical
	Init_Server variable set; AssignTypes templates it and Produce builds its
	members at the factories per-unit (the V0.2 path).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_target","_aiTeams","_pending","_g","_hcs","_live","_templates","_tmplUpgrades","_upgrades","_eligible","_i","_u","_ok","_k","_doc","_track","_pref","_pick","_template","_price","_cn","_ud","_funds","_structures","_facClass","_facNames","_facIdx","_fac","_facObj","_real","_foundedTeams","_editorTeams","_totalGroups","_facMap","_unitList","_hcUnit","_base","_extra","_maxExtra","_fundsPerExtraTeam","_lastDynTarget",
              "_allUnits","_allGroups","_allVehicles",
              "_w7Flag","_w7BestIdx","_w7Idx","_w7U","_w7Score","_w7Best","_w7SkillSend",
              "_w11FreeFlag",
              "_buckets","_eu","_bClass","_mix","_dWeights","_wSum","_roll","_acc","_chosen","_clsOrder","_bi","_ti",
              "_storedTypes","_hasAirfield","_afNames","_unlockList","_holdsTrigger"]; //--- B66

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") then {_teams = []};

//--- Snapshot the engine-global arrays once for this founding decision. The same worker pass
//--- uses them for player scaling, safe retire checks, total-AI cap, group cap and vehicle caps;
//--- rereading allUnits/allGroups/vehicles for each question turns one cheap decision into
//--- several full-world scans.
_allUnits = allUnits;
_allGroups = allGroups;
_allVehicles = vehicles;

//--- V0.6 task 47: count FOUNDED teams (HC or server-local tag) and EDITOR-SLOT
//--- teams separately so editor-slot population never blocks genuine army founding.
//--- The founding gate uses only foundedTeams + pending vs the target.
_foundedTeams = 0;
_editorTeams  = 0;
{
	if (!isNull _x) then {
		_real = false;
		if (_x getVariable ["wfbe_aicom_hc", false]) then {_real = true};
		if (!_real && {_x getVariable ["wfbe_aicom_founded", false]}) then {_real = true};
		if (_real) then {
			_foundedTeams = _foundedTeams + 1;
		} else {
			//--- Editor-slot branch: alive AI leader with units present.
			if ((count units _x) > 0 && {!isPlayer (leader _x)} && {alive (leader _x)}) then {
				_editorTeams = _editorTeams + 1;
			};
		};
	};
} forEach _teams;
_aiTeams = _foundedTeams + _editorTeams; //--- legacy alias; used in server-local log below.
_pending = _logik getVariable ["wfbe_aicom_pending", 0];

//--- V0.6.6: dynamic target - banked funds scale the founding threshold so losing
//--- AIs convert wealth into pressure instead of hoarding.
_base             = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_TARGET",        4];
_fundsPerExtraTeam = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_FUNDS_PER_EXTRA_TEAM", 15000];
_maxExtra         = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TEAMS_MAX_EXTRA",      4];
_funds            = (_side) Call GetAICommanderFunds;
_extra            = floor (_funds / _fundsPerExtraTeam);
if (_extra > _maxExtra) then {_extra = _maxExtra};
_target           = _base + _extra;

//--- B36.1 (Ray 2026-06-15): PLAYER-COUNT SCALING override. Team count is the dominant server-FPS
//--- lever, so scale the target inversely with the HUMAN player count: more players = more server
//--- pressure = FEWER HQ squads; low pop is efficient + boring, so flood it with many more AI teams.
//--- This OVERRIDES the funds-based _base/_target above with a player-count curve (tunable via
//--- WFBE_C_AICOM_TEAMS_PC_*), keeping a small funds-extra that is throttled as pop rises so a rich
//--- AI can't bloat back past the curve when the server is busiest (income->quality is handled by
//--- the separate income scaler). Human count mirrors MonitorPlayerCount.sqf (isPlayer minus live HCs).
private ["_pcN","_hcN","_pcExtraCap"];
_pcN = {isPlayer _x} count _allUnits;
_hcN = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
_pcN = (_pcN - _hcN) max 0;
	//--- B74.2 UNIFIED POP-TIER publisher (Ray 2026-06-23): the live human count is already settled here, so compute
	//--- the tier and broadcast it ONCE per change so every AI subsystem (TOTAL_AI cap, town defenders/active-cap,
	//--- side-patrols, the per-player AI buy-cap) scales off ONE source. 0=LOW(0-2)/1=MID(3-5)/2=HIGH(6-9)/3=FULL(10+).
	private "_popTier";
	_popTier = switch (true) do { case (_pcN <= 2): {0}; case (_pcN <= 5): {1}; case (_pcN <= 9): {2}; default {3} };
	if (_popTier != (missionNamespace getVariable ["WFBE_PopTier", -1])) then {
		WFBE_PopTier = _popTier; publicVariable "WFBE_PopTier";
		diag_log format ["[POPTIER] humans=%1 tier=%2 (0=LOW 1=MID 2=HIGH 3=FULL)", _pcN, _popTier];
	};
_base = switch (true) do {
	case (_pcN <= 2): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_LOW",  12]};
	case (_pcN <= 5): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_MID",  4]};
	case (_pcN <= 9): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_HIGH", 3]};
	default          {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_FULL", 2]};
};
_pcExtraCap = switch (true) do { case (_pcN >= 10): {0}; case (_pcN >= 6): {1}; default {_maxExtra} };
if (_extra > _pcExtraCap) then {_extra = _pcExtraCap};
_target = _base + _extra;
_logik setVariable ["wfbe_aicom_pc", _pcN];

	//--- B37 BANKING VALVE (Ray 2026-06-16, gated WFBE_C_AICOM_BANKING_VALVE default-ON): at LOW/MID pop a
	//--- rich commander banks income it can't spend because the funds-extra is hard-capped (MAX_EXTRA=1).
	//--- When enabled, recompute the extra UNCAPPED from funds and lift it to LOWPOP_EXTRA so banked cash
	//--- converts to squads (livelier quiet nights). The high-pop caps (0/1) above are untouched, so a busy
	//--- server never bloats. Toggle the flag to A/B legacy vs NEXT. The dyntarget log below records the lift.
	if ((missionNamespace getVariable ["WFBE_C_AICOM_BANKING_VALVE", 1]) > 0 && {_pcN <= 5}) then {
		private ["_valveCap","_valveExtra","_valveTiers","_valveIdx"];
		_valveTiers = missionNamespace getVariable ["WFBE_C_AICOM_LOWPOP_EXTRA_BY_TIER", [3,2,0,0]];
		if ((typeName _valveTiers != "ARRAY") || {count _valveTiers == 0}) then {_valveTiers = [missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA", 3]]};
		_valveIdx = _popTier;
		if (_valveIdx < 0) then {_valveIdx = 0};
		if (_valveIdx >= count _valveTiers) then {_valveIdx = (count _valveTiers) - 1};
		_valveCap   = _valveTiers select _valveIdx;
		_valveExtra = floor (_funds / _fundsPerExtraTeam);
		if (_valveExtra > _valveCap) then {_valveExtra = _valveCap};
		if (_valveExtra > _extra) then {_extra = _valveExtra; _target = _base + _extra};
	};

//--- B747.1 HARD CAP (Ray 2026-06-24): clamp the founding target to a ceiling regardless of the PC curve +
//--- banking valve. AICOM was fielding ~15 teams at low pop (base 12 + valve 3); Ray wants max 8 going forward.
private "_teamsHardCap"; _teamsHardCap = missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_HARD_CAP", 8];
if (_target > _teamsHardCap) then {_target = _teamsHardCap; _extra = (_target - _base) max 0};

//--- Log only when the effective target changes (avoid RPT spam).
_lastDynTarget = _logik getVariable ["wfbe_aicom_dyntarget", _base];
if (_target > _base && {_target != _lastDynTarget}) then {
	_logik setVariable ["wfbe_aicom_dyntarget", _target];
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] dynamic target raised to %2 (base %3 + extra %4, funds %5).", _sideText, _target, _base, _extra, _funds]] Call WFBE_CO_FNC_AICOMLog;
};
if (_target == _base && {_lastDynTarget > _base}) then {
	_logik setVariable ["wfbe_aicom_dyntarget", _base];
};

//--- B35 HC-dispatch probe (claude-gaming 2026-06-15): Ray deferred the full timeout-replan fix; this
//--- cheap probe detects whether wfbe_aicom_pending STICKS. The counter is incremented on each HC
//--- dispatch and only decremented when the HC acks (wfbe_aicom_hc set). If an HC hiccups mid-dispatch
//--- the slot never frees, pinning founding below target. Log pending + how long it has been
//--- continuously >0; a large, growing pendingAgeSec across cycles = the stick the deferred fix targets.
//--- Silent while pending==0, so a healthy server produces no HCDISPATCH lines.
if (_pending > 0) then {
	private ["_pendSince"];
	_pendSince = _logik getVariable ["wfbe_aicom_pending_since", -1];
	if (_pendSince < 0) then {_pendSince = time; _logik setVariable ["wfbe_aicom_pending_since", _pendSince]};
	diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|HCDISPATCH|pending=" + str _pending + "|founded=" + str _foundedTeams + "|target=" + str _target + "|pendingAgeSec=" + str (round (time - _pendSince)));
	//--- B69 (pending-slot-timeout-reaper): a lost HC dispatch ack would pin _pending>0 forever, starving founding via the (_foundedTeams+_pending)>=_target guard below. After a timeout, reap the oldest still-pending slot so founding resumes. (_pending is a single per-side counter, so this ages the oldest pending slot, not a per-slot timer.)
	if ((time - _pendSince) > (missionNamespace getVariable ["WFBE_C_AICOM_PENDING_TIMEOUT", 270])) then {
		_pending = _pending - 1;
		_logik setVariable ["wfbe_aicom_pending", _pending];
		if (_pending > 0) then {_logik setVariable ["wfbe_aicom_pending_since", time]} else {_logik setVariable ["wfbe_aicom_pending_since", -1]};
		diag_log ("AICOMSTAT|v2|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|HCDISPATCH_REAP|pending->" + str _pending + "|reason=ack-timeout");
	};
} else {
	_logik setVariable ["wfbe_aicom_pending_since", -1];
};

//--- B36.1 on-join CLEANUP (Ray 2026-06-15): when players join, the curve lowers _target; if the
//--- side now holds MORE founded teams than target, retire the excess for immediate server relief.
//--- GUARDRAIL (hard): only retire REAR teams - far from ALL players AND not in combat - so a player
//--- never watches an AI vanish. The HC owns the units, so we only FLAG the team (wfbe_aicom_disband);
//--- its own loop re-checks proximity and deletes locally (server-side deleteVehicle on HC-local units
//--- ghosts the group sync). Staggered: at most one retirement flagged per cycle (smallest rear team).
if (_foundedTeams > _target) then {
	private ["_safeDist","_pick","_pickN","_ldr","_nearP","_inCombat"];
	_safeDist = missionNamespace getVariable ["WFBE_C_AICOM_DISBAND_SAFE_DIST", 900];
	_pick = grpNull; _pickN = 1e9;
	{
		if (!isNull _x && {_x getVariable ["wfbe_aicom_hc", false]} && {!(_x getVariable ["wfbe_aicom_disband", false])}) then {
			_ldr = leader _x;
			if (!isNull _ldr && {alive _ldr}) then {
				_nearP = {isPlayer _x && {alive _x} && {(_x distance _ldr) < _safeDist}} count _allUnits;
				_inCombat = (behaviour _ldr == "COMBAT") || ({alive _x && {side _x != _side} && {(_x distance _ldr) < _safeDist}} count _allUnits > 0);
				if (_nearP == 0 && {!_inCombat} && {(count units _x) < _pickN}) then {
					_pickN = count units _x; _pick = _x;
				};
			};
		};
	} forEach _teams;
	if (!isNull _pick) then {
		_pick setVariable ["wfbe_aicom_disband", true, true];
		["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] PC-cleanup flagged rear team %2 to retire (founded %3 > target %4, pc %5); HC self-deletes.", _sideText, _pick, _foundedTeams, _target, _pcN]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_RETIRED|reason=pc-scale|founded=" + str _foundedTeams + "|target=" + str _target + "|pc=" + str _pcN);
	};
};

//--- B74 VETERAN-SLOT (Ray 2026-06-22, review fix): the rich flag (AI_Commander.sqf) arms wfbe_aicom_veteran_next
//--- when the team target is already MET - but the founding gate just below early-exits at target, so the W7 premium
//--- branch never ran and the flag was INERT (review w0e91uqds, MED). When the Veteran flag is armed, grant ONE extra
//--- founding slot THIS tick so the premium platoon actually founds; the downstream W7 branch consumes the flag and
//--- promotes _pick to the top-tier template. Transient: next tick the flag is consumed/false and the target returns
//--- to normal (no permanent target inflation). Placed AFTER the PC-cleanup block so the +1 never triggers a retire.
//--- A2-OA-safe: boolean getVariable on the side-logic OBJECT _logik is reliable (not a group); plain if, no Bool ==.
if (_logik getVariable ["wfbe_aicom_veteran_next", false]) then {_target = (_target + 1) min _teamsHardCap}; //--- B747.1: veteran +1 must still respect the hard cap (never exceed max teams).

if ((_foundedTeams + _pending) >= _target) exitWith {};

//--- B74.2 (Ray 2026-06-23): enforce the TIERED per-side TOTAL_AI ceiling AT FOUNDING. The HC founding path had NO
//--- side-AI gate (only AI_Commander_Produce.sqf:28-30 did), so at low pop founding blew past the cap = the
//--- "infinite teams" overshoot. Same count as Produce (side AI minus players); cap from the pop-tier array.
private ["_aiCapTier","_aiCapTiers","_aiCapTierIndex","_aiCapTierLast","_sideAINow"];
_aiCapTiers = missionNamespace getVariable ["WFBE_C_TOTAL_AI_MAX_BY_TIER", [140,130,100,80]];
if ((count _aiCapTiers) < 1) then {_aiCapTiers = [missionNamespace getVariable ["WFBE_C_AI_COMMANDER_TOTAL_AI_MAX", 140]]};
_aiCapTierIndex = (missionNamespace getVariable ["WFBE_PopTier", 0]) max 0;
_aiCapTierLast = (count _aiCapTiers) - 1;
if (_aiCapTierIndex > _aiCapTierLast) then {_aiCapTierIndex = _aiCapTierLast};
_aiCapTier = _aiCapTiers select _aiCapTierIndex;
_sideAINow = {(side _x == _side) && !(isPlayer _x)} count _allUnits;
if (_sideAINow >= _aiCapTier) exitWith {
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] founding skipped - side AI %2 >= tier cap %3 (tier %4, pc %5).", _sideText, _sideAINow, _aiCapTier, (missionNamespace getVariable ["WFBE_PopTier", 0]), _pcN]] Call WFBE_CO_FNC_AICOMLog;
};

//--- V0.6 task 47: group-cap safety ceiling - skip founding if the side already has
//--- too many groups in the field (prevents ArmA engine group-limit crashes).
_totalGroups = {side _x == _side} count _allGroups;
if (_totalGroups > (missionNamespace getVariable ["WFBE_C_AICOM_GROUP_CAP", 110])) exitWith {
	private "_groupCapWarnLast";
	_groupCapWarnLast = _logik getVariable ["wfbe_aicom_groupcap_warn_t", -9999];
	if ((time - _groupCapWarnLast) >= 900) then {
		_logik setVariable ["wfbe_aicom_groupcap_warn_t", time];
		["WARNING", Format ["AI_Commander_Teams.sqf: [%1] group-cap ceiling reached (%2 groups) - founding skipped (founded %3, editor %4, pending %5, target %6).", _sideText, _totalGroups, _foundedTeams, _editorTeams, _pending, _target]] Call WFBE_CO_FNC_AICOMLog;
	};
};
_logik setVariable ["wfbe_aicom_groupcap_warn_t", -9999];

//--- Live HC available?
_hcs = missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []];
_live = [];
{if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {_live = _live + [_x]}} forEach _hcs;

if (count _live > 0) then {
	//--- V0.3 HC path: pick a doctrine-weighted UNLOCKED template now (the HC just builds it).
	_templates    = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
	_tmplUpgrades = missionNamespace getVariable Format ["WFBE_%1AITEAMUPGRADES", _sideText];
	if (isNil "_templates" || isNil "_tmplUpgrades") exitWith {};
	_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

	//--- B66 BUCKET-CLASSIFIER: load the AUTHORITATIVE per-template stored type (0=inf,1=light,
	//--- 2=heavy,3=air) built in Squads_GetFactionGroups (the CfgGroups category). The old picker
	//--- bucketed by the upgrade MASK, which mis-buckets motorized CfgGroups templates as infantry
	//--- (they often need no light-factory upgrade). Bucket by this stored value instead, nil-guarded
	//--- to the old upgrade-mask logic per template. Air ELIGIBILITY still rides the upgrade mask.
	_storedTypes = missionNamespace getVariable Format ["WFBE_%1AITEAMTYPES", _sideText]; //--- B66 (may be nil -> per-template fallback below).

	//--- B66 AIRFIELD-AIR RULE: precompute whether the side holds an airfield-tagged town. Airfield
	//--- town names are the capture-unlock/airfield anchors (e.g. NWAF/NEAF/Balota). Build the name
	//--- list from this side's CAPTURE_UNLOCKS data (the RM70_ACR anchor town is an airfield) plus the
	//--- well-known airfield names, then run the existing town-name+sideID forEach/exitWith scan. Also
	//--- accept a town that already carries the airfield hangar object (map-independent runtime marker).
	_hasAirfield = false;
	if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD", 1]) > 0) then {
		_afNames = ["NWAF","NEAF","Balota","Rasman AF"];
		{
			if (!((_x select 1) in _afNames)) then {_afNames = _afNames + [_x select 1]};
		} forEach (missionNamespace getVariable [Format ["WFBE_%1_CAPTURE_UNLOCKS", _sideText], []]);
		{
			if (((_x getVariable ["sideID", -1]) == _sideID) && {(_x getVariable ["wfbe_is_airfield", false]) || {(_x getVariable ["name",""]) in _afNames} || {!(isNull (_x getVariable ["wfbe_airfield_hangar_obj", objNull]))}}) exitWith {_hasAirfield = true}; //--- B74: PRIMARY check is the authoritative baked wfbe_is_airfield flag (set per-airfield in mission.sqm); name-list + hangar-obj kept as fallback.
		} forEach towns;
	} else {
		_hasAirfield = true; //--- rule disabled -> planes ungated (old behaviour).
	};

	//--- B74 AIRFIELD FREE-BUY (Ray 2026-06-22): holding a captured airfield lets the side buy JETS+HELIS
	//--- there even WITHOUT the Aircraft Factory and without the AIR_MIN_TOWNS wait (the field IS the air
	//--- enabler). When false (no field held) the normal gates stand, so an Aircraft Factory alone still
	//--- yields HELICOPTERS ONLY (planes need a held field via the plane-gate below).
	private ["_freeAirWaive"];
	_freeAirWaive = _hasAirfield && {(missionNamespace getVariable ["WFBE_C_AICOM_AIRFIELD_FREE_AIR", 1]) > 0};

	//--- V0.6.2: gate templates on REAL unit data too (same rule Produce uses) - the
	//--- hand-authored squad metadata is stale (RU tank platoon claims heavy 1; the
	//--- T72_RU unit data says heavy 3 for humans). Track = factory unit-list membership.
	_facMap = [["BARRACKSUNITS", WFBE_UP_BARRACKS], ["LIGHTUNITS", WFBE_UP_LIGHT], ["HEAVYUNITS", WFBE_UP_HEAVY], ["AIRCRAFTUNITS", WFBE_UP_AIR]];

	_eligible = [];
	for "_i" from 0 to (count _templates - 1) do {
		_u = _tmplUpgrades select _i;
		_ok = true;
		for "_k" from 0 to 3 do {
			if ((_u select _k) > (_upgrades select _k)) exitWith {_ok = false};
		};
		if (_ok) then {
			{
				_cn = _x;
				_ud = missionNamespace getVariable _cn;
				if (!isNil "_ud") then {
					{
						_unitList = missionNamespace getVariable [Format ["WFBE_%1%2", _sideText, _x select 0], []];
						if (_cn in _unitList) exitWith {
							if (((_ud select QUERYUNITUPGRADE) > (_upgrades select (_x select 1))) && {!(_freeAirWaive && {(_x select 1) == WFBE_UP_AIR})}) then {_ok = false}; //--- B74: at a captured airfield (free-buy) waive the AIR factory-tier requirement so jets+helis are buildable without the Aircraft Factory; non-air factory tiers still apply.
						};
					} forEach _facMap;
				};
				//--- B66 CAPTURE-UNLOCK eligibility: a template containing a CAPTURE_UNLOCKS class
				//--- (premium ACR units: T72M4CZ/RM70_ACR) is only eligible while this side HOLDS the
				//--- trigger town. Mirror the client gate (Client_UIFillListBuyUnits): match the class
				//--- in WFBE_%1_CAPTURE_UNLOCKS, then require the trigger town held (name+sideID scan).
				//--- A2-OA-safe: forEach/exitWith locate, no findIf. _holdsTrigger defaults true so a
				//--- non-premium class never gates. NOTE: the premium TEMPLATES are added by the groups
				//--- implementer; this only gates their eligibility.
				if (_ok && {(missionNamespace getVariable ["WFBE_C_CAPTURE_UNLOCKS", 0]) > 0}) then {
					_unlockList = missionNamespace getVariable [Format ["WFBE_%1_CAPTURE_UNLOCKS", _sideText], []];
					private ["_reqTown"];
					_reqTown = ""; //--- "" => _cn is not a capture-unlock class.
					{ if ((_x select 0) == _cn) exitWith {_reqTown = _x select 1} } forEach _unlockList;
					if (_reqTown != "") then {
						_holdsTrigger = false;
						{ if (((_x getVariable ["name",""]) == _reqTown) && {(_x getVariable ["sideID", -1]) == _sideID}) exitWith {_holdsTrigger = true} } forEach towns;
						if (!_holdsTrigger) then {_ok = false};
					};
				};
				if (!_ok) exitWith {};
			} forEach (_templates select _i);
		};
		if (_ok) then {_eligible set [count _eligible, _i]};
	};
	//--- STARVED-INFANTRY FALLBACK (cmdcon33 fix, Ray 2026-07-01): MUST run BEFORE the empty-set early-exit below.
	//--- The founding strip requires EVERY unit in a template to be upgrade-0, but side-upgrades start [0,0,0,0]. A
	//--- faction whose BASE infantry squad carries an upgrade>=1 leader (BIS_US US_Soldier_TL_EP1=1) has ALL infantry
	//--- stripped -> _eligible EMPTY -> the original cmdcon31 placement (AFTER this exitWith) never ran and WEST
	//--- founded 0 teams on Takistan. Admit the CHEAPEST (lowest upgrade-mask-sum) type-0 infantry so every faction
	//--- always founds a basic squad. Map-independent; self-heals as upgrades land. A2-OA-safe: forEach/for-do, isNil-guarded.
	if (!isNil "_storedTypes") then {
		private ["_hasInf","_fbBest","_fbBestMask","_ti2","_tType","_maskSum","_stX"];
		_hasInf = false;
		{ _stX = _storedTypes select _x; if (!isNil "_stX" && {_stX == 0}) exitWith {_hasInf = true} } forEach _eligible;
		if (!_hasInf) then {
			_fbBest = -1; _fbBestMask = 1e9;
			for "_ti2" from 0 to ((count _templates) - 1) do {
				_tType = _storedTypes select _ti2;
				if (!isNil "_tType" && {_tType == 0}) then {
					_maskSum = 0;
					{ _maskSum = _maskSum + _x } forEach (_tmplUpgrades select _ti2);
					if (_maskSum < _fbBestMask) then {_fbBestMask = _maskSum; _fbBest = _ti2};
				};
			};
			if (_fbBest >= 0) then {
				_eligible set [count _eligible, _fbBest];
				diag_log format ["AICOMGATE|%1|infFallback|admitted tmpl %2 maskSum=%3 sideUpg=%4 (no upgrade-0 infantry eligible)", _sideText, _fbBest, _fbBestMask, _upgrades];
			};
		};
	};
	if (count _eligible == 0) exitWith {};

	//--- Ray 2026-06-29 NO STATICS / NO WEAPON TEAMS: strip every eligible template that contains a StaticWeapon
	//--- (a towed gun, a mortar emplacement, or any crew-served static) so the AI NEVER founds a static gun or a
	//--- weapon team. The AI may field only TRACKED/WHEELED self-propelled artillery (GRAD/MLRS), which are vehicle
	//--- hulls (not StaticWeapon) and survive this filter. GUARDRAIL: if stripping would EMPTY the set, keep the
	//--- original (so founding is never starved) - in practice infantry/vehicle templates carry no statics, so this
	//--- only removes the rare weapon-team group. A2-OA-safe: string-form isKindOf on the template classnames.
	private ["_eligNoStatic","_swEi","_swHas"];
	_eligNoStatic = [];
	{
		_swEi = _x;
		_swHas = false;
		{ if ((typeName _x == "STRING") && {_x isKindOf "StaticWeapon"}) exitWith {_swHas = true} } forEach (_templates select _swEi);
		if (!_swHas) then {_eligNoStatic set [count _eligNoStatic, _swEi]};
	} forEach _eligible;
	if (count _eligNoStatic > 0) then {_eligible = _eligNoStatic};
	if (count _eligible == 0) exitWith {};

	//--- B59 ROSTER AIR-GATE (Ray 2026-06-20): the FOUNDING path (this file) had NO air-established gate, so
	//--- a heli template (cheapest helis carried QUERYUNITUPGRADE air=0) was eligible at air-research 0 with no
	//--- air factory. Mirror AI_Commander_Produce.sqf:47-52: until the side holds >= WFBE_C_AICOM_AIR_MIN_TOWNS
	//--- towns, strip ALL air templates from _eligible (FPS-safe; air is a late, established-only asset).
	private ["_rosterMyID","_rosterOwnTowns","_eligNoAir"];
	_rosterMyID = (_side) Call WFBE_CO_FNC_GetSideID;
	_rosterOwnTowns = 0;
	{ if ((_x getVariable "sideID") == _rosterMyID) then {_rosterOwnTowns = _rosterOwnTowns + 1} } forEach towns;
	if ((_rosterOwnTowns < (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) && {!_freeAirWaive}) then { //--- B74: a captured airfield (free-buy) exempts the AIR_MIN_TOWNS strip so air comes online immediately on field capture.
		_eligNoAir = [];
		{ if (((_tmplUpgrades select _x) select WFBE_UP_AIR) <= 0) then {_eligNoAir set [count _eligNoAir, _x]} } forEach _eligible;
		_eligible = _eligNoAir;
	};
	//--- cmdcon33 cleanup: the duplicate cmdcon31 fallback that used to sit here was removed.
	//--- The canonical fallback above runs before the first empty-set exit and survives static/air strips.
	if (count _eligible == 0) exitWith {};

	//--- B74.2 EMPTY-HELI CAP (Ray 2026-06-24): if the side already fields WFBE_C_AICOM_ATTACKHELI_MAX or more
	//--- ALIVE attack helis (non-transport Helicopter), strip every air template from _eligible so the founding
	//--- draw cannot create yet another premium AH1Z team that nothing retires/cleans. The bucket picker below
	//--- degrade-walks to a buildable ground class, so founding continues normally. 0 = no cap (old behaviour).
	//--- FLAW-FIX: count BOTH crewed AND crewless non-transport helis on this side. For crewed helis, side is
	//--- resolved via (crew _x) select 0 (reliable). For crewless helis, wfbe_side on the vehicle object is
	//--- checked first (falls back to sideUnknown if not tagged on this build, which is safe). A2-OA-safe:
	//--- isKindOf/getNumber/transportSoldier mirrors the L477 detector; count over vehicles (not allUnits).
	private ["_heliCap","_heliAlive","_eligNoAir2"];
	_heliCap = missionNamespace getVariable ["WFBE_C_AICOM_ATTACKHELI_MAX", 0]; if (_heliCap > 0) then {_heliCap = _heliCap + floor((((time / 60) min ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) / ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) * (missionNamespace getVariable ["WFBE_C_AICOM_ATTACKHELI_MAX_TIME_BONUS", 0]))}; //--- B754: grow the attack-heli cap over match time so the late air push isn't throttled at the early cap (0 base cap still = no cap).
	if (_heliCap > 0) then {
		_heliAlive = 0;
		{
			if (alive _x && {_x isKindOf "Helicopter"} && {(getNumber (configFile >> "CfgVehicles" >> (typeOf _x) >> "transportSoldier")) == 0}) then {
				if ((count crew _x) > 0 && {side ((crew _x) select 0) == _side}) then {
					_heliAlive = _heliAlive + 1;
				} else {
					if ((count crew _x) == 0 && {(_x getVariable ["wfbe_side", sideUnknown]) == _side}) then {
						_heliAlive = _heliAlive + 1;
					};
				};
			};
		} forEach _allVehicles;
		if (_heliAlive >= _heliCap) then {
			_eligNoAir2 = [];
			{ if (((_tmplUpgrades select _x) select WFBE_UP_AIR) <= 0) then {_eligNoAir2 set [count _eligNoAir2, _x]} } forEach _eligible;
			_eligible = _eligNoAir2;
			["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] B74.2 attack-heli cap hit (alive %2 >= cap %3) - air templates stripped from founding this cycle.", _sideText, _heliAlive, _heliCap]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	if (count _eligible == 0) exitWith {};

	//--- ARTY CAP (Ray 2026-06-27): at most WFBE_C_AICOM_ARTY_MAX artillery batteries ALIVE per AI commander. Mirror
	//--- of the attack-heli cap above: count alive arty hulls this side; at/over cap, strip every arty template from
	//--- _eligible so the founding draw degrade-walks to a buildable ground class. Counting alive HULLS (not a flag)
	//--- self-corrects - when the battery dies the count drops and arty is re-admitted next cycle.
	private ["_artyCap","_artyCls","_artyAlive","_eligNoArty","_hasArty","_ei"];
	_artyCap = missionNamespace getVariable ["WFBE_C_AICOM_ARTY_MAX", 1];
	//--- Ray 2026-06-29 SELF-PROPELLED-ONLY: build the arty-class list from THIS side's ARTILLERY_CLASSNAMES,
	//--- keeping ONLY tracked/wheeled self-propelled hulls (GRAD/MLRS/RM70/M1129) and dropping every static
	//--- towed gun (D30/M119) and mortar (2b14/M252). Replaces the old hardcoded ["MLRS","MLRS_DES_EP1",
	//--- "GRAD_RU","GRAD_TK_EP1"] literal (which missed GRAD_CDF/RM70_ACR/M1129 + only RU/TK GRAD variants),
	//--- so the ARTY_MAX cap AND the FORCED-ARTY guarantee below now track the lone SPG battery for every
	//--- faction. A2-OA-safe: string-form isKindOf on the classname (idiom: AwardBounty.sqf:34).
	_artyCls = [];
	{
		private ["_fam2","_aCls"];
		_fam2 = _x;
		{
			_aCls = _x;
			if ((typeName _aCls == "STRING") && {_aCls != ""} && {isClass (configFile >> "CfgVehicles" >> _aCls)}) then {
				if (((_aCls isKindOf "Tank") || (_aCls isKindOf "Car") || (_aCls isKindOf "Wheeled_APC") || (_aCls isKindOf "Tracked_APC")) && {!(_aCls isKindOf "StaticWeapon")}) then {
					if (!(_aCls in _artyCls)) then {_artyCls set [count _artyCls, _aCls]};
				};
			};
		} forEach (if (typeName _fam2 == "ARRAY") then {_fam2} else {[_fam2]});
	} forEach (missionNamespace getVariable [Format ["WFBE_%1_ARTILLERY_CLASSNAMES", _sideText], []]);
	if (count _artyCls == 0) then {_artyCls = ["MLRS","MLRS_DES_EP1","GRAD_RU","GRAD_TK_EP1","GRAD_CDF","RM70_ACR","M1129_MC_EP1"]}; //--- fallback SPG superset if the side arty config is missing (never a static class).
	if (_artyCap > 0) then {
		_artyAlive = 0;
		{
			if (alive _x && {(typeOf _x) in _artyCls}) then {
				if ((count crew _x) > 0 && {side ((crew _x) select 0) == _side}) then {
					_artyAlive = _artyAlive + 1;
				} else {
					if ((count crew _x) == 0 && {(_x getVariable ["wfbe_side", sideUnknown]) == _side}) then {_artyAlive = _artyAlive + 1};
				};
			};
		} forEach _allVehicles;
		if (_artyAlive >= _artyCap) then {
			_eligNoArty = [];
			{
				_ei = _x;   //--- capture the eligible-INDEX before the inner forEach clobbers _x.
				_hasArty = false;
				{ if (_x in _artyCls) exitWith {_hasArty = true} } forEach (_templates select _ei);
				if (!_hasArty) then {_eligNoArty set [count _eligNoArty, _ei]};
			} forEach _eligible;
			_eligible = _eligNoArty;
			["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] arty cap hit (alive %2 >= cap %3) - arty templates stripped this cycle.", _sideText, _artyAlive, _artyCap]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
	if (count _eligible == 0) exitWith {};

	//--- FORCED-ARTY (Ray 2026-06-27, Issue 3 Part 2): GUARANTEE the 1 artillery battery is founded once eligible.
	//--- The arty-cap strip above only stops OVER-building; the normal type-mix/eff-draw almost never PICKS the lone
	//--- arty template (diluted across buckets). When under the arty cap (_artyCap>0 && _artyAlive<_artyCap, i.e. the
	//--- strip block above did NOT remove arty, so an arty template is still in _eligible if the tier admits it), scan
	//--- _eligible for an arty template - REUSING the exact cap-strip test (any classname in _templates select _ei is
	//--- in _artyCls) - and force the founding draw onto it. Self-limiting: next cycle _artyAlive>=cap re-strips arty,
	//--- this scan finds none, and the normal draw resumes. _artyCap/_artyAlive are still in scope from the cap block
	//--- (declared in the function-level private list). The override of _pick is applied AFTER the normal draw (just
	//--- before _template = _templates select _pick) so it is the FINAL word and feeds the existing dispatch tail.
	private ["_forcedArtyPick","_faEi"];
	_forcedArtyPick = -1;
	if (_artyCap > 0 && {_artyAlive < _artyCap}) then {
		{
			_faEi = _x;   //--- capture the eligible-INDEX before the inner forEach rebinds _x to a classname.
			if (_forcedArtyPick < 0) then {
				{ if (_x in _artyCls) exitWith {_forcedArtyPick = _faEi} } forEach (_templates select _faEi);
			};
		} forEach _eligible;
		if (_forcedArtyPick >= 0) then {
			["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] FORCED-ARTY: under cap (alive %2 < cap %3), forcing founding draw onto arty template %4 this cycle.", _sideText, _artyAlive, _artyCap, _forcedArtyPick]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	//--- P1 combined-arms picker (claude-gaming 2026-06-15). Mirror of AI_Commander_AssignTypes.sqf:
	//--- the old doctrine-only weighting (70% one vehicle track, 30% UNIFORM over all eligible) averaged
	//--- ~70% infantry because infantry templates unlock first and stay eligible all match while vehicle
	//--- templates unlock late. Here _eligible is ALREADY gated on factory + real-unit-data tier, so any
	//--- bucketed pick is buildable. Bucket eligible by class (air>0->air / heavy>0->heavy / light>0->
	//--- light / else infantry), roll a target class from WFBE_C_AICOM_TYPE_MIX (with a light doctrine
	//--- nudge), degrade to a lower buildable class when the rolled one is empty, and never starve infantry.
	_buckets = [[],[],[],[]]; //--- [infantry, light, heavy, air]
	{
		_ti = _x; _eu = _tmplUpgrades select _ti; //--- A1 (Ray 2026-06-19): _ti captured because the helicopters-only `count` below rebinds _x.
		//--- B66 BUCKET-CLASSIFIER FIX: bucket by the AUTHORITATIVE CfgGroups stored type (0=inf,1=light,
		//--- 2=heavy,3=air) instead of the upgrade mask (which mis-buckets motorized templates that need
		//--- no light upgrade as infantry). nil-guarded per-template to the old upgrade-mask logic.
		_bClass = -1;
		if (!isNil "_storedTypes" && {_ti < count _storedTypes}) then {_bClass = _storedTypes select _ti};
		if (_bClass < 0) then {
			_bClass = 0; //--- infantry (fallback to old upgrade-mask logic)
			if ((_eu select WFBE_UP_AIR) > 0) then {_bClass = 3} else {
				if ((_eu select WFBE_UP_HEAVY) > 0) then {_bClass = 2} else {
					if ((_eu select WFBE_UP_LIGHT) > 0) then {_bClass = 1};
				};
			};
		};
		//--- A1 helicopters-only AICOM air (Ray 2026-06-19): the CfgGroups Air category (via Squads_GetFactionGroups) pulls
		//--- fixed-wing Su/plane + UAV groups the AI can't operate (no takeoff/RTB) so they pile up unused on the base.
		//--- B66 AIRFIELD-AIR RULE: a fixed-wing PLANE air template is admitted ONLY when the side holds an
		//--- airfield-tagged town (_hasAirfield, computed above from CAPTURE_UNLOCKS/airfield anchors). With no
		//--- airfield held this is identical to the old blanket strip (helicopters-only). Choppers (air, no Plane)
		//--- are unaffected and remain gated by the normal tier + AIR_MIN_TOWNS roster gate above.
		if (!((_bClass == 3) && {({_x isKindOf "Plane"} count (_templates select _ti)) > 0} && {(!_hasAirfield) || (time < (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) || (random 1 >= (((((time - (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) max 0) / (((missionNamespace getVariable ["WFBE_C_AICOM_JET_FULL_SECS", 18000]) - (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) max 1)) min 1)))})) then { //--- AICOM v2 JET TIME-RAMP: planes also gated by time (no jets <2h, ramp 2h->5h).
			(_buckets select _bClass) set [count (_buckets select _bClass), _ti];
		};
	} forEach _eligible;

	//--- B66 MATURITY-RAMPED MIX: select the [inf,light,heavy,air] weight tier by the side's OWN-TOWN count
	//--- (reuse _rosterOwnTowns from the air-gate above): EARLY when towns < MATURE_MID, MID when towns <
	//--- MATURE_LATE, else LATE. Fall back to the static WFBE_C_AICOM_TYPE_MIX if a tier const is nil.
	private ["_matMid","_matLate"];
	_matMid  = missionNamespace getVariable ["WFBE_C_AICOM_TYPE_MIX_MATURE_MID",  4];
	_matLate = missionNamespace getVariable ["WFBE_C_AICOM_TYPE_MIX_MATURE_LATE", 8];
	_mix = if (_rosterOwnTowns < _matMid) then {
		missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_EARLY"
	} else {
		if (_rosterOwnTowns < _matLate) then {
			missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_MID"
		} else {
			missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_LATE"
		};
	};
	if (isNil "_mix" || {count _mix < 4}) then {_mix = WFBE_C_AICOM_TYPE_MIX}; //--- B66: tier const nil -> static fallback.
	if (isNil "_mix" || {count _mix < 4}) then {_mix = [0.65, 0.20, 0.12, 0.03]};
	_dWeights = [_mix select 0, _mix select 1, _mix select 2, _mix select 3];
	_doc = _logik getVariable ["wfbe_aicom_doctrine", ""];
	if (_doc != "") then {
		_track = if (_doc == "HF") then {2} else {1};
		_dWeights set [_track, (_dWeights select _track) * 1.5];
	};
	//--- B69 #16 TOWN-PUNCH BIAS (HC-resident path, mirrors AssignTypes): nudge the roll toward
	//--- combat vehicles by scaling the heavy (idx 2) and light (idx 1) bucket weights. Applied AFTER
	//--- the doctrine nudge and BEFORE the zero-out/safety-walk so an empty bucket still zeroes out and
	//--- the degrade-walk still guarantees a buildable pick. Default 1.0 => exact no-op before the const
	//--- exists (missionNamespace getVariable [name,default], A2-OA-safe). Buckets [inf,light,heavy,air].
	_dWeights set [2, (_dWeights select 2) * (missionNamespace getVariable ["WFBE_C_AICOM_TOWNPUNCH_HEAVY_MULT", 1.0])]; _dWeights set [2, (_dWeights select 2) * (missionNamespace getVariable ["WFBE_C_AICOM_MECH_BIAS", 2.0])]; _dWeights set [1, (_dWeights select 1) * (missionNamespace getVariable ["WFBE_C_AICOM_MOTOR_BIAS", 1.4])]; //--- B755 (Ray 2026-06-25): seat infantry in ARMED vehicles, not on foot - bias the MECHANIZED/armor bucket (2 = IFV/APC that carry their dismounts) hardest + MOTORIZED (1) up vs pure-foot infantry (0). Self-gating: the empty-bucket zero-out below keeps infantry buildable when no heavy/light factory exists yet.
	_dWeights set [1, (_dWeights select 1) * (missionNamespace getVariable ["WFBE_C_AICOM_TOWNPUNCH_LIGHT_MULT", 1.0])];
		_dWeights set [3, (_dWeights select 3) * (1 + (((time / 60) min ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) / ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) * ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_MAXMULT", 2.5]) - 1))]; //--- B754 (Ray 2026-06-25) HELI TIME-BIAS: scale the AIR bucket (idx 3) up the longer the match runs (transport + attack both). Applied after town-punch, before the empty-bucket zero-out so an empty air bucket still zeroes safely. A2-OA-safe (time/min/^ arithmetic + getVariable default; RAMP_MIN floored at 1 to avoid /0).
		//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) REQUEST-UNIT HOOK: a fresh player class request nudges the founding bucket weight (soft).
		private ["_ruReq","_ruType","_ruT0","_ruMult","_ruIdx"];
		_ruReq = _logik getVariable "wfbe_aicom_request_type";
		if (!isNil "_ruReq" && {typeName _ruReq == "ARRAY"} && {count _ruReq == 2}) then {
			_ruType = _ruReq select 0; _ruT0 = _ruReq select 1;
			if ((time - _ruT0) < (missionNamespace getVariable ["WFBE_C_AICOM_POSTURE_TTL", 300])) then {
				_ruMult = missionNamespace getVariable ["WFBE_C_AICOM_REQUEST_TYPE_MULT", 3];
				_ruIdx = -1;
				if (_ruType == "infantry") then {_ruIdx = 0};
				if (_ruType == "armor")    then {_ruIdx = 2};
				if (_ruType == "air")      then {_ruIdx = 3};
				if (_ruIdx >= 0) then {_dWeights set [_ruIdx, (_dWeights select _ruIdx) * _ruMult]};
			};
		};
	for "_bi" from 0 to 3 do {
		if (count (_buckets select _bi) == 0) then {_dWeights set [_bi, 0]};
	};

	_wSum = (_dWeights select 0) + (_dWeights select 1) + (_dWeights select 2) + (_dWeights select 3);
	_chosen = -1;
	if (_wSum > 0) then {
		_roll = random _wSum;
		_acc = 0;
		for "_bi" from 0 to 3 do {
			_acc = _acc + (_dWeights select _bi);
			if (_chosen < 0 && {_roll < _acc}) then {_chosen = _bi};
		};
		if (_chosen < 0) then {_chosen = 0};
	};
	if (_chosen < 0 || {count (_buckets select _chosen) == 0}) then {
		_clsOrder = [2,1,3,0];
		{ if (count (_buckets select _x) > 0) exitWith {_chosen = _x} } forEach _clsOrder;
	};
	//--- ALL-EMPTY GUARD (2026-06-28): if EVERY bucket is empty the degrade-walk above leaves _chosen = -1 (the
	//--- all-jets-before-the-jet-ramp edge: the lone air bucket was time-gated out and no ground bucket is buildable
	//--- this cycle). The next line `_buckets select _chosen` would throw "select -1". This founding path picks at
	//--- most ONE team per call, so exitWith ends the founding cycle (nothing buildable = nothing to found). INERT in
	//--- normal cycles: the infantry bucket is virtually always populated, so _chosen >= 0 and this never fires.
	if (_chosen < 0) exitWith {};
	//--- B750 EFFECTIVENESS-WEIGHTED DRAW (Ray 2026-06-24, "don't bias highest VALUE, bias most EFFECTIVE units +
	//--- more variety"): the B74 draw weighted each template by (mission ECONOMY price)^1.5, so the commander spammed
	//--- its single most EXPENSIVE platoon. Now weight by (summed BI CfgVehicles "cost" = combat-threat rating)^EXP,
	//--- decoupled from what the economy charges, with a LOW exponent so the draw stays VARIED (a capable mix, not one
	//--- premium template). EXP=0 (or a single candidate) reproduces a pure uniform draw. A2-OA-safe: ^ power op,
	//--- configFile/getNumber are core 1.64 commands, manual index counter, outer _x captured into _cwIdx before the
	//--- inner forEach rebinds _x to the unit classname (the documented _ti gotcha at L282).
	private ["_cwBucket","_cwExp","_cwWeights","_cwSum","_cwIdx","_cwTmpl","_cwEff","_cwW","_cwRoll","_cwAcc","_cwI","_cwHasInf"];
	_cwBucket = _buckets select _chosen;
	_cwExp = missionNamespace getVariable ["WFBE_C_AICOM_EFF_BIAS_EXP", 0.5];
	_pick = -1;
	if (_cwExp <= 0 || {count _cwBucket <= 1}) then {
		_pick = _cwBucket select (floor (random (count _cwBucket)));
	} else {
		_cwWeights = [];
		_cwSum = 0;
		{
			_cwIdx  = _x;                       //--- capture: the inner forEach below rebinds _x to the unit classname.
			_cwTmpl = _templates select _cwIdx;
			_cwEff = 0; _cwHasInf = false;
			{ _cwEff = _cwEff + (getNumber (configFile >> "CfgVehicles" >> _x >> "cost")); if (getText (configFile >> "CfgVehicles" >> _x >> "simulation") == "soldier") then {_cwHasInf = true} } forEach _cwTmpl; //--- BI combat-threat value, NOT the mission economy price.
			if (_cwEff < 1) then {_cwEff = 1}; //--- floor: classes with no config cost still keep a non-zero chance.
			_cwW = _cwEff ^ _cwExp; if (_cwHasInf) then {_cwW = _cwW * (missionNamespace getVariable ["WFBE_C_AICOM_DISMOUNT_BIAS", 1.6])}; //--- B756 (Ray 2026-06-26): boost dismount-carrying templates (IFV/APC + squad) over bare gun-vehicles, so "heavy" leans mechanized-infantry not bare MBT.
			_cwWeights set [count _cwWeights, _cwW];
			_cwSum = _cwSum + _cwW;
		} forEach _cwBucket;
		_cwRoll = random _cwSum;
		_cwAcc = 0; _cwI = 0;
		{
			_cwAcc = _cwAcc + (_cwWeights select _cwI);
			if (_pick < 0 && {_cwRoll < _cwAcc}) then {_pick = _x};
			_cwI = _cwI + 1;
		} forEach _cwBucket;
		if (_pick < 0) then {_pick = _cwBucket select (count _cwBucket - 1)};
	};

	//--- B74.1 (Ray 2026-06-23) ANTI-REPEAT ("use differing templates"): if the cost-weighted draw landed on the
	//--- SAME template this side founded last time, reroll ONCE within the same bucket so the army stops fielding
	//--- identical squads back-to-back. The cost-weight already chose the price tier; this only breaks dead-repeats.
	//--- A2-OA-safe: getVariable on the side-logic OBJECT _logik is reliable. Stored AFTER the W7 override below.
	private ["_lastTmpl"];
	_lastTmpl = _logik getVariable ["wfbe_aicom_last_template", -1];
	if (_pick == _lastTmpl && {count (_buckets select _chosen) > 1}) then {
		private ["_rrTry"];
		_rrTry = (_buckets select _chosen) select (floor (random (count (_buckets select _chosen))));
		if (_rrTry != _pick) then {_pick = _rrTry};
	};

	//--- W7 Veteran Company: one-shot flag on logik -> use highest-upgrade eligible template.
	private ["_w7Flag","_w7Skill","_w7BestIdx","_w7Idx","_w7U","_w7Score","_w7Best"];
	_w7Flag = _logik getVariable "wfbe_aicom_veteran_next";
	if (isNil "_w7Flag") then {_w7Flag = false};
	if (_w7Flag) then {
		_logik setVariable ["wfbe_aicom_veteran_next", false];
		_w7BestIdx = _pick; _w7Best = -1;
		{
			_w7Idx = _x;
			_w7U   = _tmplUpgrades select _w7Idx;
			_w7Score = (_w7U select 0) + (_w7U select 1) + (_w7U select 2) + (_w7U select 3);
			if (({_x isKindOf "Plane"} count (_templates select _w7Idx)) > 0) then {_w7Score = -1}; //--- B59 jet-spam fix (Ray 2026-06-20): demote fixed-wing so W7 never promotes a jet squadron (the W7 scan was unfiltered; mirrors the L226 helicopters-only bucket filter).
			if (_w7Score > _w7Best) then {_w7Best = _w7Score; _w7BestIdx = _w7Idx};
		} forEach _eligible;
		_pick = _w7BestIdx;
		//--- B752 (Ray 2026-06-25): VETERAN ANTI-REPEAT. The deterministic highest-score pick returns the SAME premium
		//--- template every veteran tick (tmpl13 = 56% of WEST foundings = the variety-killer). If it would repeat the
		//--- last-founded template, reroll to a random eligible candidate so premium platoons VARY across the round.
		if (_pick == (_logik getVariable ["wfbe_aicom_last_template", -1]) && {count _eligible > 1}) then {_pick = _eligible select (floor (random (count _eligible)))};
		["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] W7 VeteranCompany applied - premium template %2.", _sideText, _pick]] Call WFBE_CO_FNC_AICOMLog;
	};
	//--- FORCED-ARTY override (Issue 3 Part 2): if an arty template was forced above, it wins the draw outright.
	//--- Applied as the LAST mutation of _pick so the normal bucket/eff-draw + anti-repeat + W7 results are discarded
	//--- this cycle and the lone artillery battery is GUARANTEED to found. _template/_price/factory/HC dispatch below
	//--- all read _pick, so no further wiring is needed. Inert (no-op) when _forcedArtyPick < 0 (normal cycles).
	if (_forcedArtyPick >= 0) then {_pick = _forcedArtyPick};
	_template = _templates select _pick;
	_logik setVariable ["wfbe_aicom_last_template", _pick]; //--- B74.1: record the actual founded template for the next founding's anti-repeat reroll.

	//--- B57 LARGER-GROUPS (Ray 2026-06-20): live teams are HC-founded at raw template size (3-6) and are NEVER
	//--- filled afterwards (AI_Commander_Produce skips wfbe_aicom_hc teams = 100% of live teams). So pad infantry
	//--- templates up to the team-size floor HERE, at founding, so every team founds at 8-12. Skip MBT/attack-heli
	//--- templates (the vehicle is the punch). The price loop below then charges for the bigger team and CreateTeam
	//--- builds it full on the HC. A2-OA-safe (no pushBack/A3 commands; +_template copies so the shared template isn't mutated).
	//--- B57 SOAK DRAFT (2026-06-20, claude-gaming, propose-only): pad to FOUND_SIZE (midband), not the
	//--- raw MIN floor. HC-founded teams are never refilled, so founding at the floor lets the live
	//--- average dribble below the 8-12 band (soak measured 4.2-5.1). FOUND_SIZE defaults to MIN if unset
	//--- and is clamped into [MIN,MAX]; behaviour is identical to before when FOUND_SIZE == MIN.
	private ["_sizeMin","_sizeMax","_foundSize","_isBigVeh","_padClass"];
	_sizeMin   = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MIN", 8];
	_sizeMax   = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 12];
	_foundSize = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_FOUND_SIZE", _sizeMin];
	if (_foundSize < _sizeMin) then {_foundSize = _sizeMin};
	if (_foundSize > _sizeMax) then {_foundSize = _sizeMax};
	_isBigVeh = false;
	{
		if (_x isKindOf "Tank") exitWith {_isBigVeh = true};
		if ((_x isKindOf "Helicopter") && ((getNumber (configFile >> "CfgVehicles" >> _x >> "transportSoldier")) == 0)) exitWith {_isBigVeh = true};
	} forEach _template;
	if (!_isBigVeh) then {
		_padClass = "";
		{ if (_x isKindOf "Man") then {_padClass = _x} } forEach _template;
		if ((_padClass != "") && (count _template < _foundSize)) then {
			_template = +_template;
			while {count _template < _foundSize} do { _template = _template + [_padClass] };
			["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] B57 padded infantry team to found-size (%2 units).", _sideText, count _template]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	//--- B66 INF-TRANSPORT TRUCK: a PURE-INFANTRY team (every template entry is Man-class) on a long
	//--- approach needs wheels - AssignTowns caps a footed team at REACH_FOOT, skipping far targets. When
	//--- WFBE_C_AICOM_INF_TRANSPORT>0 AND the side has a Light+ factory (Light/Heavy/Aircraft) AND the
	//--- template has NO ground vehicle, prepend a faction troop-truck to a COPY of the template so
	//--- CreateTeam crews it and the existing HC mount-up seats the infantry. Truck classname resolves
	//--- per-side from the Core transport lists (WFBE_%1REDEPLOYTRUCKS = MTVR/Kamaz; GUER falls back to
	//--- its V3S troop truck). A2-OA-safe: classname-literal isKindOf, +_template copy (no shared mutation).
	//--- ARMED-TRANSPORT-ONLY conflict fix (2026-06-22, Ray "trucks that linger"): when
	//--- WFBE_C_AICOM_ARMED_TRANSPORT_ONLY is ON the ride-pool (Common_RunCommanderTeam) refuses unarmed
	//--- trucks, so this prepended troop-truck is NEVER boarded and LINGERS empty beside the team. Skip the
	//--- prepend entirely when armed-transport-only is on -> the infantry road-march on foot, no dead truck.
	if (((missionNamespace getVariable ["WFBE_C_AICOM_INF_TRANSPORT", 1]) > 0) && {(missionNamespace getVariable ["WFBE_C_AICOM_ARMED_TRANSPORT_ONLY", 1]) <= 0}) then {
		private ["_pureInf","_hasLightPlus","_facNamesT","_structuresT","_truck","_truckList"];
		_pureInf = true;
		{ if (!(_x isKindOf "Man")) exitWith {_pureInf = false} } forEach _template;
		if (_pureInf && {count _template > 0}) then {
			//--- Light+ factory existence (mirror the spawn-factory scan below): any alive Light/Heavy/Aircraft.
			_hasLightPlus = false;
			_facNamesT    = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
			_structuresT  = (_side) Call WFBE_CO_FNC_GetSideStructures;
			if (!isNil "_facNamesT") then {
				{
					_facIdx = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText]) find _x;
					if (_facIdx >= 0) then {
						_facClass = _facNamesT select _facIdx;
						{ if (typeOf _x == _facClass && {alive _x}) exitWith {_hasLightPlus = true} } forEach _structuresT;
					};
					if (_hasLightPlus) exitWith {};
				} forEach ["Light","Heavy","Aircraft"];
			};
			if (_hasLightPlus) then {
				//--- Resolve a per-side troop truck. WFBE_%1REDEPLOYTRUCKS is the faction transport (MTVR/Kamaz);
				//--- GUER has none defined, so fall back to its V3S troop carrier classnames.
				_truck = "";
				_truckList = missionNamespace getVariable [Format ["WFBE_%1REDEPLOYTRUCKS", _sideText], []];
				if (count _truckList > 0) then {_truck = _truckList select 0};
				if (_truck == "") then {
					{ if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith {_truck = _x} } forEach ["V3S_TK_GUE_EP1","V3S_Gue","WarfareSupplyTruck_Gue"];
				};
				if (_truck != "" && {isClass (configFile >> "CfgVehicles" >> _truck)}) then {
					_template = [_truck] + _template; //--- prepend on a fresh array (no shared-template mutation).
					["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] B66 prepended troop-truck %2 to pure-infantry founding template (%3 units total).", _sideText, _truck, count _template]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
	};

	//--- Full template price from AI commander funds (whole-team purchase economics).
	_price = 0;
	{
		_cn = _x;
		_ud = missionNamespace getVariable _cn;
		if (!isNil "_ud") then {_price = _price + (_ud select QUERYUNITPRICE)};
	} forEach _template;
	_funds = (_side) Call GetAICommanderFunds;

	//--- W11 Field Hospital: one-shot free re-founding flag - waive the price check once.
	private ["_w11FreeFlag"];
	_w11FreeFlag = _logik getVariable "wfbe_aicom_free_refound";
	if (isNil "_w11FreeFlag") then {_w11FreeFlag = false};
	if (_w11FreeFlag) then {
		_logik setVariable ["wfbe_aicom_free_refound", false];
		_funds = _price; //--- Satisfy the funds gate without deducting.
		["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] W11 FieldHospital free-refound flag consumed.", _sideText]] Call WFBE_CO_FNC_AICOMLog;
	};

	if (_funds < _price) exitWith {};

	//--- Spawn at the doctrine factory (fallback: Barracks, then the HQ).
	_facNames = missionNamespace getVariable Format ["WFBE_%1STRUCTURENAMES", _sideText];
	_structures = (_side) Call WFBE_CO_FNC_GetSideStructures;
	_facObj = objNull;
	{
		_facIdx = (missionNamespace getVariable Format ["WFBE_%1STRUCTURES", _sideText]) find _x;
		if (_facIdx >= 0) then {
			_facClass = _facNames select _facIdx;
			{ if (typeOf _x == _facClass && {alive _x}) exitWith {_facObj = _x} } forEach _structures;
		};
		if (!isNull _facObj) exitWith {};
	} forEach (if (_doc == "HF") then {["Heavy","Light","Barracks"]} else {["Light","Heavy","Barracks"]});
	if (isNull _facObj) then {_facObj = (_side) Call WFBE_CO_FNC_GetSideHQ};
	if (isNull _facObj) exitWith {};

	//--- W11 free-refound: do not deduct funds (founding is free this one time).
	if (!_w11FreeFlag) then {
		[_side, -_price] Call ChangeAICommanderFunds;
	};
	_logik setVariable ["wfbe_aicom_pending", _pending + 1];
	if (_pending <= 0) then {_logik setVariable ["wfbe_aicom_pending_since", time]};
	//--- V0.6.4: name the receiving HC in the log - the random pick spreads load across
	//--- all live HCs, and the server RPT should show the split without reading HC RPTs.
	//--- Commander teams are the BIG atomic lumps (a whole platoon lands on ONE HC), so
	//--- picking the least-loaded HC matters most here. Least-loaded self-corrects: once an
	//--- HC is heavy it stops being chosen until the other catches up.
	_hcUnit = Call WFBE_CO_FNC_PickLeastLoadedHC;
	//--- Funds were already deducted and pending incremented above, and _live is non-empty in
	//--- this synchronous branch, so the picker cannot return objNull here. Fall back to the
	//--- first live HC rather than aborting (which would leak the deducted funds / pending slot).
	if (isNull _hcUnit) then {_hcUnit = leader (_live select 0)};
	//--- W7 skill boost: pass expected skill level in the delegate message if flag was active.
	_w7SkillSend = _logik getVariable "wfbe_aicom_veteran_skill";
	if (isNil "_w7SkillSend") then {_w7SkillSend = 0};
	_logik setVariable ["wfbe_aicom_veteran_skill", 0]; // consume
	//--- B69 template stamp: carry the template index + refill pad-class so the founded group
	//--- keeps its source template metadata without another template round-trip.
	//--- _padClass = LAST Man-class in the FINAL _template (the basic dismount), "" for all-vehicle teams.
	//--- APPENDED as trailing args (slots 5/6 of the inner array) so the W7 skill arg stays at slot 3 and
	//--- the 3-arg server-local CreateTeam calls (which never reach this delegate) are unaffected. Purely
	//--- additive: no current reader, so default behaviour is unchanged. A2-OA-safe (isKindOf/select/forEach).
	private ["_padClass"];
	_padClass = "";
	{ if (_x isKindOf "Man") then {_padClass = _x} } forEach _template;
	//--- AICOM v2 JET RUNWAY-SPAWN (Ray 2026-06-27): a fixed-wing (Plane) team spawns on the CAPTURED AIRFIELD
	//--- runway (the owned airfield town's hangar/logic), not at the rear factory - so it can take off + operate.
	//--- Self-contained + gated to jet teams only (inert for every existing ground/heli founding).
	private ["_spawnPos","_isJetTeam"];
	_isJetTeam = ({_x isKindOf "Plane"} count _template) > 0;
	_spawnPos = getPos _facObj;
	//--- AICOM v2 (Ray): spawn at the factory's SPAWN BEACON - the HeliH-family pad players use (the closest pad
	//--- within 80m is THIS factory's own), so AI teams egress from the designated spot, not the raw factory hull.
	//--- HeliHRescue/HeliHCivil inherit HeliH; Sr_border is the barracks pad. Jets override to the airfield below.
	private ["_padList","_bestPad","_bestD"];
	_padList = (_facObj nearObjects ["HeliH", 80]) + (_facObj nearObjects ["Sr_border", 80]);
	_bestPad = objNull; _bestD = 1e9;
	{ if (!isNull _x && {(_x distance _facObj) < _bestD}) then {_bestD = _x distance _facObj; _bestPad = _x} } forEach _padList;
	if (!isNull _bestPad) then {_spawnPos = getPos _bestPad};
	if (_isJetTeam && {_hasAirfield}) then {
		private ["_afTown","_haObj"];
		_afTown = objNull;
		{ if (((_x getVariable ["sideID", -1]) == _sideID) && {(_x getVariable ["wfbe_is_airfield", false]) || {!(isNull (_x getVariable ["wfbe_airfield_hangar_obj", objNull]))}}) exitWith {_afTown = _x} } forEach towns;
		if (!isNull _afTown) then {
			_haObj = _afTown getVariable ["wfbe_hangar", objNull];
			if (isNull _haObj) then {_haObj = _afTown getVariable ["wfbe_airfield_hangar_obj", objNull]};
			_spawnPos = if (!isNull _haObj) then {getPos _haObj} else {getPos _afTown};
		};
	};
	//--- DISBAND-LOW-TIER STAMP (2026-06-28): HC-founded teams SKIP AssignTypes, so they never get wfbe_teamtype
	//--- stamped -> AI_Commander_DisbandLowTier could never classify (and used to throw) on them. wfbe_teamtype is the
	//--- TEMPLATE INDEX - the SAME value AssignTypes stores (L241: setVariable ["wfbe_teamtype", _pick]); every reader
	//--- (DisbandLowTier's _types select _tt, Produce, AI_Commander) resolves the 0-3 type from it ITSELF. So stamp the
	//--- picked template index _pick, NOT a pre-resolved type. Thread it as a TRAILING delegate arg so
	//--- Common_RunCommanderTeam can setVariable ["wfbe_teamtype", ...] at founding. A2-OA-safe (typeName + isNil).
	private ["_foundType"];
	_foundType = -1;
	if (!isNil "_pick" && {typeName _pick == "SCALAR"} && {_pick >= 0}) then {_foundType = _pick};
	[_hcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _template, _spawnPos, _w7SkillSend, _pick, _padClass, _foundType]] Call WFBE_CO_FNC_SendToClient;
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] HC team founding dispatched to HC [%2] (template %3, cost %4, doctrine %5, founded %6 editor %7 pending->%8 target %9 veteran_skill=%10).", _sideText, name _hcUnit, _pick, _price, _doc, _foundedTeams, _editorTeams, _pending + 1, _target, _w7SkillSend]] Call WFBE_CO_FNC_AICOMLog;
	//--- PRODUCTION class telemetry (claude-gaming 2026-06-15): classify the founded team's
	//--- template by its min-upgrade requirements ([barracks,light,heavy,air] = _tmplUpgrades
	//--- select _pick) so the infantry-vs-vehicle mix is visible. air>0 -> air, else heavy>0 ->
	//--- heavy, else light>0 -> light, else infantry. Rides the existing TEAM_FOUNDED event.
	private ["_clsU","_cls"];
	_clsU = _tmplUpgrades select _pick;
	_cls = "infantry";
	if ((_clsU select WFBE_UP_AIR) > 0) then {_cls = "air"} else {
		if ((_clsU select WFBE_UP_HEAVY) > 0) then {_cls = "heavy"} else {
			if ((_clsU select WFBE_UP_LIGHT) > 0) then {_cls = "light"};
		};
	};
	diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_FOUNDED|via=HC|template=" + str _pick + "|class=" + _cls + "|cost=" + str _price);
} else {
	//--- Fallback (no HC): found a server-local empty team; AssignTypes + Produce feed it.
	_g = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
	if (isNull _g) exitWith {
		// Note: WFBE_CO_FNC_CreateGroup already logs the grpNull warning; this exitWith handles the no-op gracefully.
	};
	_g setVariable ["wfbe_aicom_founded", true];
	_g setVariable ["wfbe_funds", 0, true];
	_g setVariable ["wfbe_side", _side];
	_g setVariable ["wfbe_persistent", true];
	_g setVariable ["wfbe_queue", []];
	_g setVariable ["wfbe_vote", -1, true];
	[_g, false] Call SetTeamAutonomous;
	[_g, ""] Call SetTeamRespawn;
	[_g, -1] Call SetTeamType;
	[_g, "towns"] Call SetTeamMoveMode;
	[_g, [0,0,0]] Call SetTeamMovePos;
	_logik setVariable ["wfbe_teams", _teams + [_g], true];
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] founded server-local AI team (founded %2->%3 editor %4 target %5) [%6].", _sideText, _foundedTeams, _foundedTeams + 1, _editorTeams, _target, _g]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_FOUNDED|server-local");
};
