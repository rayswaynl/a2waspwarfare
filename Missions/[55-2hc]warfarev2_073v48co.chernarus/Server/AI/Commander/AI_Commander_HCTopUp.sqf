/*
	AI Commander - HC-team top-up and merge worker

	Server-side picker for under-strength HC-owned infantry groups. It performs at most
	one safe action per cadence: merge two same-owner depleted groups, or publish one
	charged reinforcement request for the existing HC-local Common_RunCommanderTeam
	consumer. Both paths stay inert unless their existing default-0 flags are enabled.

	Parameter: _this = side.
*/
private ["_side","_sideText","_logik","_enable","_teams","_sizeMin","_floor","_funds",
         "_perUnitCost","_picked","_team","_ldr","_aliveNow","_nearSupply","_myID",
         "_shortBy","_classes","_template","_templates","_type","_man","_want","_inContact","_isArmour",
         "_mergeEnable","_topupEnable","_sizeMax","_mFloor","_mRange","_cands","_t","_tl","_an","_ty","_arm",
         "_bestA","_bestB","_bestSum","_nC","_ca","_cb","_sum","_sent","_bSideID","_ownerA","_ownerB","_existingReq","_hasPending","_existingDisband","_isDisbanding","_topCharge","_hcTeam","_tHC","_tRelief","_tReq","_tHasPending","_tDisband","_tIsDisbanding","_tStrike","_tCapLock","_tHolding","_tIsHolding"];

//--- HARD GATE: inert unless EITHER pass is explicitly enabled (absent variable => false).
//--- B69: the MERGE pass (below) is gated on WFBE_C_AICOM_HC_MERGE_ENABLE; the legacy top-up pick loop
//--- is gated on WFBE_C_AICOM_HC_TOPUP_ENABLE (the approved B69 lever is MERGE - top-up stays inert/SKIPPED
//--- unless its own flag is turned on). The worker runs if EITHER is on; each pass self-gates independently.
_enable      = (missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_ENABLE", 0]) > 0; //--- B69 fix: enable flags ship as Number 0/1; coerce to BOOL via >0 so the downstream bool gates work (the old typeName!="BOOL" coercion forced both to false, so the worker was inert even when the flag was set to 1).
_mergeEnable = (missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_ENABLE", 0]) > 0;
if (!_enable && {!_mergeEnable}) exitWith {};

_side = _this;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

_sizeMin = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MIN", 8];
//--- reinforce only teams that have fallen clearly below the band (not every 7/8 squad).
_floor = round (_sizeMin * (missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_FRAC", 0.6]));

_myID = (_side) Call WFBE_CO_FNC_GetSideID;
_templates = missionNamespace getVariable Format ["WFBE_%1AITEAMTEMPLATES", _sideText];

//--- ============================================================================================
//--- B69 SAME-HC MERGE PASS (default-OFF, 1 merge/call). PART 1 = server PICKER only.
//--- When two HC-resident infantry teams on the SAME side have both attrited below floor and sit
//--- close together OUT of combat, consolidate them: joinSilent B's survivors into A (one bigger
//--- squad, one whole group slot freed). Strictly better than refill for the FPS-bound server:
//--- total AI FLAT, group count -1. Hard catch: in this 2-HC mission A and B may be LOCAL on
//--- DIFFERENT HCs and joinSilent across machines is unreliable in OA, so the actual join MUST run
//--- only where BOTH leaders are local to the SAME HC. The picker requires both leaders to share
//--- an owner, sends only to that owner, and only then deregisters the donor; cross-HC pairs are never
//--- selected, so an unmerged donor cannot be reaped.
//--- A2-OA 1.64 safe: typeName ==, isKindOf "Tank", behaviour ==, distance, leader, alive, units,
//--- nested for..do (no findIf/apply), grpNull, exitWith. NO isEqualType/isEqualTo/typed params.
//--- This pass fires AT MOST one merge per call (exitWith), matching the top-up 1/call throttle.
if (_mergeEnable) then {
	_sizeMax = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 12];
	_mFloor  = round (_sizeMin * (missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_FRAC", 0.6]));
	_mRange  = missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_RANGE", 300];
	//--- Build the list of merge-eligible HC infantry teams: below floor, alive, NOT in combat, NOT
	//--- player-led, NOT armour/heli, and not pending top-up, disbanding, holding/cap-locked, garrison,
	//--- relief, or HQ-strike tasked. Those teams have live work that a merge must not abandon.
	//--- Each candidate carries [team, aliveCount, leader].
	_cands = [];
	{
		_t = _x;
		if (!isNull _t) then {
			_tHC = _t getVariable "wfbe_aicom_hc";
			_tReq = _t getVariable "wfbe_aicom_topup_req";
			_tHasPending = !isNil "_tReq" && {(typeName _tReq) == "ARRAY"} && {(count _tReq) > 0};
			_tDisband = _t getVariable "wfbe_aicom_disband";
			_tIsDisbanding = !isNil "_tDisband" && {_tDisband};
			_tStrike = [_t, "wfbe_aicom_strike", false] Call WFBE_CO_FNC_GroupGetBool;
			_tCapLock = [_t] Call WFBE_CO_FNC_CapLock;
			_tHolding = _t getVariable "wfbe_aicom_holding_town";
			_tIsHolding = !isNil "_tHolding" && {(typeName _tHolding) == "OBJECT"} && {!isNull _tHolding};
			if (!isNil "_tHC" && {_tHC} && {!_tHasPending} && {!_tIsDisbanding} && {!_tStrike} && {!_tCapLock} && {!_tIsHolding}) then {
				_tl = leader _t;
				if (!isNull _tl && {alive _tl} && {!(isPlayer _tl)} && {(behaviour _tl) != "COMBAT"}) then {
					_tRelief = _t getVariable "wfbe_aicom_relief";
					if (!(((_logik getVariable ["wfbe_aicom_garrison", grpNull]) == _t) || {!isNil "_tRelief" && {!isNull _tRelief}})) then {
						_an = {alive _x} count (units _t);
						_ty = _t getVariable "wfbe_teamtype";
						if (isNil "_ty") then {_ty = -1};
						_arm = false;
						if (!isNil "_templates" && {_ty >= 0} && {_ty < count _templates}) then {
							{ if (_x isKindOf "Tank") exitWith {_arm = true} } forEach (_templates select _ty);
						};
						if (!_arm && {_an > 0} && {_an < _mFloor}) then {_cands = _cands + [[_t, _an, _tl]]};
					};
				};
			};
		};
	} forEach _teams;

	//--- Pick the smallest-COMBINED eligible PAIR within range whose combined alive <= SIZE_MAX
	//--- (so the merged squad never exceeds the 12-cap). A = keep (larger), B = donor (smaller).
	_bestA = grpNull; _bestB = grpNull; _bestSum = 1e9;
	_nC = count _cands;
	if (_nC >= 2) then {
		for "_i" from 0 to (_nC - 2) do {
			for "_j" from (_i + 1) to (_nC - 1) do {
				_ca = _cands select _i; _cb = _cands select _j;
				_sum = (_ca select 1) + (_cb select 1);
				if (_sum <= _sizeMax && {((_ca select 2) distance (_cb select 2)) <= _mRange} && {(owner (_ca select 2)) == (owner (_cb select 2))} && {_sum < _bestSum}) then {
					_bestSum = _sum;
					//--- A keeps the LARGER survivor count (donor B is the smaller of the two).
					if ((_ca select 1) >= (_cb select 1)) then {
						_bestA = _ca select 0; _bestB = _cb select 0;
					} else {
						_bestA = _cb select 0; _bestB = _ca select 0;
					};
				};
			};
		};
	};

	if (!isNull _bestA && {!isNull _bestB}) exitWith {
		_ownerA = owner (leader _bestA);
		_ownerB = owner (leader _bestB);
		//--- The pair picker requires a shared owner. Remote joins are sent only to that HC;
		//--- server-local pairs join inline. This prevents the old cross-HC no-op/donor-reap race.
		if (_ownerA == _ownerB) then {
			_bSideID = (side (leader _bestB)) Call WFBE_CO_FNC_GetSideID; //--- capture before joinSilent empties donor B.
			if (isServer && {local (leader _bestA)} && {local (leader _bestB)}) then {
				(units _bestB) joinSilent _bestA;
				_bestB setVariable ["wfbe_persistent", false, true];
				["aicom-team-ended", _bSideID, _bestB] Call HandleSpecial;
			} else {
				//--- The owning HC sends aicom-team-ended only after its local join completes.
				[leader _bestA, "HandleSpecial", ["aicom-team-merge", _bestA, _bestB]] Call WFBE_CO_FNC_SendToClient;
			};
			diag_log ("AICOMSTAT|v1|EVENT|" + str _myID + "|" + str (round (time / 60)) + "|HC_MERGE_DISPATCH|A=" + (str _bestA) + "|B=" + (str _bestB) + "|sum=" + str _bestSum + "|range=" + str (round ((leader _bestA) distance (leader _bestB))));
			["INFORMATION", Format ["AI_Commander_HCTopUp.sqf: [%1] MERGE dispatched B[%2] -> A[%3] (combined %4, floor %5).", _sideText, _bestB, _bestA, _bestSum, _mFloor]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
};
//--- ---- end B69 merge pass; the legacy top-up pick loop follows ----

//--- TOP-UP path is SKIPPED unless its own flag is on (merge is the approved B69 lever). When only the
//--- merge flag is enabled this exits here (no spawn, no funds touched) - keeps the refill path inert.
if (!_enable) exitWith {};

//--- Pick ONE eligible team this call (throttle = 1/team per cadence).
_picked = objNull;
{
	_team = _x;
	if (isNull _picked && {!isNull _team}) then {
		//--- HC-founded teams only (server-local teams are handled by Produce already).
		_hcTeam = _team getVariable "wfbe_aicom_hc";
		if (!isNil "_hcTeam" && {_hcTeam}) then {
			_existingReq = _team getVariable "wfbe_aicom_topup_req";
			_hasPending = !isNil "_existingReq" && {(typeName _existingReq) == "ARRAY"} && {(count _existingReq) > 0};
			_existingDisband = _team getVariable "wfbe_aicom_disband";
			_isDisbanding = !isNil "_existingDisband" && {_existingDisband};
			_ldr = leader _team;
			if (!_hasPending && {!_isDisbanding} && {!isNull _ldr} && {alive _ldr}) then {
				_aliveNow = {alive _x} count (units _team);
				//--- Skip MBT / attack-heli teams: their punch is the hull+crew, never pad with rifles.
				//--- (A non-infantry template is identified the same way Produce does: any Tank in it.)
				_type = _team getVariable "wfbe_teamtype";
				if (isNil "_type") then {_type = -1};
				_isArmour = false;
				if (!isNil "_templates" && {_type >= 0} && {_type < count _templates}) then {
					{ if (_x isKindOf "Tank") exitWith {_isArmour = true} } forEach (_templates select _type);
				};
				//--- In-contact guard: do NOT reinforce a team that is mid-firefight (cosmetic pop-in
				//--- next to players/enemies + it should be fighting, not waiting on spawns). Behaviour
				//--- COMBAT is the A2-safe "in contact" read used elsewhere in this codebase.
				_inContact = (behaviour _ldr) == "COMBAT";
				//--- Near a friendly supply town (resupply makes sense at the front/rear, not in open field).
				_nearSupply = false;
				{
					if (((_x getVariable ["sideID",-1]) == _myID) && {(_ldr distance _x) < (missionNamespace getVariable ["WFBE_C_AICOM_HC_TOPUP_RANGE", 900])}) exitWith {_nearSupply = true};
				} forEach towns;

				if (!_isArmour && {!_inContact} && {_nearSupply} && {_aliveNow > 0} && {_aliveNow < _floor}) then {
					_picked = _team;
				};
			};
		};
	};
} forEach _teams;

if (isNull _picked) exitWith {};

//--- Compute the shortfall class list. Top up toward SIZE_MIN (clamped by the per-side AI cap
//--- the same way Produce.sqf:123 does). Pad with the LAST Man-class in the team template
//--- (a basic rifleman) - never duplicate a vehicle (mirrors Produce.sqf:155-157 FILL-TO-FLOOR).
_team = _picked;
_aliveNow = {alive _x} count (units _team);
_want = (_sizeMin min (missionNamespace getVariable "WFBE_C_AI_MAX"));
_shortBy = _want - _aliveNow;
if (_shortBy <= 0) exitWith {};
//--- Common_RunCommanderTeam consumes at most four bodies, then clears the request.
_shortBy = _shortBy min 4;

_man = "";
_type = _team getVariable "wfbe_teamtype";
if (isNil "_type") then {_type = -1};
if (!isNil "_templates" && {_type >= 0} && {_type < count _templates}) then {
	_template = _templates select _type;
	{ if (_x isKindOf "Man") then {_man = _x} } forEach _template;   //--- last Man-class = basic dismount.
};
if (_man == "") exitWith {};   //--- all-vehicle template => nothing to pad with (armour exempt anyway).

//--- Funds gate (charge up-front for the batch; per-unit price via the canonical query lookup).
_perUnitCost = 0;
private ["_ud"]; _ud = missionNamespace getVariable _man;
if (!isNil "_ud") then {_perUnitCost = _ud select QUERYUNITPRICE};
_funds = (_side) Call GetAICommanderFunds;
if (_perUnitCost > 0 && {_funds < (_perUnitCost * _shortBy)}) then {
	//--- Trim the batch to what we can afford rather than skip entirely (still >=1).
	_shortBy = floor (_funds / _perUnitCost);
};
if (_shortBy <= 0) exitWith {};

_classes = [];
for "_i" from 1 to _shortBy do { _classes = _classes + [_man] };
if (_perUnitCost > 0) then { [_side, -(_perUnitCost * (count _classes))] Call ChangeAICommanderFunds };

//--- Publish the charged request on the group. The existing Common_RunCommanderTeam HC consumer
//--- self-gates on locality, creates the requested men with WFBE_CO_FNC_CreateUnit, and refunds
//--- stale or failed work. Public group state is the current proven HC dispatch contract.
_topCharge = _perUnitCost * (count _classes);
_team setVariable ["wfbe_aicom_topup_req", [count _classes, getPosATL (leader _team), _classes, time, _topCharge], true];

diag_log ("AICOMSTAT|v1|EVENT|" + str _myID + "|" + str (round (time / 60)) + "|HC_TOPUP|team=" + (str _team) + "|alive=" + str _aliveNow + "|add=" + str (count _classes) + "|class=" + _man);
["INFORMATION", Format ["AI_Commander_HCTopUp.sqf: [%1] top-up team [%2] alive=%3 -> +%4 x %5 (floor=%6).", _sideText, _team, _aliveNow, count _classes, _man, _floor]] Call WFBE_CO_FNC_AICOMLog;
