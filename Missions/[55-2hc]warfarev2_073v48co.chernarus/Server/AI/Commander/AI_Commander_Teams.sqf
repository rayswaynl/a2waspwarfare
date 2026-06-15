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
              "_buckets","_eu","_bClass","_mix","_dWeights","_wSum","_roll","_acc","_chosen","_clsOrder","_bi"];

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
		if ([_x, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool) then {_real = true};
		if (!_real && {[_x, "wfbe_aicom_founded", false] Call WFBE_CO_FNC_GroupGetBool}) then {_real = true};
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

//--- Log only when the effective target changes (avoid RPT spam).
_lastDynTarget = _logik getVariable ["wfbe_aicom_dyntarget", _base];
if (_target > _base && {_target != _lastDynTarget}) then {
	_logik setVariable ["wfbe_aicom_dyntarget", _target];
	["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] dynamic target raised to %2 (base %3 + extra %4, funds %5).", _sideText, _target, _base, _extra, _funds]] Call WFBE_CO_FNC_AICOMLog;
};
if (_target == _base && {_lastDynTarget > _base}) then {
	_logik setVariable ["wfbe_aicom_dyntarget", _base];
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

	//--- P1 combined-arms picker (claude-gaming 2026-06-15). Mirror of AI_Commander_AssignTypes.sqf:
	//--- the old doctrine-only weighting (70% one vehicle track, 30% UNIFORM over all eligible) averaged
	//--- ~70% infantry because infantry templates unlock first and stay eligible all match while vehicle
	//--- templates unlock late. Here _eligible is ALREADY gated on factory + real-unit-data tier, so any
	//--- bucketed pick is buildable. Bucket eligible by class (air>0->air / heavy>0->heavy / light>0->
	//--- light / else infantry), roll a target class from WFBE_C_AICOM_TYPE_MIX (with a light doctrine
	//--- nudge), degrade to a lower buildable class when the rolled one is empty, and never starve infantry.
	_buckets = [[],[],[],[]]; //--- [infantry, light, heavy, air]
	{
		_eu = _tmplUpgrades select _x;
		_bClass = 0; //--- infantry
		if ((_eu select WFBE_UP_AIR) > 0) then {_bClass = 3} else {
			if ((_eu select WFBE_UP_HEAVY) > 0) then {_bClass = 2} else {
				if ((_eu select WFBE_UP_LIGHT) > 0) then {_bClass = 1};
			};
		};
		(_buckets select _bClass) set [count (_buckets select _bClass), _x];
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
			if (_w7Score > _w7Best) then {_w7Best = _w7Score; _w7BestIdx = _w7Idx};
		} forEach _eligible;
		_pick = _w7BestIdx;
		["INFORMATION", Format ["AI_Commander_Teams.sqf: [%1] W7 VeteranCompany applied - premium template %2.", _sideText, _pick]] Call WFBE_CO_FNC_AICOMLog;
	};
	_template = _templates select _pick;

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
