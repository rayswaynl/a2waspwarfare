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
              "_w7Flag","_w7BestIdx","_w7Idx","_w7U","_w7Score","_w7Best","_w7SkillSend",
              "_w11FreeFlag",
              "_buckets","_eu","_bClass","_mix","_dWeights","_wSum","_roll","_acc","_chosen","_clsOrder","_bi","_ti"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") then {_teams = []};

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
_pcN = {isPlayer _x} count allUnits;
_hcN = {!isNull _x && {!isNull leader _x} && {alive leader _x}} count (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
_pcN = (_pcN - _hcN) max 0;
_base = switch (true) do {
	case (_pcN <= 2): {missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_PC_LOW",  6]};
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
		private ["_valveCap","_valveExtra"];
		_valveCap   = missionNamespace getVariable ["WFBE_C_AICOM_TEAMS_LOWPOP_EXTRA", 6];
		_valveExtra = floor (_funds / _fundsPerExtraTeam);
		if (_valveExtra > _valveCap) then {_valveExtra = _valveCap};
		if (_valveExtra > _extra) then {_extra = _valveExtra; _target = _base + _extra};
	};

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
				_nearP = {isPlayer _x && {alive _x} && {(_x distance _ldr) < _safeDist}} count allUnits;
				_inCombat = (behaviour _ldr == "COMBAT") || ({alive _x && {side _x != _side} && {(_x distance _ldr) < _safeDist}} count allUnits > 0);
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

if ((_foundedTeams + _pending) >= _target) exitWith {};

//--- V0.6 task 47: group-cap safety ceiling - skip founding if the side already has
//--- too many groups in the field (prevents ArmA engine group-limit crashes).
_totalGroups = {side _x == _side} count allGroups;
if (_totalGroups > 110) exitWith {
	["WARNING", Format ["AI_Commander_Teams.sqf: [%1] group-cap ceiling reached (%2 groups) - founding skipped (founded %3, editor %4, pending %5, target %6).", _sideText, _totalGroups, _foundedTeams, _editorTeams, _pending, _target]] Call WFBE_CO_FNC_AICOMLog;
};

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
							if ((_ud select QUERYUNITUPGRADE) > (_upgrades select (_x select 1))) then {_ok = false};
						};
					} forEach _facMap;
				};
				if (!_ok) exitWith {};
			} forEach (_templates select _i);
		};
		if (_ok) then {_eligible set [count _eligible, _i]};
	};
	if (count _eligible == 0) exitWith {};

	//--- B59 ROSTER AIR-GATE (Ray 2026-06-20): the FOUNDING path (this file) had NO air-established gate, so
	//--- a heli template (cheapest helis carried QUERYUNITUPGRADE air=0) was eligible at air-research 0 with no
	//--- air factory. Mirror AI_Commander_Produce.sqf:47-52: until the side holds >= WFBE_C_AICOM_AIR_MIN_TOWNS
	//--- towns, strip ALL air templates from _eligible (FPS-safe; air is a late, established-only asset).
	private ["_rosterMyID","_rosterOwnTowns","_eligNoAir"];
	_rosterMyID = (_side) Call WFBE_CO_FNC_GetSideID;
	_rosterOwnTowns = 0;
	{ if ((_x getVariable "sideID") == _rosterMyID) then {_rosterOwnTowns = _rosterOwnTowns + 1} } forEach towns;
	if (_rosterOwnTowns < (missionNamespace getVariable ["WFBE_C_AICOM_AIR_MIN_TOWNS", 4])) then {
		_eligNoAir = [];
		{ if (((_tmplUpgrades select _x) select WFBE_UP_AIR) <= 0) then {_eligNoAir set [count _eligNoAir, _x]} } forEach _eligible;
		_eligible = _eligNoAir;
	};
	if (count _eligible == 0) exitWith {};

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
		_bClass = 0; //--- infantry
		if ((_eu select WFBE_UP_AIR) > 0) then {_bClass = 3} else {
			if ((_eu select WFBE_UP_HEAVY) > 0) then {_bClass = 2} else {
				if ((_eu select WFBE_UP_LIGHT) > 0) then {_bClass = 1};
			};
		};
		//--- A1 helicopters-only AICOM air (Ray 2026-06-19): the CfgGroups Air category (via Squads_GetFactionGroups) pulls
		//--- fixed-wing Su/plane + UAV groups the AI can't operate (no takeoff/RTB) so they pile up unused on the base. Drop
		//--- any air template that contains a Plane -> only helicopter air teams are ever founded.
		if (!((_bClass == 3) && {({_x isKindOf "Plane"} count (_templates select _ti)) > 0})) then {
			(_buckets select _bClass) set [count (_buckets select _bClass), _ti];
		};
	} forEach _eligible;

	_mix = WFBE_C_AICOM_TYPE_MIX;
	if (isNil "_mix" || {count _mix < 4}) then {_mix = [0.65, 0.20, 0.12, 0.03]};
	_dWeights = [_mix select 0, _mix select 1, _mix select 2, _mix select 3];
	_doc = _logik getVariable ["wfbe_aicom_doctrine", ""];
	if (_doc != "") then {
		_track = if (_doc == "HF") then {2} else {1};
		_dWeights set [_track, (_dWeights select _track) * 1.5];
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
	_pick = (_buckets select _chosen) select (floor (random (count (_buckets select _chosen))));

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
		["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] W7 VeteranCompany applied - premium template %2.", _sideText, _pick]] Call WFBE_CO_FNC_AICOMLog;
	};
	_template = _templates select _pick;

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
	[_hcUnit, "HandleSpecial", ['delegate-aicom-team', _sideID, _template, getPos _facObj, _w7SkillSend]] Call WFBE_CO_FNC_SendToClient;
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
