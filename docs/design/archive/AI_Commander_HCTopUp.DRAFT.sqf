/*
	AI Commander - HC-team TOP-UP pass  [DRAFT - claude-gaming 2026-06-20, B58 soak]

	STATUS: DRAFT / NOT WIRED. This file is referenced by NOTHING in the live mission
	(no loader, no spawn, no FSM). Committing it changes ZERO live behaviour - it exists
	for AM review on branch claude/b57-soak-proposals. Do NOT add it to a loader until the
	HC-side consumer (below) is written and the whole path is live-verified.

	WHY: live CMDRSTAT shows unitsPerTeam dribbling to 4.9-7 (target band 8-12) because
	AI_Commander_Produce.sqf:63 skips wfbe_aicom_hc teams - i.e. 100% of live teams are
	NEVER refilled after founding. The founding-pad (B57) sets size AT founding; attrition
	then drags the live average below the floor with no recovery. Produce can't fix it:
	AIBuyUnit spawns the refill at a SERVER-side factory, but HC teams' units are LOCAL on
	the Headless Client, so the refill must be created HC-side and join-ed there (same
	locality rule Common_RunCommanderTeam.sqf / Common_CreateTeam.sqf rely on).

	DESIGN (two halves):
	  (A) THIS server worker: scan a side's HC teams, find ONE under-strength team that is
	      safe to reinforce (not in contact, near a friendly supply town), charge funds, and
	      hand the HC a top-up request via the existing RequestSpecial / HandleSpecial bus
	      that the create/end/heading messages already use.
	  (B) HC-side consumer (TO WRITE - see the commented spec at the bottom): on
	      "aicom-team-topup" the owning HC createUnit's the shortfall NEXT TO the team leader
	      and joinSilent's them into the group, mirroring Common_CreateTeam's spawn pass.

	A2-OA 1.64 SAFE:
	  - no isEqualType / isEqualTo / worldSize / forceFollowRoad (typeName + string compares only);
	  - NO sim-gating and NO distance-gating that could freeze AI: this worker only ADDS units;
	    it never stops, sleeps, or sim-disables a team. Teams keep their live orders untouched.
	  - does NOT touch antistack.
	  - default-OFF behind WFBE_C_AICOM_HC_TOPUP_ENABLE (absent => false => early exit), so even
	    if someone wires it, it is inert until explicitly switched on.
	  - throttled to ONE team per call (avoids the town-activation spike the old per-group HC
	    pick caused) - the supervisor would call it on a slow cadence, like Produce.

	Parameter: _this = side.
*/

private ["_side","_sideText","_logik","_enable","_teams","_sizeMin","_floor","_funds",
         "_perUnitCost","_picked","_team","_ldr","_aliveNow","_nearSupply","_myID",
         "_shortBy","_classes","_template","_templates","_type","_man","_want","_inContact","_isArmour",
         "_mergeEnable","_topupEnable","_sizeMax","_mFloor","_mRange","_cands","_t","_tl","_an","_ty","_arm",
         "_bestA","_bestB","_bestSum","_nC","_ca","_cb","_sum","_sent","_bSideID"];

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
//--- only where BOTH leaders are local to the SAME HC. This server picker only SELECTS the pair and
//--- broadcasts it to EVERY live HC via WFBE_CO_FNC_SendToClient; each HC's consumer self-gates on
//--- local(leaderA) && local(leaderB). Cross-HC pairs are skipped on every HC (no-op, self-heals
//--- next cadence) => zero orphan risk. The HC-side consumer is PART 2 (handle-consumer agent owns it).
//--- A2-OA 1.64 safe: typeName ==, isKindOf "Tank", behaviour ==, distance, leader, alive, units,
//--- nested for..do (no findIf/apply), grpNull, exitWith. NO isEqualType/isEqualTo/typed params.
//--- This pass fires AT MOST one merge per call (exitWith), matching the top-up 1/call throttle.
if (_mergeEnable) then {
	_sizeMax = missionNamespace getVariable ["WFBE_C_AICOM_TEAM_SIZE_MAX", 12];
	_mFloor  = round (_sizeMin * (missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_FRAC", 0.6]));
	_mRange  = missionNamespace getVariable ["WFBE_C_AICOM_HC_MERGE_RANGE", 300];
	//--- Build the list of merge-eligible HC infantry teams: below floor, alive, NOT in combat, NOT
	//--- player-led, NOT armour/heli (MBT/attack-heli teams are the hull+crew punch - never consolidate
	//--- those), and NOT currently tasked relief / garrison / strike (those teams have a live job; the
	//--- merge would abandon B's order). Each candidate carries [team, aliveCount, leader].
	_cands = [];
	{
		_t = _x;
		if (!isNull _t && {_t getVariable ["wfbe_aicom_hc", false]}) then {
			_tl = leader _t;
			//--- only consider teams whose LEADER is a sane, non-player, non-combat AI body.
			if (!isNull _tl && {alive _tl} && {!(isPlayer _tl)} && {(behaviour _tl) != "COMBAT"}) then {
				//--- skip teams with a live special JOB (don't yank a tasked team into a merge):
				//---   - GARRISON: the side logic tracks the single garrison team in wfbe_aicom_garrison
				//---     (set AI_Commander_AssignTowns.sqf:153; read Strategy.sqf:227/337/557).
				//---   - RELIEF: a relief assignment stamps wfbe_aicom_relief on the team (Strategy.sqf:557).
				//---   (STRIKE is a transient strategy MODE, not a persistent per-team flag - those teams are
				//---    either armour (already excluded below) or marching under a defense order, so they are
				//---    caught by the COMBAT / armour tests; no separate A2-safe flag exists to test for it.)
				//--- NOTE: wfbe_aicom_order is an ARRAY [seq,mode,pos], NOT a string - do not string-compare it.
				if (!(((_logik getVariable ["wfbe_aicom_garrison", grpNull]) == _t) || {!isNull (_t getVariable ["wfbe_aicom_relief", objNull])})) then {
					_an = {alive _x} count (units _t);
					//--- armour/heli exemption: any Tank in the team's template => leave it alone.
					_ty = _t getVariable ["wfbe_teamtype", -1];
					_arm = false;
					if (!isNil "_templates" && {_ty >= 0} && {_ty < count _templates}) then {
						{ if (_x isKindOf "Tank") exitWith {_arm = true} } forEach (_templates select _ty);
					};
					if (!_arm && {_an > 0} && {_an < _mFloor}) then { _cands = _cands + [[_t, _an, _tl]]; };
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
				if (_sum <= _sizeMax && {((_ca select 2) distance (_cb select 2)) <= _mRange} && {_sum < _bestSum}) then {
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

	if (!isNull _bestA && {!isNull _bestB}) exitWith {   //--- exitWith = this call does ONE thing only.
		//--- MERGE PAYLOAD CONTRACT (handle-consumer / hctopup-picker must match EXACTLY):
		//---   the HC consumer reads _args = [A, B] from a "HandleSpecial" PVF carrying ['aicom-team-merge', [A,B]],
		//---   self-gates on local(leader A) && local(leader B), then runs { (units B) joinSilent A }.
		//--- ROUTING: WFBE_CO_FNC_SendToClient routes by owner(element 0), so element 0 MUST be the HC UNIT we
		//--- are sending to (the same idiom AI_Commander_Teams.sqf:514 uses for 'delegate-aicom-team' with
		//--- _hcUnit as element 0) - NOT the merge leader. We iterate WFBE_HEADLESSCLIENTS_ID and send the
		//--- identical payload to EVERY live HC; only the HC that owns BOTH leaders acts (locality self-gate),
		//--- a cross-HC pair is a no-op on every HC (self-heals next cadence). The payload tail ['aicom-team-merge',
		//--- [A,B]] is the consumer contract and is unchanged regardless of which HC we route to.
		{
			if (!isNull _x && {!isNull leader _x} && {alive leader _x}) then {
				[leader _x, "HandleSpecial", ['aicom-team-merge', _bestA, _bestB]] Call WFBE_CO_FNC_SendToClient; //--- B69 fix: WFBE_HEADLESSCLIENTS_ID holds GROUPS -> SendToClient owner needs the LEADER unit; FLAT args (consumer reads _args select 0/1).
			};
		} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);
		//--- Server-local fallback (HC down / server-local pair): act inline if BOTH leaders are local here.
		if (isServer && {local (leader _bestA)} && {local (leader _bestB)}) then {
			['aicom-team-merge', _bestA, _bestB] Call HandleSpecial; //--- B69 fix: FLAT args (consumer reads _args select 0/1).
		};
		//--- Deregister B's SERVER bookkeeping (marker + wfbe_teams entry + persistent) via the canonical
		//--- team-ended path so the now-empty husk is GC-reaped. Do NOT deleteGroup B (desyncs state).
		//--- Fire AFTER the SendToClient dispatch: those are async PVFs and the HC consumer must still read
		//--- B as a live group; the server-side ended-case never touches B's remote units, so no race.
		_bSideID = (side (leader _bestB)) Call WFBE_CO_FNC_GetSideID;
		_bestB setVariable ["wfbe_persistent", false, true]; //--- B69 fix: clear persistent so the empty donor husk is GC-reaped AFTER the async joinSilent (the ended-case count==0 check otherwise races the async join -> husk never reaped -> group count never drops).
		["aicom-team-ended", _bSideID, _bestB] Call HandleSpecial;
		diag_log ("AICOMSTAT|v1|EVENT|" + str _myID + "|" + str (round (time / 60)) + "|HC_MERGE|A=" + (str _bestA) + "|B=" + (str _bestB) + "|sum=" + str _bestSum + "|range=" + str (round ((leader _bestA) distance (leader _bestB))));
		["INFORMATION", Format ["AI_Commander_HCTopUp.DRAFT.sqf: [%1] MERGE B[%2] -> A[%3] (combined %4, floor %5).", _sideText, _bestB, _bestA, _bestSum, _mFloor]] Call WFBE_CO_FNC_AICOMLog;
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
		if (_team getVariable ["wfbe_aicom_hc", false]) then {
			_ldr = leader _team;
			if (!isNull _ldr && {alive _ldr}) then {
				_aliveNow = {alive _x} count (units _team);
				//--- Skip MBT / attack-heli teams: their punch is the hull+crew, never pad with rifles.
				//--- (A non-infantry template is identified the same way Produce does: any Tank in it.)
				_type = _team getVariable ["wfbe_teamtype", -1];
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

_man = "";
_type = _team getVariable ["wfbe_teamtype", -1];
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

//--- Hand the top-up to the OWNING machine. HC teams are remote, so route via the same bus the
//--- create/end/heading messages use; the server-local fallback (no HC) joins directly.
//--- [team, classnames] -> consumer createUnit's each near the leader + joinSilent into _team.
if (isServer && {local (leader _team)}) then {
	//--- server-local team (HC down / fallback path): do it inline, HC-side spec mirrors this.
	["aicom-team-topup", [_team, _classes]] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-topup", [_team, _classes]]] Call WFBE_CO_FNC_SendToServer; //--- server -> all; the owning HC acts on locality.
};

diag_log ("AICOMSTAT|v1|EVENT|" + str _myID + "|" + str (round (time / 60)) + "|HC_TOPUP|team=" + (str _team) + "|alive=" + str _aliveNow + "|add=" + str (count _classes) + "|class=" + _man);
["INFORMATION", Format ["AI_Commander_HCTopUp.DRAFT.sqf: [%1] top-up team [%2] alive=%3 -> +%4 x %5 (floor=%6).", _sideText, _team, _aliveNow, count _classes, _man, _floor]] Call WFBE_CO_FNC_AICOMLog;

/* ----------------------------------------------------------------------------------------
   (B) HC-SIDE CONSUMER - TO WRITE, then wire BOTH halves and live-verify before enabling.

   In Server/Functions/HandleSpecial.sqf add a case "aicom-team-topup" => [team, classes]:
   only act where the team is LOCAL (the owning HC). Spawn each class next to the leader and
   join it in, reusing the Common_CreateTeam idiom so locality + skills stay consistent:

       _team = _p select 0; _classes = _p select 1;
       if (isNull _team || {!local (leader _team)}) exitWith {};   //--- only the owner acts
       _ldr = leader _team; _sp = _ldr modelToWorld [0,-6,0];
       { _u = (group _ldr) createUnit [_x, _sp, [], 8, "FORM"]; _u setSkill ... ;
         [_u] joinSilent _team; } forEach _classes;               //--- joinSilent => no leader churn

   Then have AI_Commander.sqf call this worker on a SLOW gated cadence (like Produce), and set
   WFBE_C_AICOM_HC_TOPUP_ENABLE=true only after watching unitsPerTeam recover toward 8-12 in a
   test round. Keep the 1-team/call throttle to avoid a spawn/town-activation spike.

   NO-FROZEN-AI NOTE: this path only ADDS units and joins them; it never stops the team, never
   sim-disables, never distance-gates the team's own behaviour. The newly-joined units inherit
   the group's live waypoints/orders, so nobody stands idle. A2-OA safe: createUnit + joinSilent
   + setSkill are all 1.64 primitives (Common_CreateTeam uses the same).
---------------------------------------------------------------------------------------- */
