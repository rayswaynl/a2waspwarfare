/*
	AI Commander - assign an AI-team template to each unassigned AI team.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side (west/east/resistance).

	A team needs a template (wfbe_teamtype) before it can be produced for. We pick a
	random template the side has UNLOCKED (its [barracks,light,heavy,air] min-upgrade
	levels are all met). Factory availability is NOT checked here on purpose - the
	Produce worker no-ops gracefully when the needed factory does not exist yet.
*/

private ["_side","_logik","_sideText","_teams","_templates","_tmplUpgrades","_upgrades","_team","_eligible","_i","_u","_ok","_k","_pick","_unassigned","_doc","_track","_pref","_buckets","_eu","_bClass","_mix","_doctrineNudge","_dWeights","_wSum","_roll","_acc","_chosen","_order","_bi","_ti",
              "_sideID","_storedTypes","_ownTowns","_hasAirfield","_afNames","_unlockList","_cn","_reqTown","_holdsTrigger"]; //--- B66

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_sideText = str _side;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID; //--- B66 (capture-unlock + airfield town-ownership scans).

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

_templates    = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];
_tmplUpgrades = missionNamespace getVariable Format ["WFBE_%1AITEAMUPGRADES", _sideText];
if (isNil "_templates") exitWith {};
if (isNil "_tmplUpgrades") exitWith {};
if (count _templates == 0) exitWith {};

_upgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

//--- B66 BUCKET-CLASSIFIER: load the AUTHORITATIVE per-template stored type (0=inf,1=light,2=heavy,
//--- 3=air) from Squads_GetFactionGroups (the CfgGroups category) so the picker buckets by that instead
//--- of the upgrade mask (which mis-buckets motorized templates as infantry). nil-guarded per template.
_storedTypes = missionNamespace getVariable Format ["WFBE_%1AITEAMTYPES", _sideText]; //--- B66

//--- B66 MATURITY-RAMP + AIRFIELD-AIR: precompute the side's OWN-TOWN count (for the mix tier) and whether
//--- it holds an airfield-tagged town (for the fixed-wing plane gate), once per call. Airfield town names
//--- are the capture-unlock/airfield anchors (NWAF/NEAF/Balota), reused from this side's CAPTURE_UNLOCKS.
_ownTowns = 0;
{ if ((_x getVariable ["sideID", -1]) == _sideID) then {_ownTowns = _ownTowns + 1} } forEach towns;
_hasAirfield = false;
if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_REQUIRE_AIRFIELD", 1]) > 0) then {
	_afNames = ["NWAF","NEAF","Balota","Rasman AF"];
	{
		if (!((_x select 1) in _afNames)) then {_afNames = _afNames + [_x select 1]};
	} forEach (missionNamespace getVariable [Format ["WFBE_%1_CAPTURE_UNLOCKS", _sideText], []]);
	{
		if (((_x getVariable ["sideID", -1]) == _sideID) && {(_x getVariable ["wfbe_is_airfield", false]) || {(_x getVariable ["name",""]) in _afNames} || {!(isNull (_x getVariable ["wfbe_airfield_hangar_obj", objNull]))}}) exitWith {_hasAirfield = true}; //--- B74: authoritative baked wfbe_is_airfield flag primary; name-list + hangar-obj fallback.
	} forEach towns;
} else {
	_hasAirfield = true; //--- rule disabled -> planes ungated (old behaviour).
};

{
	_team = _x;
	//--- V0.6.5: skip NULL entries (wiped HC teams; getVariable on a null group
	//--- returns nil even with a default -> nil < 0 threw and killed this worker).
	if (!isNull _team) then {
	_unassigned = false;
	if ((_team getVariable ["wfbe_teamtype", -1]) < 0) then {_unassigned = true};
	//--- V0.3: HC-resident teams carry a fixed template from founding - skip.
	if (!isPlayer (leader _team) && {!([_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool)}) then {
		if (_unassigned) then {
			//--- Build the list of UNLOCKED template indices.
			_eligible = [];
			for "_i" from 0 to (count _templates - 1) do {
				_u = _tmplUpgrades select _i;
				_ok = true;
				for "_k" from 0 to 3 do {
					if ((_u select _k) > (_upgrades select _k)) exitWith {_ok = false};
				};
				//--- B66 CAPTURE-UNLOCK eligibility: a template containing a CAPTURE_UNLOCKS premium
				//--- class (T72M4CZ/RM70_ACR) is only eligible while this side HOLDS the trigger town.
				//--- Mirror the client gate (Client_UIFillListBuyUnits): match class -> require town
				//--- held (name+sideID scan). A2-OA-safe: forEach/exitWith, no findIf. Non-premium
				//--- classes never gate (_reqTown stays ""). Premium TEMPLATES are added by the groups
				//--- implementer; this only gates their eligibility.
				if (_ok && {(missionNamespace getVariable ["WFBE_C_CAPTURE_UNLOCKS", 0]) > 0}) then {
					_unlockList = missionNamespace getVariable [Format ["WFBE_%1_CAPTURE_UNLOCKS", _sideText], []];
					{
						_cn = _x;
						_reqTown = ""; //--- "" => _cn is not a capture-unlock class.
						{ if ((_x select 0) == _cn) exitWith {_reqTown = _x select 1} } forEach _unlockList;
						if (_reqTown != "") then {
							_holdsTrigger = false;
							{ if (((_x getVariable ["name",""]) == _reqTown) && {(_x getVariable ["sideID", -1]) == _sideID}) exitWith {_holdsTrigger = true} } forEach towns;
							if (!_holdsTrigger) then {_ok = false};
						};
						if (!_ok) exitWith {};
					} forEach (_templates select _i);
				};
				if (_ok) then {_eligible set [count _eligible, _i]};
			};

			//--- Ray 2026-06-29 NO STATICS / NO WEAPON TEAMS (no-HC fallback): mirror of the founding strip in
			//--- AI_Commander_Teams.sqf - drop every eligible template containing a StaticWeapon so the AI never types a
			//--- server-local team onto a static gun / mortar emplacement / weapon team. Self-propelled arty (GRAD/MLRS)
			//--- are vehicle hulls, not StaticWeapon, so they survive. GUARDRAIL: keep the original set if stripping would
			//--- empty it (founding never starved). A2-OA-safe: string-form isKindOf on the template classnames.
			private ["_eligNoStatic","_swEi","_swHas"];
			_eligNoStatic = [];
			{
				_swEi = _x;
				_swHas = false;
				{ if ((typeName _x == "STRING") && {_x isKindOf "StaticWeapon"}) exitWith {_swHas = true} } forEach (_templates select _swEi);
				if (!_swHas) then {_eligNoStatic set [count _eligNoStatic, _swEi]};
			} forEach _eligible;
			if (count _eligNoStatic > 0) then {_eligible = _eligNoStatic};

			if (count _eligible > 0) then {
				//--- P1 combined-arms picker (claude-gaming 2026-06-15). The old logic favoured the
				//--- doctrine's single vehicle track 70% of the time but fell back to a UNIFORM draw over
				//--- all eligible templates the other 30%; because infantry templates unlock first and are
				//--- ALWAYS eligible while vehicle templates unlock late, the run-long average landed ~70%
				//--- infantry. New approach: bucket the eligible templates by CLASS (infantry/light/heavy/
				//--- air using the same air>0->air / heavy>0->heavy / light>0->light / else infantry rule
				//--- as the telemetry), then roll a target class from WFBE_C_AICOM_TYPE_MIX. Buckets are
				//--- built from _eligible, so every pick is already factory+tech-buildable. If the rolled
				//--- class is empty we degrade to the next buildable class (down to infantry, always present),
				//--- so non-infantry only appears when the side can actually field it - and infantry is never
				//--- starved (foot are needed to capture camps).
				_buckets = [[],[],[],[]]; //--- [infantry, light, heavy, air]
				{
					_ti = _x; _eu = _tmplUpgrades select _ti; //--- A1 (Ray 2026-06-19): _ti captured because the helicopters-only `count` below rebinds _x.
					//--- B66 BUCKET-CLASSIFIER FIX: bucket by the AUTHORITATIVE CfgGroups stored type (0=inf,
					//--- 1=light,2=heavy,3=air) instead of the upgrade mask (which mis-buckets motorized
					//--- templates as infantry). nil-guarded per template to the old upgrade-mask logic.
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
					//--- A1 helicopters-only AICOM air (Ray 2026-06-19): drop fixed-wing Su/plane + UAV air templates (CfgGroups
					//--- Air pulls them via Squads_GetFactionGroups) - the AI can't fly planes, they pile up unused on base.
					//--- B66 AIRFIELD-AIR RULE: a fixed-wing PLANE air template is admitted ONLY when the side holds an
					//--- airfield-tagged town (_hasAirfield). No airfield = identical to the old blanket strip (helicopters
					//--- only); choppers (air, no Plane) are unaffected.
					if (!((_bClass == 3) && {({_x isKindOf "Plane"} count (_templates select _ti)) > 0} && {(!_hasAirfield) || (time < (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) || (random 1 >= (((((time - (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) max 0) / (((missionNamespace getVariable ["WFBE_C_AICOM_JET_FULL_SECS", 18000]) - (missionNamespace getVariable ["WFBE_C_AICOM_JET_START_SECS", 7200])) max 1)) min 1)))})) then { //--- AICOM v2 JET TIME-RAMP: planes also gated by time (no jets <2h, ramp 2h->5h).
						(_buckets select _bClass) set [count (_buckets select _bClass), _ti];
					};
				} forEach _eligible;

				//--- B66 MATURITY-RAMPED MIX: select the [inf,light,heavy,air] weight tier by the side's OWN-TOWN
				//--- count (_ownTowns): EARLY when towns < MATURE_MID, MID when towns < MATURE_LATE, else LATE.
				//--- Fall back to the static WFBE_C_AICOM_TYPE_MIX if a tier const is nil. Copied below so the
				//--- doctrine nudge never mutates the shared const.
				private ["_matMid","_matLate"];
				_matMid  = missionNamespace getVariable ["WFBE_C_AICOM_TYPE_MIX_MATURE_MID",  4];
				_matLate = missionNamespace getVariable ["WFBE_C_AICOM_TYPE_MIX_MATURE_LATE", 8];
				_mix = if (_ownTowns < _matMid) then {
					missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_EARLY"
				} else {
					if (_ownTowns < _matLate) then {
						missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_MID"
					} else {
						missionNamespace getVariable "WFBE_C_AICOM_TYPE_MIX_LATE"
					};
				};
				if (isNil "_mix" || {count _mix < 4}) then {_mix = WFBE_C_AICOM_TYPE_MIX}; //--- B66: tier const nil -> static fallback.
				if (isNil "_mix" || {count _mix < 4}) then {_mix = [0.65, 0.20, 0.12, 0.03]};
				_dWeights = [_mix select 0, _mix select 1, _mix select 2, _mix select 3];
				//--- Keep a light doctrine flavour: nudge the side's primary vehicle track up ~50% so HF
				//--- armies skew armour and LF armies skew mech/light, WITHOUT collapsing back to one track.
				_doc = _logik getVariable ["wfbe_aicom_doctrine", ""];
				if (_doc != "") then {
					_track = if (_doc == "HF") then {2} else {1};
					_dWeights set [_track, (_dWeights select _track) * 1.5];
				};
				//--- B69 #16 TOWN-ASSAULT PUNCH-BIAS: scale the heavy/armour bucket (select 2) and the
				//--- light/transport-truck bucket (select 1) by server-local multipliers so town-assault
				//--- pressure skews toward armour+trucks without re-weighting the const. Applied AFTER the
				//--- doctrine nudge and BEFORE the zero-out loop, so a class with no buildable template is
				//--- still zeroed below -> the bias is a no-op when the side cannot build armour (infantry
				//--- never starved/frozen). Defaults 1.0 => byte-identical until the consts land.
				_dWeights set [2, (_dWeights select 2) * (missionNamespace getVariable ["WFBE_C_AICOM_TOWNPUNCH_HEAVY_MULT", 1.0])]; _dWeights set [2, (_dWeights select 2) * (missionNamespace getVariable ["WFBE_C_AICOM_MECH_BIAS", 2.0])]; _dWeights set [1, (_dWeights select 1) * (missionNamespace getVariable ["WFBE_C_AICOM_MOTOR_BIAS", 1.4])]; //--- B755: mechanized/motorized bias (mirror of Teams.sqf) for the no-HC fallback path.
				_dWeights set [1, (_dWeights select 1) * (missionNamespace getVariable ["WFBE_C_AICOM_TOWNPUNCH_LIGHT_MULT", 1.0])];
					_dWeights set [3, (_dWeights select 3) * (1 + (((time / 60) min ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) / ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_RAMP_MIN", 45]) max 1)) * ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_TIME_BIAS_MAXMULT", 2.5]) - 1))]; //--- B754: heli time-bias (mirror of Teams.sqf) for the no-HC fallback path.
				//--- COMMAND CONSOLE (PR backend, claude-gaming 2026-06-28) REQUEST-UNIT HOOK: a fresh player class request nudges the bucket weight (soft).
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
				//--- Zero out classes with no buildable template so the roll only lands on achievable types.
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
				//--- Safety: if the weighted roll produced nothing buildable, walk classes by preference
				//--- (heavy > light > air > infantry) and take the first non-empty bucket; infantry always
				//--- has entries (the [0,0,0,0] rifle squad), so a pick is guaranteed.
				if (_chosen < 0 || {count (_buckets select _chosen) == 0}) then {
					_order = [2,1,3,0];
					{ if (count (_buckets select _x) > 0) exitWith {_chosen = _x} } forEach _order;
				};
				//--- ALL-EMPTY GUARD (2026-06-28): if EVERY bucket is empty the degrade-walk above leaves _chosen = -1
				//--- (the all-jets-before-the-jet-ramp edge: the lone air bucket was time-gated out and no ground bucket
				//--- exists this cycle). The next line `_buckets select _chosen` would throw "select -1". The all-empty
				//--- condition is GLOBAL for this cycle, so exitWith ends the team forEach (spec-sanctioned). INERT in
				//--- normal cycles: the infantry bucket is virtually always populated, so _chosen >= 0 and this never fires.
				if (_chosen < 0) exitWith {};
				_pick = -1;
					//--- B74 COST/TIER-WEIGHTED DRAW (Ray 2026-06-22): mirror of the founding picker in AI_Commander_Teams.sqf -
					//--- weight the chosen bucket by (summed unit price)^EXP so server-local teams field their expensive unlocked
					//--- units too (EXP=0 or a single candidate reproduces the old uniform draw). A2-OA-safe (^ op, manual counter, _x captured).
					private ["_cwBucket","_cwExp","_cwWeights","_cwSum","_cwIdx","_cwTmpl","_cwPrice","_cwW","_cwRoll","_cwAcc","_cwI","_cwUd"];
					_cwBucket = _buckets select _chosen;
					_cwExp = missionNamespace getVariable ["WFBE_C_AICOM_TIER_BIAS_EXP", 1.5];
					if (_cwExp <= 0 || {count _cwBucket <= 1}) then {
						_pick = _cwBucket select (floor (random (count _cwBucket)));
					} else {
						_cwWeights = []; _cwSum = 0;
						{
							_cwIdx  = _x;
							_cwTmpl = _templates select _cwIdx;
							_cwPrice = 0;
							{ _cwUd = missionNamespace getVariable _x; if (!isNil "_cwUd") then {_cwPrice = _cwPrice + (_cwUd select QUERYUNITPRICE)} } forEach _cwTmpl;
							if (_cwPrice < 1) then {_cwPrice = 1};
							_cwW = _cwPrice ^ _cwExp;
							_cwWeights set [count _cwWeights, _cwW];
							_cwSum = _cwSum + _cwW;
						} forEach _cwBucket;
						_cwRoll = random _cwSum; _cwAcc = 0; _cwI = 0;
						{
							_cwAcc = _cwAcc + (_cwWeights select _cwI);
							if (_pick < 0 && {_cwRoll < _cwAcc}) then {_pick = _x};
							_cwI = _cwI + 1;
						} forEach _cwBucket;
						if (_pick < 0) then {_pick = _cwBucket select (count _cwBucket - 1)};
					};
				_team setVariable ["wfbe_teamtype", _pick, true];
				["INFORMATION", Format ["AI_Commander_AssignTypes.sqf: [%1] assigned template %2 to AI team [%3] (doctrine %4).", _sideText, _pick, _team, _doc]] Call WFBE_CO_FNC_AICOMLog;
				//--- PRODUCTION class telemetry (claude-gaming 2026-06-15): a server-local team's
				//--- class is decided HERE (the HC path is logged in AI_Commander_Teams.sqf). Classify
				//--- the assigned template by its min-upgrade reqs ([barracks,light,heavy,air] =
				//--- _tmplUpgrades select _pick): air>0 -> air, else heavy>0 -> heavy, else light>0 ->
				//--- light, else infantry. Single diag_log riding the existing per-team assignment.
				private ["_clsU","_cls"];
				_clsU = _tmplUpgrades select _pick;
				_cls = "infantry";
				if ((_clsU select WFBE_UP_AIR) > 0) then {_cls = "air"} else {
					if ((_clsU select WFBE_UP_HEAVY) > 0) then {_cls = "heavy"} else {
						if ((_clsU select WFBE_UP_LIGHT) > 0) then {_cls = "light"};
					};
				};
				diag_log ("AICOMSTAT|v2|EVENT|" + _sideText + "|" + str (round (time / 60)) + "|TEAM_TYPED|via=server-local|template=" + str _pick + "|class=" + _cls);
			};
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
